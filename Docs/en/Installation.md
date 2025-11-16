# Installation Guide

[Русская версия](../ru/Installation.md)

This guide covers installing Nevod and its dependencies in your project.

## Requirements

- **iOS**: 17.0 or later
- **macOS**: 15.0 or later  
- **Swift**: 6.2 or later
- **Xcode**: 16.0 or later

## Swift Package Manager

### Option 1: Xcode UI

1. Open your project in Xcode
2. Go to `File` → `Add Package Dependencies...`
3. Enter the repository URL:
   ```
   https://github.com/andrey-torlopov/Nevod.git
   ```
4. Select version rule (recommended: "Up to Next Major Version")
5. Click `Add Package`

### Option 2: Package.swift

Add Nevod to your `Package.swift` file:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "git@github.com:andrey-torlopov/Nevod.git", from: "0.0.2")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "Nevod", package: "Nevod")
            ]
        )
    ]
)
```

Then run:
```bash
swift package update
```

## Dependencies

Nevod automatically installs its dependencies via SPM:

### Letopis (Structured Logging)

**Repository**: [https://github.com/andrey-torlopov/Letopis](https://github.com/andrey-torlopov/Letopis)

**Version**: 0.0.10 or later

**Purpose**: Internal event logging for NetworkProvider

You only need to `import Letopis` if you want to pass a custom logger to `NetworkProvider`.

## Minimal Setup

```swift
import Nevod

// 1. Define service domain
enum MyDomain: ServiceDomain {
    case api
    
    var identifier: String { "api" }
}

// 2. Create configuration
let config = NetworkConfig(
    environments: [
        MyDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!
        )
    ],
    timeout: 30,
    retries: 3
)

// 3. Create provider
let provider = NetworkProvider(config: config)

// 4. Make a request
let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

let user = try await provider.perform(route)
```

## Next Steps

- [Quick Start Guide](./QuickStart.md) - Learn the basics
- [Authentication Guide](./Authentication.md) - Setup token-based auth
- [Advanced Usage](./Advanced.md) - Interceptors, multiple services, custom routes

## Troubleshooting

### "No such module 'Nevod'"

1. Clean build: `Product` → `Clean Build Folder` (Cmd+Shift+K)
2. Reset caches: `File` → `Packages` → `Reset Package Caches`
3. Update packages: `File` → `Packages` → `Update to Latest Package Versions`

### Dependency resolution failed

1. Check Swift version (requires 6.2+)
2. Check platform requirements (iOS 17+, macOS 15+)
3. Clear derived data: `~/Library/Developer/Xcode/DerivedData`

### Build errors after update

```bash
swift package clean
swift package update
swift build
```
