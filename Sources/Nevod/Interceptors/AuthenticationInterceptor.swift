import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Generic interceptor that handles authentication with any token type
///
/// Responsibilities:
/// - Applies tokens to requests via `authorize()`
/// - Detects 401 errors and triggers token refresh
/// - Delegates refresh logic to external strategy
/// - Saves refreshed tokens to storage
///
/// The interceptor does NOT know HOW to refresh tokens - that logic is injected
public actor AuthenticationInterceptor<Token: TokenModel>: RequestInterceptor {
    private let tokenStorage: TokenStorage<Token>

    /// Strategy for refreshing tokens when they expire
    /// Receives the current (possibly expired) token and returns a new one
    private let refreshStrategy: @Sendable (Token?) async throws -> Token

    /// Filter to determine which requests should be authenticated
    /// Useful when you have multiple domains with different auth schemes
    private let shouldAuthenticate: @Sendable (URLRequest) -> Bool

    private var refreshTask: Task<Token, Error>?

    /// Creates an authentication interceptor
    /// - Parameters:
    ///   - tokenStorage: Storage for the authentication token
    ///   - refreshStrategy: Closure that knows how to refresh the token
    ///   - shouldAuthenticate: Filter for requests that need authentication (default: all)
    public init(
        tokenStorage: TokenStorage<Token>,
        refreshStrategy: @escaping @Sendable (Token?) async throws -> Token,
        shouldAuthenticate: @escaping @Sendable (URLRequest) -> Bool = { _ in true }
    ) {
        self.tokenStorage = tokenStorage
        self.refreshStrategy = refreshStrategy
        self.shouldAuthenticate = shouldAuthenticate
    }

    /// Adds authentication to the request if applicable
    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        guard shouldAuthenticate(request) else {
            return request
        }

        var req = request

        // Apply token if available
        if let token = await tokenStorage.load() {
            token.authorize(&req)
        }

        return req
    }

    /// Handles retry logic on 401 errors by refreshing the token
    public func retry(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        error: NetworkError
    ) async throws -> Bool {
        // Only handle 401 errors for requests we authenticate
        guard shouldAuthenticate(request),
              case .unauthorized = error else {
            return false
        }

        // Refresh token and retry
        do {
            _ = try await refreshTokenIfNeeded()
            return true
        } catch {
            throw NetworkError.unauthorized(data: nil, response: response)
        }
    }

    // MARK: - Private

    private func refreshTokenIfNeeded() async throws -> Token {
        // Deduplicate concurrent refresh requests
        if let task = refreshTask {
            return try await task.value
        }

        let task = Task { () async throws -> Token in
            // Get current token (may be nil or expired)
            let currentToken = await tokenStorage.load()

            // Call refresh strategy (it knows what to do)
            let newToken = try await refreshStrategy(currentToken)

            // Save new token
            await tokenStorage.save(newToken)

            return newToken
        }

        self.refreshTask = task

        do {
            let token = try await task.value
            self.refreshTask = nil
            return token
        } catch {
            self.refreshTask = nil
            throw error
        }
    }
}
