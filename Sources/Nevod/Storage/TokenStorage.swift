import Foundation

public enum TokenStorageError: Error, CustomStringConvertible {
    case failedToDecode(Error)
    case failedToEncode(Error)

    public var description: String {
        switch self {
        case .failedToDecode(let error):
            return "Failed to decode token: \(error.localizedDescription)"
        case .failedToEncode(let error):
            return "Failed to encode token: \(error.localizedDescription)"
        }
    }
}

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
    private let errorHandler: (@Sendable (TokenStorageError) -> Void)?

    /// Creates a token storage
    /// - Parameters:
    ///   - storage: The underlying key-value storage
    ///   - key: The storage key to use (defaults to .token)
    ///   - onError: Optional callback invoked when encoding/decoding fails
    public init(
        storage: any KeyValueStorage,
        key: StorageKey = .token,
        onError: (@Sendable (TokenStorageError) -> Void)? = nil
    ) {
        self.storage = storage
        self.storageKey = key
        self.errorHandler = onError

        // Try to load cached token on init
        if let data = storage.data(for: key) {
            do {
                self.cached = try Token.decode(from: data)
            } catch {
                let storageError = TokenStorageError.failedToDecode(error)
                errorHandler?(storageError)
            }
        }
    }

    /// Returns the current token
    public func load() throws -> Token? {
        if let cached { return cached }
        guard let data = storage.data(for: storageKey) else { return nil }
        do {
            let token = try Token.decode(from: data)
            cached = token
            return token
        } catch {
            let storageError = TokenStorageError.failedToDecode(error)
            errorHandler?(storageError)
            throw storageError
        }
    }

    /// Saves a new token
    /// - Parameter token: The token to save (nil to remove)
    public func save(_ token: Token?) throws {
        self.cached = token

        guard let token else {
            storage.remove(for: storageKey)
            return
        }

        do {
            let data = try token.encode()
            storage.set(data, for: storageKey)
        } catch {
            let storageError = TokenStorageError.failedToEncode(error)
            errorHandler?(storageError)
            throw storageError
        }
    }
}
