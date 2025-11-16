# Authentication Guide

[Русская версия](../ru/Authentication.md)

Nevod provides a flexible, generic token system that supports multiple authentication methods out of the box.

## Overview

Nevod's authentication system is based on:
- **TokenModel** protocol - Define any token type
- **TokenStorage<Token>** - Generic, type-safe token storage
- **AuthenticationInterceptor<Token>** - Automatic token injection and refresh
- **CookieAuthenticationInterceptor** - Specialized cookie-based session management

## Built-in Token Types

### 1. Bearer Token

Standard OAuth 2.0 Bearer token authentication.

```swift
import Nevod

// Create token
let token = Token(value: "your-access-token")

// Setup storage
let storage = TokenStorage<Token>(storage: keychain)
await storage.save(token)

// Create auth interceptor
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        guard let oldToken = oldToken else {
            throw NetworkError.unauthorized
        }
        
        // Call your refresh endpoint
        let response: RefreshResponse = try await authService.refresh(oldToken.value)
        return Token(value: response.accessToken)
    }
)

// Create provider
let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

**How it works:**
- Adds `Authorization: Bearer {token}` header to requests
- On 401 error, calls refreshStrategy
- Retries request with new token
- Deduplicates concurrent refresh calls

### 2. Cookie Authentication

Session-based authentication using HTTP cookies.

```swift
import Nevod

let cookieStorage = TokenStorage<CookieToken>(storage: keychain)

let cookieInterceptor = CookieAuthenticationInterceptor(
    cookieStorage: cookieStorage,
    loginStrategy: {
        // Your login logic
        let credentials = ["email": email, "password": password]
        let loginURL = URL(string: "https://api.example.com/login")!
        
        // Perform login
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(credentials)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        // Extract cookies
        if let httpResponse = response as? HTTPURLResponse,
           let cookies = HTTPCookie.cookies(withResponseHeaderFields: 
               httpResponse.allHeaderFields as? [String: String] ?? [:],
               for: loginURL) {
            return CookieToken(sessionCookies: cookies)
        }
        
        throw NetworkError.unauthorized
    }
)

let provider = NetworkProvider(config: config, interceptor: cookieInterceptor)
```

**Use cases:**
- Traditional web APIs
- Services that don't support OAuth
- Legacy systems
- APIs like Space-Track.org

### 3. API Key (Header)

API key passed in a custom header.

```swift
import Nevod

let apiKeyToken = APIKeyToken(
    apiKey: "your-api-key-12345",
    headerName: "X-API-Key"  // Customize header name
)

let storage = TokenStorage<APIKeyToken>(storage: userDefaults)
await storage.save(apiKeyToken)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { _ in
        // API keys typically don't refresh
        throw NetworkError.unauthorized
    }
)

let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

**Use cases:**
- OpenWeatherMap
- NewsAPI
- Many public APIs

### 4. API Key (Query Parameter)

API key passed as a URL query parameter.

```swift
import Nevod

let queryToken = QueryAPIKeyToken(
    apiKey: "your-api-key-12345",
    paramName: "api_key"  // or "key", "apikey", etc.
)

let storage = TokenStorage<QueryAPIKeyToken>(storage: userDefaults)
await storage.save(queryToken)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { _ in throw NetworkError.unauthorized }
)

// Requests to /users?limit=10 become /users?limit=10&api_key=your-api-key-12345
let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

**Use cases:**
- Google Maps API
- Some weather services
- APIs that require query-based auth

## Custom Token Types

Create your own token type for complex authentication schemes:

```swift
import Nevod

struct OAuthToken: TokenModel, Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
    // TokenModel conformance
    func authorize(_ request: inout URLRequest) {
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}

// Usage
let storage = TokenStorage<OAuthToken>(storage: keychain)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        guard let oldToken = oldToken else {
            throw NetworkError.unauthorized
        }
        
        // Call OAuth refresh endpoint
        let response: OAuthResponse = try await oauthService.refresh(
            refreshToken: oldToken.refreshToken
        )
        
        return OAuthToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn)
        )
    }
)
```

## KeyValueStorage Implementation

Implement `KeyValueStorage` for token persistence:

### UserDefaults (Development)

```swift
final class UserDefaultsStorage: KeyValueStorage {
    private let defaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }
    
    nonisolated func string(for key: StorageKey) -> String? {
        defaults.string(forKey: key.rawValue)
    }
    
    nonisolated func data(for key: StorageKey) -> Data? {
        defaults.data(forKey: key.rawValue)
    }
    
    nonisolated func set(_ value: String?, for key: StorageKey) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    nonisolated func set(_ value: Data?, for key: StorageKey) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    nonisolated func remove(for key: StorageKey) {
        defaults.removeObject(forKey: key.rawValue)
    }
}
```

### Keychain (Production)

```swift
import Security

