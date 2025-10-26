# Installation Guide

[Русская версия](./Installation-ru.md)

This guide covers installing Nevod and its dependencies in your project.

## Requirements

- **iOS**: 17.0 or later
- **macOS**: 15.0 or later
- **Swift**: 6.2 or later
- **Xcode**: 16.0 or later

## Installation Methods

### Swift Package Manager (Recommended)

#### Option 1: Xcode UI

1. Open your project in Xcode
2. Go to `File` → `Add Package Dependencies...`
3. Enter the repository URL:
   ```
   https://github.com/yourusername/Nevod.git
   ```
4. Select version rule (recommended: "Up to Next Major Version")
5. Click `Add Package`

#### Option 2: Package.swift

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
        .package(url: "https://github.com/yourusername/Nevod.git", from: "0.0.1")
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

Nevod requires the following dependencies, which will be automatically installed via SPM:

### Letopis (structured logging)
**Purpose**: Structured logging framework for internal events

**Repository**: [https://github.com/andrey-torlopov/Letopis](https://github.com/andrey-torlopov/Letopis)

**Version**: 0.0.9 or later

**Features**:
- Event-based logging system
- Multiple interceptor support
- Structured payload metadata
- Console, file, and custom output

You only need to `import Letopis` when you pass a custom logger into `NetworkProvider`.

### Storage (optional token persistence)
**Purpose**: Key-value storage abstraction used by `TokenStorage`

**Repository**: Add the companion Storage package from your workspace or provide your own implementation.

**Features**:
- `KeyValueStorage` protocol
- `UserDefaultsStorage` implementation
- Thread-safe storage operations

**Usage in Nevod**:
```swift
import Storage

let storage = UserDefaultsStorage()
let tokenStorage = TokenStorage(storage: storage)
```

**Note**: Include `Storage` only if you plan to use the bundled `TokenStorage`. You can substitute any actor that matches the same API.


## Dependency Graph

```
┌─────────────────┐
│     Nevod       │
└────────┬────────┘
         │
         v
┌─────────────────┐
│    Letopis      │
└─────────────────┘
```

Storage is an optional helper that you include only when you use the bundled `TokenStorage`.


## Importing Modules

In your Swift files:

```swift
import Nevod           // Core networking
// Optional helpers
import Storage         // When using TokenStorage
import Letopis         // When providing a custom logger
```

## Minimal Setup

Here's the minimal code to get started:

```swift
import Nevod
import Storage

// 1. Define your service domain
enum MyDomain: ServiceDomain {
    case api

    var identifier: String {
        switch self {
        case .api: return "api"
        }
    }
}

// 2. Create network configuration
let config = NetworkConfig(
    environments: [
        MyDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!,
            apiKey: "secret-key",
            headers: ["X-Client-Version": "1.0"]
        )
    ],
    timeout: 30,
    retries: 3
)

// 3. Create network provider
let provider = NetworkProvider(config: config)

// 4. Define a route
let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

// 5. Make request
let user = try await provider.perform(route)
```

`SimpleEnvironment` is bundled with Nevod and conforms to `NetworkEnvironmentProviding`. Replace it with your own implementation if you need runtime environment switching.


## Optional: Local Package Setup

If you're developing Nevod locally or using it as a local package:

### File Structure
```
YourProject/
├── LocalPackages/
│   ├── Nevod/
│   └── Storage/      # Optional helper
└── YourApp/
    └── Package.swift
```

### Package.swift for Local Development

```swift
let package = Package(
    name: "YourApp",
    dependencies: [
        .package(path: "../LocalPackages/Nevod"),
        // .package(path: "../LocalPackages/Storage") // Optional helper
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "Nevod", package: "Nevod"),
                // .product(name: "Storage", package: "Storage") // Optional
            ]
        )
    ]
)
```

## Troubleshooting

### Issue: "No such module 'Nevod'"

**Solution**:
1. Clean build folder: `Product` → `Clean Build Folder` (Cmd+Shift+K)
2. Reset package cache: `File` → `Packages` → `Reset Package Caches`
3. Update packages: `File` → `Packages` → `Update to Latest Package Versions`

### Issue: Dependency resolution failed

**Solution**:
1. Check Swift version compatibility (requires 6.2+)
2. Check platform requirements (iOS 17+, macOS 15+)
3. Verify Package.swift syntax
4. Clear derived data: `~/Library/Developer/Xcode/DerivedData`

### Issue: Build errors after updating

**Solution**:
```bash
# Clean and rebuild
swift package clean
swift package update
swift build
```

## Next Steps

- [Quick Start Guide](./QuickStart.md) - Learn basic usage
- [Examples](../Examples/) - See real-world examples

## Version Compatibility

| Nevod Version | iOS    | macOS  | Swift | Xcode  |
|---------------|--------|--------|-------|--------|
| 1.0.0+        | 17.0+  | 15.0+  | 6.2+  | 16.0+  |

## Getting Help

If you encounter issues:
1. Check this installation guide
2. Review [Quick Start](./QuickStart.md)
3. Search [GitHub Issues](https://github.com/yourusername/Nevod/issues)
4. Open a new issue with:
   - Your environment (iOS/macOS version, Xcode version)
   - Package.swift configuration
   - Error messages
   - Steps to reproduce
