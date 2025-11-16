# Authentication Examples for Nevod

This document demonstrates how to use different authentication schemes with Nevod's flexible architecture.

## Architecture Overview

Nevod's authentication is built on three key protocols:

1. **TokenModel** - Defines how tokens are applied to requests and serialized
2. **RequestInterceptor** - Handles request adaptation and retry logic
3. **TokenStorage** - Manages token persistence and caching

This design allows you to easily add new authentication schemes by implementing `TokenModel` and optionally creating a custom interceptor.

---

## 1. Bearer Token Authentication (OAuth 2.0)

Most modern REST APIs use Bearer tokens in the Authorization header.

```swift
import Nevod

// 1. Create token storage
let tokenStorage = TokenStorage<Token>(
    storage: keychain,
    key: StorageKey(value: "bearer_token")
)

// 2. Create authentication interceptor with refresh logic
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: tokenStorage,
    refreshStrategy: { oldToken in
        // Call your refresh endpoint
        let refreshRoute = RefreshTokenRoute(refreshToken: oldToken?.value ?? "")
        let newToken = try await networkProvider.perform(refreshRoute)
        return Token(value: newToken.accessToken)
    },
    shouldAuthenticate: { request in
        // Authenticate all requests to your API
        return request.url?.host?.contains("api.yourservice.com") ?? false
    }
)

// 3. Create network provider with interceptor
let config = NetworkConfig(
    environments: [
        YourDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://api.yourservice.com")!
        )
    ],
    timeout: 30
)

let provider = NetworkProvider(
    config: config,
    interceptor: authInterceptor
)

// 4. Use it!
let route = GetUserRoute()
let user = try await provider.perform(route)
```

**How it works:**
- Initial request automatically includes `Authorization: Bearer {token}`
- If server returns 401, interceptor calls refresh strategy
- Fresh token is saved and request is retried
- All concurrent requests wait for the same refresh operation

---

## 2. Cookie-based Authentication

Traditional session-based authentication used by many web services.

```swift
import Nevod

// 1. Create cookie storage
let cookieStorage = TokenStorage<CookieToken>(
    storage: keychain,
    key: StorageKey(value: "session_cookies")
)

// 2. Create cookie authentication interceptor
let cookieInterceptor = CookieAuthenticationInterceptor(
    cookieStorage: cookieStorage,
    loginStrategy: {
        // Perform login and extract cookies
        let cookies = try await performLogin(
            email: "user@example.com",
            password: "password123"
        )
        return CookieToken(sessionCookies: cookies)
    },
    shouldAuthenticate: { request in
        // Only for your cookie-based service
        return request.url?.host?.contains("space-track.org") ?? false
    }
)

// 3. Create network provider
let config = NetworkConfig(
    environments: [
        SpaceTrackDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://www.space-track.org")!
        )
    ]
)

let provider = NetworkProvider(
    config: config,
    interceptor: cookieInterceptor
)

// 4. Helper login function
func performLogin(email: String, password: String) async throws -> [HTTPCookie] {
    let loginURL = URL(string: "https://www.space-track.org/ajaxauth/login")!
    
    var request = URLRequest(url: loginURL)
    request.httpMethod = "POST"
    request.httpBody = "identity=\(email)&password=\(password)".data(using: .utf8)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    
    let (_, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NetworkError.unauthorized
    }
    
    let cookies = HTTPCookieStorage.shared.cookies(for: loginURL) ?? []
    guard !cookies.isEmpty else {
        throw NetworkError.unauthorized
    }
    
    return cookies
}

// 5. Use it - login happens automatically on first request or after 401
let route = FetchTLERoute()
let tleData = try await provider.perform(route)
```

**How it works:**
- First request triggers login if no cookies exist
- Cookies are automatically applied to all subsequent requests
- If session expires (401), interceptor re-authenticates
- Fresh cookies are saved and request is retried

---

## 3. API Key Authentication

Simple API key in headers or query parameters.

### Header-based API Key

