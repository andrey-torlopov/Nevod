import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Interceptor for cookie-based authentication
///
/// Handles session-based authentication by:
/// - Applying cookies to requests
/// - Detecting session expiration (401 errors)
/// - Re-authenticating when sessions expire
/// - Deduplicating concurrent login attempts
///
/// Example usage:
/// ```swift
/// let cookieStorage = TokenStorage<CookieToken>(
///     storage: keychain,
///     key: StorageKey(value: "session_cookies")
/// )
///
/// let cookieInterceptor = CookieAuthenticationInterceptor(
///     cookieStorage: cookieStorage,
///     loginStrategy: {
///         // Perform login and return cookies
///         let cookies = try await performLogin(email: email, password: password)
///         return CookieToken(sessionCookies: cookies)
///     }
/// )
///
/// let provider = NetworkProvider(
///     config: config,
///     interceptor: cookieInterceptor
/// )
/// ```
public actor CookieAuthenticationInterceptor: RequestInterceptor {
    private let cookieStorage: TokenStorage<CookieToken>

    /// Strategy for obtaining new session cookies (login logic)
    /// Called when session expires or no cookies are available
    private let loginStrategy: @Sendable () async throws -> CookieToken

    /// Filter to determine which requests should be authenticated
    /// Useful when you have multiple domains with different auth schemes
    private let shouldAuthenticate: @Sendable (URLRequest) -> Bool

    /// Ongoing login task (for deduplication)
    private var loginTask: Task<CookieToken, Error>?
    private let maxRetryAttempts: Int
    private let retryBackoff: RetryPolicy?
    private var consecutive401s = 0

    /// Creates a cookie authentication interceptor
    /// - Parameters:
    ///   - cookieStorage: Storage for session cookies
    ///   - loginStrategy: Closure that knows how to perform login and obtain cookies
    ///   - shouldAuthenticate: Filter for requests that need authentication (default: all)
    public init(
        cookieStorage: TokenStorage<CookieToken>,
        loginStrategy: @escaping @Sendable () async throws -> CookieToken,
        shouldAuthenticate: @escaping @Sendable (URLRequest) -> Bool = { _ in true },
        maxRetryAttempts: Int = 2,
        retryBackoff: RetryPolicy? = nil
    ) {
        self.cookieStorage = cookieStorage
        self.loginStrategy = loginStrategy
        self.shouldAuthenticate = shouldAuthenticate
        self.maxRetryAttempts = max(1, maxRetryAttempts)
        self.retryBackoff = retryBackoff
    }

    // MARK: - RequestInterceptor

    /// Adds cookies to the request if applicable
    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        guard shouldAuthenticate(request) else {
            return request
        }

        var req = request

        // Apply cookies if available
        do {
            if let token = try await cookieStorage.load() {
                token.authorize(&req)
            }
        } catch {
            throw NetworkError.authenticationFailed
        }

        return req
    }

    /// Handles retry logic on 401 errors by re-authenticating
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

        // Re-authenticate and retry
        do {
            _ = try await loginIfNeeded()
            consecutive401s = 0
            return true
        } catch let networkError as NetworkError {
            throw networkError
        } catch {
            throw NetworkError.unauthorized(data: nil, response: response)
        }
    }

    // MARK: - Private

    /// Performs login if needed, deduplicating concurrent requests
    private func loginIfNeeded() async throws -> CookieToken {
        // Deduplicate concurrent login requests
        if let task = loginTask {
            return try await task.value
        }

        let task = Task { () async throws -> CookieToken in
            do {
                let newToken = try await loginStrategy()
                try await cookieStorage.save(newToken)
                return newToken
            } catch let networkError as NetworkError {
                throw networkError
            } catch is TokenStorageError {
                throw NetworkError.authenticationFailed
            }
        }

        self.loginTask = task

        do {
            let token = try await task.value
            self.loginTask = nil
            return token
        } catch {
            self.loginTask = nil
            throw error
        }
    }
}
