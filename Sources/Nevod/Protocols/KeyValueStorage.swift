import Foundation

/// Protocol for key-value storage
///
/// Note: This protocol uses nonisolated methods to allow both actor and non-actor implementations.
/// Implementations should ensure thread-safety if accessed from multiple contexts.
public protocol KeyValueStorage: Sendable {
    /// Retrieves a string value for the given key
    nonisolated func string(for key: StorageKey) -> String?

    /// Retrieves data for the given key
    nonisolated func data(for key: StorageKey) -> Data?

    /// Sets a string value for the given key
    nonisolated func set(_ value: String?, for key: StorageKey)

    /// Sets data for the given key
    nonisolated func set(_ value: Data?, for key: StorageKey)

    /// Removes value for the given key
    nonisolated func remove(for key: StorageKey)
}

/// Keys for storage
///
/// StorageKey is a type-safe wrapper around string keys.
/// You can create custom keys for your application:
///
/// Example:
/// ```swift
/// extension StorageKey {
///     static let spaceTrackSession = StorageKey(value: "com.myapp.space_track_session")
///     static let apiToken = StorageKey(value: "com.myapp.api_token")
/// }
/// ```
public struct StorageKey: Hashable, Sendable, ExpressibleByStringLiteral {
    public let value: String

    public init(value: String) {
        self.value = value
    }

    // ExpressibleByStringLiteral conformance for convenience
    public init(stringLiteral value: String) {
        self.value = value
    }
}

// MARK: - Default Keys

public extension StorageKey {
    /// Default token storage key
    static let token = StorageKey(value: "com.nevod.token")
}