```swift
import Nevod

// 1. Create custom token type
struct APIKeyToken: TokenModel {
    let apiKey: String
    let headerName: String
    
    func authorize(_ request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: headerName)
    }
    
    func encode() throws -> Data {
        try JSONEncoder().encode(["key": apiKey, "header": headerName])
    }
    
    static func decode(from data: Data) throws -> Self {
        let dict = try JSONDecoder().decode([String: String].self, from: data)
        return APIKeyToken(
            apiKey: dict["key"] ?? "",
            headerName: dict["header"] ?? "X-API-Key"
        )
    }
}

// 2. Create storage
let apiKeyStorage = TokenStorage<APIKeyToken>(
    storage: keychain,
    key: StorageKey(value: "api_key")
)

// 3. Save your API key
await apiKeyStorage.save(
    APIKeyToken(apiKey: "your-api-key-here", headerName: "X-API-Key")
)

// 4. Use simple interceptor (no refresh needed for API keys)
actor SimpleAPIKeyInterceptor: RequestInterceptor {
    let storage: TokenStorage<APIKeyToken>
    
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        await storage.load()?.authorize(&req)
        return req
    }
    
    func retry(_ request: URLRequest, response: HTTPURLResponse?, error: NetworkError) async throws -> Bool {
        return false // API keys don't refresh
    }
}

let interceptor = SimpleAPIKeyInterceptor(storage: apiKeyStorage)
let provider = NetworkProvider(config: config, interceptor: interceptor)
```

### Query Parameter API Key

```swift
struct QueryAPIKeyToken: TokenModel {
    let apiKey: String
    let paramName: String
    
    func authorize(_ request: inout URLRequest) {
        guard var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) else {
            return
        }
        
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: paramName, value: apiKey))
        components.queryItems = queryItems
        request.url = components.url
    }
    
    // encode/decode implementation...
}
```

---

## 4. Multiple Authentication Schemes

Use different providers for different services.

```swift
import Nevod

actor NetworkContainer {
    let keychain: KeyValueStorage
    
    // Bearer token provider (for main API)
    lazy var bearerProvider: NetworkProvider = {
        let tokenStorage = TokenStorage<Token>(
            storage: keychain,
            key: StorageKey(value: "bearer_token")
        )
        
        let authInterceptor = AuthenticationInterceptor(
            tokenStorage: tokenStorage,
            refreshStrategy: { oldToken in
                // OAuth refresh logic
                try await refreshOAuthToken(oldToken)
            }
        )
        
        return NetworkProvider(
            config: mainAPIConfig,
            interceptor: authInterceptor
        )
    }()
    
    // Cookie provider (for legacy service)
    lazy var cookieProvider: NetworkProvider = {
        let cookieStorage = TokenStorage<CookieToken>(
            storage: keychain,
            key: StorageKey(value: "session_cookies")
        )
        
        let cookieInterceptor = CookieAuthenticationInterceptor(
            cookieStorage: cookieStorage,
            loginStrategy: {
                try await performCookieLogin()
            },
            shouldAuthenticate: { request in
                request.url?.host?.contains("legacy-service.com") ?? false
            }
        )
        
        return NetworkProvider(
            config: legacyServiceConfig,
            interceptor: cookieInterceptor
        )
    }()
    
    // API key provider (for third-party service)
    lazy var apiKeyProvider: NetworkProvider = {
        let storage = TokenStorage<APIKeyToken>(
            storage: keychain,
            key: StorageKey(value: "third_party_api_key")
        )
        
        let interceptor = SimpleAPIKeyInterceptor(storage: storage)
        
        return NetworkProvider(
            config: thirdPartyConfig,
            interceptor: interceptor
        )
    }()
}

// Usage in your app
let container = NetworkContainer(keychain: secureKeychain)

// Different services use appropriate providers
let mainService = MainAPIService(provider: container.bearerProvider)
let legacyService = LegacyService(provider: container.cookieProvider)
let thirdPartyService = ThirdPartyService(provider: container.apiKeyProvider)
```

---

## 5. Custom Authentication Schemes

You can implement any authentication scheme by conforming to `TokenModel`.

### Example: HMAC Signature

```swift
struct HMACToken: TokenModel {
    let apiKey: String
    let secret: String
    
    func authorize(_ request: inout URLRequest) {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        
        // Create signature from request data
        let message = """
        \(request.httpMethod ?? "GET")
        \(request.url?.path ?? "")
        \(timestamp)
        \(request.httpBody?.sha256 ?? "")
        """
        
        let signature = message.hmacSHA256(key: secret)
        
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
    }
    
    // encode/decode implementation...
}
```

