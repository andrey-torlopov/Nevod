# Quick Start Guide

[Русская версия](../ru/QuickStart.md)

Get started with Nevod in minutes. This guide covers the essential steps to integrate Nevod into your project.

## Installation

Add Nevod to your `Package.swift`:

```swift
dependencies: [
    .package(url: "git@github.com:andrey-torlopov/Nevod.git", from: "0.0.2")
]
```

## Basic Setup

### 1. Define Service Domain

```swift
import Nevod

enum MyDomain: ServiceDomain {
    case api
    
    var identifier: String { "api" }
}
```

### 2. Create Configuration

```swift
let config = NetworkConfig(
    environments: [
        MyDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!
        )
    ],
    timeout: 30,
    retries: 3
)
```

### 3. Create Provider

```swift
let provider = NetworkProvider(config: config)
```

## Making Requests

### GET Request

```swift
struct User: Decodable {
    let id: Int
    let name: String
}

let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

let user = try await provider.perform(route)
```

### POST Request

```swift
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
}

let route = SimplePostRoute<User, MyDomain>(
    endpoint: "/users",
    domain: .api,
    parameters: ["name": "John", "email": "john@example.com"]
)

let user = try await provider.perform(route)
```

### PUT Request

```swift
let route = SimplePutRoute<User, MyDomain>(
    endpoint: "/users/123",
    domain: .api,
    parameters: ["name": "Jane"]
)

let user = try await provider.perform(route)
```

### DELETE Request

```swift
struct DeleteResponse: Decodable {
    let success: Bool
}

let route = SimpleDeleteRoute<DeleteResponse, MyDomain>(
    endpoint: "/users/123",
    domain: .api
)

let response = try await provider.perform(route)
```

## Authentication

Nevod supports multiple authentication methods out of the box.

### Bearer Token

```swift
// 1. Create storage
let storage = TokenStorage<Token>(storage: yourKeyValueStorage)

// 2. Create auth interceptor
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        let newToken = try await refreshToken(oldToken?.value)
        return Token(value: newToken)
    }
)

// 3. Create provider with auth
let provider = NetworkProvider(
    config: config,
    interceptor: authInterceptor
)
```

### Cookie Authentication

```swift
let cookieStorage = TokenStorage<CookieToken>(storage: keychain)

let cookieInterceptor = CookieAuthenticationInterceptor(
    cookieStorage: cookieStorage,
    loginStrategy: {
        let response = try await performLogin(email: email, password: password)
        let cookies = HTTPCookieStorage.shared.cookies(for: loginURL) ?? []
        return CookieToken(sessionCookies: cookies)
    }
)

let provider = NetworkProvider(config: config, interceptor: cookieInterceptor)
```

### API Key (Header)

```swift
let token = APIKeyToken(apiKey: "your-key", headerName: "X-API-Key")
let storage = TokenStorage<APIKeyToken>(storage: userDefaults)
await storage.save(token)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { _ in throw NetworkError.unauthorized }
)
```

### API Key (Query Parameter)

```swift
let token = QueryAPIKeyToken(apiKey: "your-key", paramName: "api_key")
let storage = TokenStorage<QueryAPIKeyToken>(storage: userDefaults)
await storage.save(token)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { _ in throw NetworkError.unauthorized }
)
```

## Logging

### HTTP Request/Response Logging

```swift
import OSLog

let logger = Logger(subsystem: "com.myapp", category: "Network")
let loggingInterceptor = LoggingInterceptor(logger: logger, logLevel: .verbose)

let provider = NetworkProvider(
    config: config,
    interceptor: loggingInterceptor
)
```

## Error Handling

```swift
do {
    let user = try await provider.perform(route)
} catch let error as NetworkError {
    switch error {
    case .unauthorized:
        // Handle auth error
    case .timeout:
        // Handle timeout
    case .noConnection:
        // Handle no connection
    case .parsingError:
        // Handle parsing error
    case .clientError(let code):
        // Handle client error
    case .serverError(let code):
        // Handle server error
    default:
        // Handle other errors
    }
}
```

## Multiple Services

```swift
enum AppDomains: ServiceDomain {
    case mainAPI
    case cdn
    
    var identifier: String {
        switch self {
        case .mainAPI: return "main"
        case .cdn: return "cdn"
        }
    }
}

let config = NetworkConfig(
    environments: [
        AppDomains.mainAPI: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!
        ),
        AppDomains.cdn: SimpleEnvironment(
            baseURL: URL(string: "https://cdn.example.com")!
        )
    ]
)

// Use different domains
let userRoute = SimpleGetRoute<User, AppDomains>(
    endpoint: "/users/me",
    domain: .mainAPI
)

let imageRoute = SimpleGetRoute<Data, AppDomains>(
    endpoint: "/images/avatar.png",
    domain: .cdn
)
```

## Combining Interceptors

```swift
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        LoggingInterceptor(logger: logger, logLevel: .detailed),
        HeadersInterceptor(headers: ["User-Agent": "MyApp/1.0"]),
        AuthenticationInterceptor(tokenStorage: storage, refreshStrategy: refreshBlock)
    ])
)
```

## Custom Routes

For more control, create custom routes:

```swift
struct GetUserPostsRoute: Route {
    typealias Response = [Post]
    typealias Domain = MyDomain
    
    let userId: Int
    
    var domain: MyDomain { .api }
    var endpoint: String { "/users/\(userId)/posts" }
    var method: HTTPMethod { .get }
    var parameters: [String: String]? {
        ["limit": "10"]
    }
}

let route = GetUserPostsRoute(userId: 123)
let posts = try await provider.perform(route)
```

## KeyValueStorage Implementation

For token storage, implement `KeyValueStorage`:

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

**Note:** For production, use Keychain for secure token storage.

## Next Steps

- [Authentication Guide](./Authentication.md) - Learn about all authentication methods
- [Installation Guide](./Installation.md) - Setup details

For more information, check the main [README](../../README.md).
