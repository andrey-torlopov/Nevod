# Quick Start Guide

[Русская версия](./QuickStart-ru.md)

Get started with Nevod in minutes. This guide covers the most common use cases.

## Table of Contents

- [Basic Setup](#basic-setup)
- [Simple Requests](#simple-requests)
- [Custom Routes](#custom-routes)
- [Authentication](#authentication)
- [Logging](#logging)
- [Error Handling](#error-handling)
- [Multiple Services](#multiple-services)
- [Advanced Features](#advanced-features)

## Basic Setup

### 1. Import Required Modules

```swift
import Nevod
import Core
import Storage  // If using authentication
```

### 2. Define Your Service Domain

```swift
enum MyDomain: ServiceDomain {
    case api
    case cdn
    
    var identifier: String {
        switch self {
        case .api: return "api"
        case .cdn: return "cdn"
        }
    }
}
```

### 3. Create Network Configuration

```swift
let config = NetworkConfig(
    urls: [
        MyDomain.api: (
            test: URL(string: "https://test-api.example.com")!,
            prod: URL(string: "https://api.example.com")!
        )
    ],
    environment: .production,
    timeout: 30,
    retries: 3
)
```

### 4. Create Network Provider

```swift
let provider = NetworkProvider(config: config)
```

## Simple Requests

Nevod provides pre-built route types for common HTTP methods:

### GET Request

```swift
struct User: Decodable {
    let id: Int
    let name: String
    let email: String
}

let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

// Async/await throws style
do {
    let user = try await provider.perform(route)
    print("User: \(user.name)")
} catch {
    print("Error: \(error)")
}

// Result style
let result = await provider.request(route)
switch result {
case .success(let user):
    print("User: \(user.name)")
case .failure(let error):
    print("Error: \(error)")
}
```

### POST Request

```swift
struct CreateUserResponse: Decodable {
    let id: Int
    let name: String
}

let route = SimplePostRoute<CreateUserResponse, MyDomain>(
    endpoint: "/users",
    domain: .api,
    parameters: [
        "name": "John Doe",
        "email": "john@example.com"
    ]
)

let response = try await provider.perform(route)
print("Created user with ID: \(response.id)")
```

### PUT Request

```swift
let route = SimplePutRoute<User, MyDomain>(
    endpoint: "/users/123",
    domain: .api,
    parameters: ["name": "Jane Doe"]
)

let updatedUser = try await provider.perform(route)
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

## Custom Routes

For more complex requests, create custom routes:

```swift
struct GetUserPostsRoute: Route {
    typealias Response = [Post]
    typealias Domain = MyDomain
    
    let userId: Int
    
    var domain: MyDomain { .api }
    var endpoint: String { "/users/\(userId)/posts" }
    var method: HTTPMethod { .get }
    var parameters: [String: String]? {
        ["limit": "10", "offset": "0"]
    }
}

// Usage
let route = GetUserPostsRoute(userId: 123)
let posts = try await provider.perform(route)
```

### POST with JSON Body

```swift
struct LoginRoute: Route {
    typealias Response = AuthResponse
    typealias Domain = MyDomain
    
    let email: String
    let password: String
    
    var domain: MyDomain { .api }
    var endpoint: String { "/auth/login" }
    var method: HTTPMethod { .post }
    var parameterEncoding: ParameterEncoding { .json }
    var parameters: [String: String]? {
        ["email": email, "password": password]
    }
}

// Usage
let route = LoginRoute(email: "user@example.com", password: "secret")
let authResponse = try await provider.perform(route)
```

### Custom Headers

```swift
struct UploadRoute: Route {
    typealias Response = UploadResponse
    typealias Domain = MyDomain
    
    var domain: MyDomain { .api }
    var endpoint: String { "/upload" }
    var method: HTTPMethod { .post }
    var parameters: [String: String]? { nil }
    
    var headers: [String: String]? {
        [
            "Content-Type": "application/octet-stream",
            "X-Upload-Type": "image"
        ]
    }
}
```

## Authentication

### Setup Token Storage

```swift
import Storage

let storage = UserDefaultsStorage()
let tokenStorage = TokenStorage(storage: storage)
```

### Create Auth Interceptor

```swift
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: tokenStorage,
    refreshToken: {
        // Your token refresh logic
        let newToken = try await refreshAccessToken()
        return newToken
    }
)
```

### Create Provider with Auth

```swift
let provider = NetworkProvider(
    config: config,
    interceptor: authInterceptor
)

// All requests will now include Authorization header
// and automatically retry on 401 with token refresh
```

### Complete Auth Example

```swift
// 1. Login
struct LoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

let loginRoute = SimplePostRoute<LoginResponse, MyDomain>(
    endpoint: "/auth/login",
    domain: .api,
    parameters: ["email": "user@example.com", "password": "password"]
)

let loginResponse = try await provider.perform(loginRoute)

// 2. Store token
await tokenStorage.setToken(Token(value: loginResponse.accessToken))

// 3. All subsequent requests are authenticated automatically
let userRoute = SimpleGetRoute<User, MyDomain>(endpoint: "/users/me", domain: .api)
let user = try await provider.perform(userRoute)
```

## Logging

### HTTP Request/Response Logging (OSLog)

```swift
import OSLog

let logger = Logger(subsystem: "com.myapp", category: "Network")

let loggingInterceptor = LoggingInterceptor(
    logger: logger,
    logLevel: .verbose  // .minimal, .detailed, or .verbose
)

let provider = NetworkProvider(
    config: config,
    interceptor: loggingInterceptor
)
```

**Log Levels**:
- `.minimal` - Only logs request method and URL
- `.detailed` - Adds headers and status codes
- `.verbose` - Includes request/response bodies

### Internal Events Logging (Letopis)

```swift
import Letopis

let letopis = Letopis(interceptors: [
    ConsoleInterceptor()
])

let provider = NetworkProvider(
    config: config,
    logger: letopis
)
```

### Combined Logging

```swift
let provider = NetworkProvider(
    config: config,
    interceptor: LoggingInterceptor(logger: logger, logLevel: .verbose),
    logger: Letopis(interceptors: [ConsoleInterceptor()])
)
```

## Error Handling

### NetworkError Types

```swift
public enum NetworkError: Error {
    case invalidURL
    case parsingError
    case timeout
    case noConnection
    case unauthorized
    case clientError(Int)
    case serverError(Int)
    case bodyEncodingFailed
    case unknown(Error)
}
```

### Handling Errors

```swift
do {
    let user = try await provider.perform(route)
    print("Success: \(user)")
} catch let error as NetworkError {
    switch error {
    case .unauthorized:
        // Redirect to login
        print("User not authorized")
    case .timeout:
        // Show retry option
        print("Request timed out")
    case .noConnection:
        // Show offline message
        print("No internet connection")
    case .parsingError:
        // Log parsing issue
        print("Failed to parse response")
    case .clientError(let code):
        print("Client error: \(code)")
    case .serverError(let code):
        print("Server error: \(code)")
    default:
        print("Unknown error: \(error)")
    }
}
```

## Multiple Services

### Define Multiple Domains

```swift
enum AppDomains: ServiceDomain {
    case mainAPI
    case analyticsAPI
    case cdn
    
    var identifier: String {
        switch self {
        case .mainAPI: return "main"
        case .analyticsAPI: return "analytics"
        case .cdn: return "cdn"
        }
    }
}
```

### Configure Multiple URLs

```swift
let config = NetworkConfig(
    urls: [
        AppDomains.mainAPI: (
            test: URL(string: "https://test-api.example.com")!,
            prod: URL(string: "https://api.example.com")!
        ),
        AppDomains.analyticsAPI: (
            test: URL(string: "https://test-analytics.example.com")!,
            prod: URL(string: "https://analytics.example.com")!
        ),
        AppDomains.cdn: (
            test: URL(string: "https://test-cdn.example.com")!,
            prod: URL(string: "https://cdn.example.com")!
        )
    ],
    environment: .production
)
```

### Use Different Domains

```swift
// Main API request
let userRoute = SimpleGetRoute<User, AppDomains>(
    endpoint: "/users/me",
    domain: .mainAPI  // → api.example.com
)

// Analytics request
let trackRoute = SimplePostRoute<TrackResponse, AppDomains>(
    endpoint: "/events",
    domain: .analyticsAPI,  // → analytics.example.com
    parameters: ["event": "page_view"]
)

// CDN request
let imageRoute = SimpleGetRoute<Data, AppDomains>(
    endpoint: "/images/logo.png",
    domain: .cdn  // → cdn.example.com
)
```

## Advanced Features

### Combining Multiple Interceptors

```swift
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        LoggingInterceptor(logger: logger, logLevel: .detailed),
        HeadersInterceptor(headers: [
            "User-Agent": "MyApp/1.0",
            "X-Client-Platform": "iOS"
        ]),
        AuthenticationInterceptor(
            tokenStorage: tokenStorage,
            refreshToken: { try await refreshToken() }
        )
    ])
)
```

**Execution Order**:
1. Logging logs the request
2. Headers adds custom headers
3. Auth adds Authorization header
4. Request sent to network
5. On 401: Auth refreshes token and retries
6. Response logged

### Custom Interceptor

```swift
public actor RateLimitInterceptor: RequestInterceptor {
    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval
    
    public init(minimumInterval: TimeInterval = 1.0) {
        self.minimumInterval = minimumInterval
    }
    
    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                try await Task.sleep(nanoseconds: UInt64((minimumInterval - elapsed) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
        return request
    }
}

// Usage
let provider = NetworkProvider(
    config: config,
    interceptor: RateLimitInterceptor(minimumInterval: 0.5)
)
```

### Response as Raw Data

```swift
let route = SimpleGetRoute<Data, MyDomain>(
    endpoint: "/download/file.pdf",
    domain: .api
)

let pdfData = try await provider.perform(route)
// Use pdfData directly
```

### Task Delegation for Progress Tracking

```swift
class DownloadDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        print("Upload progress: \(progress * 100)%")
    }
}

let delegate = DownloadDelegate()
let result = await provider.request(uploadRoute, delegate: delegate)
```

## Best Practices

1. **Reuse NetworkProvider**: Create once, use throughout your app
2. **Define Domains Clearly**: Use meaningful domain identifiers
3. **Handle Errors Gracefully**: Always handle NetworkError cases
4. **Use Simple Routes**: Prefer `SimpleGetRoute`, etc. for standard requests
5. **Custom Routes for Complex Cases**: Only create custom Route when needed
6. **Interceptor Order Matters**: Put logging first, auth last in chain
7. **Environment Switching**: Use `.test` during development, `.production` for release
8. **Token Security**: Use secure storage (Keychain) for production tokens

## Next Steps

- Explore [Installation Guide](./Installation.md) for dependencies
- Check [API Reference](./API.md) for complete documentation
- Review source code examples in the repository

## Common Patterns

### Repository Pattern

```swift
protocol UserRepository {
    func getCurrentUser() async throws -> User
    func updateUser(_ user: User) async throws -> User
}

class NetworkUserRepository: UserRepository {
    private let provider: NetworkProvider
    
    init(provider: NetworkProvider) {
        self.provider = provider
    }
    
    func getCurrentUser() async throws -> User {
        let route = SimpleGetRoute<User, MyDomain>(
            endpoint: "/users/me",
            domain: .api
        )
        return try await provider.perform(route)
    }
    
    func updateUser(_ user: User) async throws -> User {
        let route = SimplePutRoute<User, MyDomain>(
            endpoint: "/users/\(user.id)",
            domain: .api,
            parameters: ["name": user.name, "email": user.email]
        )
        return try await provider.perform(route)
    }
}
```

### Dependency Injection

```swift
@MainActor
class UserViewModel: ObservableObject {
    @Published var user: User?
    @Published var error: NetworkError?
    
    private let provider: NetworkProvider
    
    init(provider: NetworkProvider) {
        self.provider = provider
    }
    
    func loadUser() async {
        let route = SimpleGetRoute<User, MyDomain>(
            endpoint: "/users/me",
            domain: .api
        )
        
        do {
            self.user = try await provider.perform(route)
        } catch let error as NetworkError {
            self.error = error
        }
    }
}
```

Happy coding with Nevod!