### Example: Multi-header Authentication

```swift
struct MultiHeaderToken: TokenModel {
    let headers: [String: String]
    
    func authorize(_ request: inout URLRequest) {
        headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    // encode/decode implementation...
}

// Usage
let token = MultiHeaderToken(headers: [
    "X-Client-ID": "client123",
    "X-Client-Secret": "secret456",
    "X-Session-Token": "session789"
])
```

---

## 6. Interceptor Chains

Combine multiple interceptors for complex scenarios.

```swift
let chain = InterceptorChain(interceptors: [
    LoggingInterceptor(),           // Log all requests
    HeadersInterceptor(headers: [   // Add common headers
        "Accept": "application/json",
        "User-Agent": "MyApp/1.0"
    ]),
    CookieAuthenticationInterceptor(...),  // Handle auth
])

let provider = NetworkProvider(config: config, interceptor: chain)
```

**Execution order:**
- **adapt()**: first → last (logging → headers → auth)
- **retry()**: last → first (auth handles 401 first)

---

## 7. Testing

Mock authentication for unit tests.

```swift
struct MockToken: TokenModel {
    let value: String
    
    func authorize(_ request: inout URLRequest) {
        request.setValue("Mock-\(value)", forHTTPHeaderField: "Authorization")
    }
    
    func encode() throws -> Data {
        value.data(using: .utf8)!
    }
    
    static func decode(from data: Data) throws -> Self {
        MockToken(value: String(data: data, encoding: .utf8)!)
    }
}

// In tests
let mockStorage = InMemoryStorage()
let tokenStorage = TokenStorage<MockToken>(storage: mockStorage)
await tokenStorage.save(MockToken(value: "test-token"))

// No network calls, no real auth
```

---

## Best Practices

### 1. Separate Providers by Auth Scheme
✅ Do: One provider per authentication type
```swift
let oauthProvider = NetworkProvider(config: config, interceptor: oauthInterceptor)
let cookieProvider = NetworkProvider(config: config, interceptor: cookieInterceptor)
```

❌ Don't: Try to handle multiple auth types in one provider
```swift
// Anti-pattern
let universalProvider = NetworkProvider(config: config, interceptor: confusedInterceptor)
```

### 2. Use Dependency Injection
✅ Do: Inject providers into services
```swift
actor MyService {
    let provider: NetworkProvider
    
    init(provider: NetworkProvider) {
        self.provider = provider
    }
}
```

### 3. Secure Storage
✅ Do: Use Keychain for sensitive tokens
```swift
import KeychainAccess
let keychain = Keychain(service: "com.yourapp.nevod")
let storage = KeychainStorage(keychain: keychain)
```

❌ Don't: Store tokens in UserDefaults
```swift
// Insecure!
let storage = UserDefaultsStorage()
```

### 4. Handle Errors Gracefully
```swift
do {
    let data = try await provider.perform(route)
} catch NetworkError.unauthorized {
    // Show login screen
} catch NetworkError.serverError(let statusCode, _) {
    // Handle server errors
} catch {
    // Handle other errors
}
```

---

## Extending Nevod

To add a new authentication scheme:

1. **Create a TokenModel**
   ```swift
   struct MyCustomToken: TokenModel {
       // Your token data
       
       func authorize(_ request: inout URLRequest) {
           // Apply auth to request
       }
       
       func encode() throws -> Data { ... }
       static func decode(from data: Data) throws -> Self { ... }
   }
   ```

2. **Optionally create a custom interceptor** (if you need special retry logic)
   ```swift
   actor MyCustomInterceptor: RequestInterceptor {
       func adapt(_ request: URLRequest) async throws -> URLRequest { ... }
       func retry(...) async throws -> Bool { ... }
   }
   ```

3. **Use it!**
   ```swift
   let storage = TokenStorage<MyCustomToken>(...)
   let interceptor = MyCustomInterceptor(storage: storage)
   let provider = NetworkProvider(config: config, interceptor: interceptor)
   ```

That's it! Nevod's protocol-oriented design makes it easy to support any authentication scheme.
