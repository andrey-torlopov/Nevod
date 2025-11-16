# Adding New Authentication Types to Nevod

This guide shows how easy it is to extend Nevod with new authentication schemes.

## Core Principle

Nevod uses a **protocol-oriented** design that separates concerns:

- `TokenModel` - Defines what a token IS and how it authorizes requests
- `RequestInterceptor` - Defines how to handle authentication lifecycle
- `TokenStorage` - Generic storage that works with any TokenModel

This means you can add ANY authentication scheme by simply implementing `TokenModel`.

## Quick Example: Adding Custom Header Auth

Let's say you have an API that requires these headers:
```
X-Client-ID: your-client-id
X-Client-Secret: your-secret
```

### Step 1: Create a TokenModel (5 lines of code)

```swift
import Nevod

struct CustomHeaderToken: TokenModel {
    let clientID: String
    let clientSecret: String
    
    // How to apply auth to requests
    func authorize(_ request: inout URLRequest) {
        request.setValue(clientID, forHTTPHeaderField: "X-Client-ID")
        request.setValue(clientSecret, forHTTPHeaderField: "X-Client-Secret")
    }
    
    // How to save/load (use Codable)
    func encode() throws -> Data {
        try JSONEncoder().encode(["id": clientID, "secret": clientSecret])
    }
    
    static func decode(from data: Data) throws -> Self {
        let dict = try JSONDecoder().decode([String: String].self, from: data)
        return CustomHeaderToken(
            clientID: dict["id"] ?? "",
            clientSecret: dict["secret"] ?? ""
        )
    }
}
```

### Step 2: Use it!

```swift
// 1. Create storage
let storage = TokenStorage<CustomHeaderToken>(
    storage: keychain,
    key: StorageKey(value: "custom_header_token")
)

// 2. Save your credentials
await storage.save(
    CustomHeaderToken(
        clientID: "abc123",
        clientSecret: "secret456"
    )
)

// 3. Use existing AuthenticationInterceptor (no refresh needed)
let interceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        // If your credentials don't expire, just return the same token
        guard let token = oldToken else {
            throw NetworkError.unauthorized
        }
        return token
    }
)

// 4. Create provider and use it
let provider = NetworkProvider(config: config, interceptor: interceptor)
let result = try await provider.perform(yourRoute)
```

**That's it!** You just added support for a new auth scheme.

---

## Built-in Authentication Types

Nevod now includes several ready-to-use authentication types:

### 1. Bearer Token (OAuth 2.0)
```swift
let token = Token(value: "your-access-token")
// Adds: Authorization: Bearer your-access-token
```

**Use case:** Most modern REST APIs, OAuth 2.0

### 2. Cookie-based Session
```swift
let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
let token = CookieToken(sessionCookies: cookies)
// Adds: Cookie: session_id=abc123; path=/
```

**Use case:** Traditional web services, Space-Track.org

**Interceptor:** `CookieAuthenticationInterceptor` (handles session re-login)

### 3. API Key in Header
```swift
let token = APIKeyToken(apiKey: "your-key", headerName: "X-API-Key")
// Adds: X-API-Key: your-key
```

**Use case:** OpenWeatherMap, NewsAPI, simple APIs

### 4. API Key in Query Parameter
```swift
let token = QueryAPIKeyToken(apiKey: "your-key", paramName: "api_key")
// Adds ?api_key=your-key to URL
```

**Use case:** Google Maps API, some public APIs

---

## When You Need a Custom Interceptor

Most auth schemes can use the existing `AuthenticationInterceptor`. You only need a custom interceptor if:

1. **Special retry logic** - Different from standard 401 handling
2. **Token expiration check** - Proactive refresh before expiry
3. **Multi-step auth** - Requires multiple round-trips

### Example: Custom Interceptor for Cookie Auth

The `CookieAuthenticationInterceptor` is a custom interceptor because cookie-based auth has special needs:

```swift
public actor CookieAuthenticationInterceptor: RequestInterceptor {
    // Deduplicates login requests (important for cookies)
    private var loginTask: Task<CookieToken, Error>?
    
    // Uses loginStrategy instead of refreshStrategy
    // (cookies require full re-login, not refresh)
    private let loginStrategy: @Sendable () async throws -> CookieToken
    
    public func retry(...) async throws -> Bool {
        guard case .unauthorized = error else { return false }
        
        // Re-login when session expires
        _ = try await loginIfNeeded()
        return true
    }
}
```

