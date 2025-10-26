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
public enum StorageKey: String, Sendable {
    case token = "com.nevod.token"
}
