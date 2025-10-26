import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Interceptor that handles OAuth-style Bearer token authentication.
/// Automatically adds Authorization header and refreshes tokens on 401 errors.
public actor AuthenticationInterceptor: RequestInterceptor {
    private let tokenStorage: TokenStorage
    private let refreshToken: @Sendable () async throws -> String
    private var refreshTask: Task<String, Error>?

    /// Creates an authentication interceptor
    /// - Parameters:
    ///   - tokenStorage: Storage for the current token
    ///   - refreshToken: Closure that refreshes the token when it expires
    public init(
        tokenStorage: TokenStorage,
        refreshToken: @escaping @Sendable () async throws -> String
    ) {
        self.tokenStorage = tokenStorage
        self.refreshToken = refreshToken
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var req = request

        // Add Bearer token if available
        if let token = await tokenStorage.tokenValue() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return req
    }

    public func retry(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        error: NetworkError
    ) async throws -> Bool {
        // Only retry on 401 Unauthorized
        guard case .unauthorized = error else {
            return false
        }

        // Refresh token and retry
        do {
            _ = try await refreshTokenIfNeeded()
            return true
        } catch {
            throw NetworkError.unauthorized
        }
    }

    // MARK: - Private

    private func refreshTokenIfNeeded() async throws -> String {
        // Deduplicate concurrent refresh requests
        if let task = refreshTask {
            return try await task.value
        }

        let task = Task { () async throws -> String in
            return try await refreshToken()
        }

        self.refreshTask = task

        do {
            let token = try await task.value
            await tokenStorage.setToken(Token(value: token))
            self.refreshTask = nil
            return token
        } catch {
            self.refreshTask = nil
            throw error
        }
    }
}