---

## Real-World Examples

### Multiple Services with Different Auth

```swift
actor NetworkContainer {
    // OAuth API
    lazy var oauthProvider: NetworkProvider = {
        let storage = TokenStorage<Token>(storage: keychain, key: .token)
        let interceptor = AuthenticationInterceptor(
            tokenStorage: storage,
            refreshStrategy: { try await refreshOAuth($0) }
        )
        return NetworkProvider(config: oauthConfig, interceptor: interceptor)
    }()
    
    // Cookie-based Legacy API
    lazy var legacyProvider: NetworkProvider = {
        let storage = TokenStorage<CookieToken>(storage: keychain, key: .cookies)
        let interceptor = CookieAuthenticationInterceptor(
            cookieStorage: storage,
            loginStrategy: { try await performLogin() }
        )
        return NetworkProvider(config: legacyConfig, interceptor: interceptor)
    }()
    
    // API Key Third-Party
    lazy var apiKeyProvider: NetworkProvider = {
        let storage = TokenStorage<APIKeyToken>(storage: keychain, key: .apiKey)
        let interceptor = AuthenticationInterceptor(
            tokenStorage: storage,
            refreshStrategy: { $0! } // No refresh needed
        )
        return NetworkProvider(config: apiKeyConfig, interceptor: interceptor)
    }()
}
```

### Conditional Authentication

Some endpoints need auth, others don't:

```swift
let interceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: refreshStrategy,
    shouldAuthenticate: { request in
        // Only authenticate /api/* endpoints
        request.url?.path.hasPrefix("/api/") ?? false
    }
)
```

---

## Complete Example: HMAC Signature Auth

Some APIs require signing requests with HMAC. Here's how to add support:

```swift
import CryptoKit

struct HMACToken: TokenModel {
    let apiKey: String
    let secret: String
    
    func authorize(_ request: inout URLRequest) {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        // Create message to sign
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path ?? ""
        let bodyHash = request.httpBody?.sha256Hex ?? ""
        let message = "\(method)\n\(path)\n\(timestamp)\n\(bodyHash)"
        
        // Create HMAC signature
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        let signatureHex = Data(signature).hexString
        
        // Add headers
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(signatureHex, forHTTPHeaderField: "X-Signature")
    }
    
    func encode() throws -> Data {
        try JSONEncoder().encode(["key": apiKey, "secret": secret])
    }
    
    static func decode(from data: Data) throws -> Self {
        let dict = try JSONDecoder().decode([String: String].self, from: data)
        return HMACToken(apiKey: dict["key"] ?? "", secret: dict["secret"] ?? "")
    }
}

// Helper extensions
extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self).compactMap { String(format: "%02x", $0) }.joined()
    }
    
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
```

Usage:

```swift
let storage = TokenStorage<HMACToken>(storage: keychain, key: .hmac)
await storage.save(HMACToken(apiKey: "key", secret: "secret"))

let interceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { $0! } // Credentials don't expire
)

let provider = NetworkProvider(config: config, interceptor: interceptor)
```

---

## Testing

Mock tokens for unit tests:

```swift
struct MockToken: TokenModel {
    let value: String
    
    func authorize(_ request: inout URLRequest) {
        request.setValue("Mock-\(value)", forHTTPHeaderField: "Authorization")
    }
    
    func encode() throws -> Data { value.data(using: .utf8)! }
    static func decode(from data: Data) throws -> Self {
        MockToken(value: String(data: data, encoding: .utf8)!)
    }
}

// In tests
let storage = TokenStorage<MockToken>(storage: InMemoryStorage())
await storage.save(MockToken(value: "test"))
```

---

## Summary

To add a new authentication scheme:

1. ✅ Create a struct conforming to `TokenModel`
2. ✅ Implement `authorize()` to add auth to requests
3. ✅ Implement `encode()`/`decode()` for persistence
4. ✅ Use existing `AuthenticationInterceptor` (or create custom if needed)
5. ✅ Done!

**That's the power of protocol-oriented design** - you can support any authentication scheme without modifying Nevod's core.

See `AUTHENTICATION_EXAMPLES.md` for more detailed examples.