final class KeychainStorage: KeyValueStorage {
    private let service: String
    
    init(service: String = Bundle.main.bundleIdentifier ?? "com.app") {
        self.service = service
    }
    
    nonisolated func data(for key: StorageKey) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    nonisolated func set(_ value: Data?, for key: StorageKey) {
        guard let value = value else {
            remove(for: key)
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        // Try to update first
        let attributes: [String: Any] = [kSecValueData as String: value]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status == errSecItemNotFound {
            // Item doesn't exist, add it
            var newItem = query
            newItem[kSecValueData as String] = value
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
    
    nonisolated func remove(for key: StorageKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    nonisolated func string(for key: StorageKey) -> String? {
        guard let data = data(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    nonisolated func set(_ value: String?, for key: StorageKey) {
        set(value?.data(using: .utf8), for: key)
    }
}
```

## Multiple Authentication Methods

Use different auth for different domains:

```swift
enum AppDomains: ServiceDomain {
    case mainAPI      // OAuth
    case adminAPI     // API Key
    case legacyAPI    // Cookie
    
    var identifier: String {
        switch self {
        case .mainAPI: return "main"
        case .adminAPI: return "admin"
        case .legacyAPI: return "legacy"
        }
    }
}

// OAuth for main API
let oauthStorage = TokenStorage<OAuthToken>(storage: keychain)
let oauthInterceptor = AuthenticationInterceptor(
    tokenStorage: oauthStorage,
    refreshStrategy: { /* OAuth refresh */ },
    shouldAuthenticate: { $0.url?.host == "api.example.com" }
)

// API Key for admin
let apiKeyStorage = TokenStorage<APIKeyToken>(storage: keychain)
let apiKeyInterceptor = AuthenticationInterceptor(
    tokenStorage: apiKeyStorage,
    refreshStrategy: { _ in throw NetworkError.unauthorized },
    shouldAuthenticate: { $0.url?.host == "admin.example.com" }
)

// Cookie for legacy
let cookieStorage = TokenStorage<CookieToken>(storage: keychain)
let cookieInterceptor = CookieAuthenticationInterceptor(
    cookieStorage: cookieStorage,
    loginStrategy: { /* login logic */ },
    shouldAuthenticate: { $0.url?.host == "legacy.example.com" }
)

// Combine all
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        oauthInterceptor,
        apiKeyInterceptor,
        cookieInterceptor
    ])
)
```

## Login Flow Example

```swift
class AuthService {
    private let provider: NetworkProvider
    private let tokenStorage: TokenStorage<Token>
    
    init(provider: NetworkProvider, tokenStorage: TokenStorage<Token>) {
        self.provider = provider
        self.tokenStorage = tokenStorage
    }
    
    func login(email: String, password: String) async throws {
        let route = SimplePostRoute<LoginResponse, MyDomain>(
            endpoint: "/auth/login",
            domain: .api,
            parameters: ["email": email, "password": password]
        )
        
        let response = try await provider.perform(route)
        
        // Save token
        let token = Token(value: response.accessToken)
        await tokenStorage.save(token)
    }
    
    func logout() async {
        await tokenStorage.clear()
    }
    
    func isAuthenticated() async -> Bool {
        await tokenStorage.load() != nil
    }
}
```

## Best Practices

1. **Use Keychain for production** - Never store tokens in UserDefaults for production apps
2. **Clear tokens on logout** - Call `await tokenStorage.clear()`
3. **Handle refresh failures** - Show login screen when refresh fails
4. **Deduplicate requests** - TokenStorage and interceptors handle this automatically
5. **Custom token types** - Create your own TokenModel for complex schemes
6. **Test refresh logic** - Mock refresh strategy in tests
7. **Secure storage** - Use Keychain with proper access control
8. **Token expiration** - Include expiry in custom token types
9. **Concurrent safety** - All operations are actor-isolated

## See Also

- [Quick Start Guide](./QuickStart.md)
- [Advanced Usage](./Advanced.md)
