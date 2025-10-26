# Nevod

<p align="center">
  <img src="Docs/banner.png" alt="Nevod banner" width="600"/>
</p>

<p align="center">
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-6.1+-orange.svg?logo=swift" />
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
- **OAuth Support** - Built-in automatic token refresh handling
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
    .package(url: "https://github.com/yourusername/Nevod.git", from: "1.0.0")
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
- `AuthenticationInterceptor` - OAuth token management
- `LoggingInterceptor` - HTTP request/response logging
- `HeadersInterceptor` - Add custom headers
- `InterceptorChain` - Combine multiple interceptors

### Network Provider
Actor-based network executor with automatic retries and error handling.

## Usage Patterns

### Basic Request
```swift
let route = SimpleGetRoute<User, MyDomain>(endpoint: "/users/me", domain: .api)
let user = try await provider.perform(route)
```

### With Authentication
```swift
let provider = NetworkProvider(
    config: config,
    interceptor: AuthenticationInterceptor(
        tokenStorage: tokenStorage,
        refreshToken: { try await authService.refreshToken() }
    )
)
```

### Multiple Interceptors
```swift
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        LoggingInterceptor(logger: logger, logLevel: .verbose),
        HeadersInterceptor(headers: ["User-Agent": "MyApp/1.0"]),
        AuthenticationInterceptor(tokenStorage: tokenStorage, refreshToken: refreshBlock)
    ])
)
```

## Requirements

- iOS 17.0+ / macOS 15.0+
- Swift 6.1+
- Xcode 16.0+

## Dependencies

- [Core](../Core) - Environment and core utilities
- [Storage](../Storage) - Key-value storage abstraction
- [Letopis](https://github.com/andrey-torlopov/Letopis) - Structured logging framework

## License

MIT License - see [LICENSE](./LICENSE) file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
