# Nevod

<p align="center">
  <img src="Docs/banner.png" alt="Nevod banner" width="600"/>
</p>

<p align="center">
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg?logo=swift" />
  </a>
  <a href="https://swift.org/package-manager/">
    <img src="https://img.shields.io/badge/SPM-compatible-green.svg" />
  </a>
  <img src="https://img.shields.io/badge/platforms-iOS%2017.0+%20|%20macOS%2015.0+-blue.svg" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-lightgrey.svg" />
  </a>
</p>

<p align="center">
  <b>Modern, lightweight and flexible networking layer for Swift with interceptor pattern support.</b>
</p>

<p align="center">
  <a href="README-ru.md">Русская версия</a>
</p>

## Overview

Nevod is a Swift networking library designed with simplicity and flexibility in mind. It provides a clean API for basic requests while offering powerful features like interceptors, multiple service domains, and automatic token refresh for advanced use cases.

Built on modern Swift concurrency (async/await) and actor-based architecture for thread-safety.

## Key Features

- **Simple API** - Minimal boilerplate for basic requests
- **Interceptor Pattern** - Flexible middleware system for request adaptation and retry logic
- **Multiple Services** - Easy management of different API endpoints
- **Generic Token System** - Flexible authentication with any token type
- **OAuth Support** - Built-in automatic token refresh handling with custom strategies
- **Type-Safe** - Protocol-oriented design with full type safety
- **Modern Swift** - async/await and actor-based concurrency
- **Testable** - Dependency injection friendly architecture
- **Logging** - Integrated support for request/response logging via OSLog and Letopis

## Quick Example

```swift
// Define your service domain
enum MyDomain: ServiceDomain {
    case api
    var identifier: String { "api" }
}

// Create a simple GET request
let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

// Execute request
let user = try await provider.perform(route)
```

## Installation

See [Installation Guide](./Docs/Installation.md) for detailed setup instructions.

**Swift Package Manager:**

```swift
dependencies: [
    .package(url: "git@github.com:andrey-torlopov/Nevod.git", from: "0.0.2")
]
```

## Documentation

- [Quick Start Guide](./Docs/QuickStart.md) - Get started in minutes
- [Installation](./Docs/Installation.md) - Detailed installation and dependencies
- [API Reference](./Docs/API.md) - Complete API documentation

## Core Components

### Routes
Define your API endpoints with type-safe routes:
- `Route` protocol for custom endpoints
- `SimpleGetRoute`, `SimplePostRoute`, `SimplePutRoute`, `SimpleDeleteRoute` for common cases

### Interceptors
Modify requests and handle retries:
- `AuthenticationInterceptor<Token>` - Generic token management with custom refresh strategies
- `LoggingInterceptor` - HTTP request/response logging
- `HeadersInterceptor` - Add custom headers
- `InterceptorChain` - Combine multiple interceptors

### Token System
Flexible authentication with any token type:
- `TokenModel` protocol - Define your own token types
- `TokenStorage<Token>` - Generic token storage
- Built-in `Token` - Simple Bearer token implementation

### Network Provider
Actor-based network executor with automatic retries and error handling.

## Usage Patterns

### Basic Request
```swift
let route = SimpleGetRoute<User, MyDomain>(endpoint: "/users/me", domain: .api)
let user = try await provider.perform(route)
```

### With Simple Bearer Token
```swift
// Create token storage
let storage = TokenStorage<Token>(storage: myKeyValueStorage)

// Create authentication interceptor
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        // Your refresh logic here
        let newTokenValue = try await authService.refreshToken(oldToken?.value)
        return Token(value: newTokenValue)
    }
)

let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

### With Custom Token Type (OAuth)
```swift
// Define your custom token
struct OAuthToken: TokenModel, Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

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

// Use with storage and interceptor
let storage = TokenStorage<OAuthToken>(storage: myStorage)
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        guard let oldToken = oldToken else { throw NetworkError.unauthorized }

        // Call refresh endpoint
        let response: OAuthResponse = try await baseClient.request(
            .post,
            path: "/oauth/refresh",
            body: ["refresh_token": oldToken.refreshToken]
        )

        return OAuthToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn)
        )
    }
)
```

### Multiple Domains with Different Authentication
```swift
// OAuth for api.example.com
let oauthStorage = TokenStorage<OAuthToken>(storage: keychainStorage)
let oauthInterceptor = AuthenticationInterceptor(
    tokenStorage: oauthStorage,
    refreshStrategy: { /* OAuth refresh */ },
    shouldAuthenticate: { $0.url?.host == "api.example.com" }
)

// API Key for admin.example.com
let apiKeyStorage = TokenStorage<APIKeyToken>(storage: userDefaults)
let apiKeyInterceptor = AuthenticationInterceptor(
    tokenStorage: apiKeyStorage,
    refreshStrategy: { /* API key refresh */ },
    shouldAuthenticate: { $0.url?.host == "admin.example.com" }
)

// Combine both
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([oauthInterceptor, apiKeyInterceptor])
)
```

### Multiple Interceptors
```swift
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        LoggingInterceptor(logger: logger, logLevel: .verbose),
        HeadersInterceptor(headers: ["User-Agent": "MyApp/1.0"]),
        AuthenticationInterceptor(tokenStorage: storage, refreshStrategy: refreshBlock)
    ])
)
```

## Architecture Benefits

✅ **Separation of Concerns** - Token models, storage, and refresh logic are separated
✅ **Flexibility** - Support any token type through protocols
✅ **Scalability** - Multiple interceptors for different domains
✅ **Type-Safety** - Strong typing through generics
✅ **Testability** - Easy to mock storage and refresh strategies
✅ **Clean Architecture** - External code configures behavior

## Requirements

- iOS 17.0+ / macOS 15.0+
- Swift 6.2+
- Xcode 16.0+

## Dependencies

- [Letopis](https://github.com/andrey-torlopov/Letopis) - Structured logging framework

## License

MIT License - see [LICENSE](./LICENSE) file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
