import Foundation

/// Generic actor for storing authentication tokens
///
/// TokenStorage is responsible only for:
/// - Loading tokens from storage
/// - Saving tokens to storage
/// - Caching tokens in memory
///
/// It does NOT handle token refresh logic - that's delegated to interceptors
public actor TokenStorage<Token: TokenModel> {
    private let storage: any KeyValueStorage
    private let storageKey: StorageKey
    private var cached: Token?

    /// Creates a token storage
    /// - Parameters:
    ///   - storage: The underlying key-value storage
    ///   - key: The storage key to use (defaults to .token)
    public init(storage: any KeyValueStorage, key: StorageKey = .token) {
        self.storage = storage
        self.storageKey = key
        
        // Try to load cached token on init
        if let data = storage.data(for: key),
           let token = try? Token.decode(from: data) {
            self.cached = token
        }
    }

    /// Returns the current token
    public func load() -> Token? {
        cached
    }

    /// Saves a new token
    /// - Parameter token: The token to save (nil to remove)
    public func save(_ token: Token?) {
        self.cached = token
        
        if let token, let data = try? token.encode() {
            storage.set(data, for: storageKey)
        } else {
            storage.remove(for: storageKey)
        }
    }
}
