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

    private let maxRetryAttempts: Int
    private let retryBackoff: RetryPolicy?
    private var refreshTask: Task<Token, Error>?
    private var consecutive401s = 0

    /// Creates an authentication interceptor
    /// - Parameters:
    ///   - tokenStorage: Storage for the authentication token
    ///   - refreshStrategy: Closure that knows how to refresh the token
    ///   - shouldAuthenticate: Filter for requests that need authentication (default: all)
    public init(
        tokenStorage: TokenStorage<Token>,
        refreshStrategy: @escaping @Sendable (Token?) async throws -> Token,
        shouldAuthenticate: @escaping @Sendable (URLRequest) -> Bool = { _ in true },
        maxRetryAttempts: Int = 2,
        retryBackoff: RetryPolicy? = nil
    ) {
        self.tokenStorage = tokenStorage
        self.refreshStrategy = refreshStrategy
        self.shouldAuthenticate = shouldAuthenticate
        self.maxRetryAttempts = max(1, maxRetryAttempts)
        self.retryBackoff = retryBackoff
    }

    /// Adds authentication to the request if applicable
    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        guard shouldAuthenticate(request) else {
            return request
        }

        var req = request

        // Apply token if available
        do {
            if let token = try await tokenStorage.load() {
                token.authorize(&req)
            }
        } catch {
            throw NetworkError.authenticationFailed
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
        guard shouldAuthenticate(request) else {
            consecutive401s = 0
            return false
        }

        guard case .unauthorized = error else {
            consecutive401s = 0
            return false
        }

        guard consecutive401s < maxRetryAttempts else {
            return false
        }

        let attemptIndex = consecutive401s
        consecutive401s += 1

        if let retryBackoff {
            do {
                try await retryBackoff.performDelay(for: attemptIndex)
            } catch {
                if error is CancellationError {
                    throw NetworkError.cancelled
                }
                throw NetworkError.unknown(error)
            }
        }

        // Refresh token and retry
        do {
            _ = try await refreshTokenIfNeeded()
            consecutive401s = 0
            return true
        } catch let networkError as NetworkError {
            throw networkError
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
            do {
                let currentToken = try await tokenStorage.load()
                let newToken = try await refreshStrategy(currentToken)
                try await tokenStorage.save(newToken)
                return newToken
            } catch let networkError as NetworkError {
                throw networkError
            } catch is TokenStorageError {
                throw NetworkError.authenticationFailed
            }
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
