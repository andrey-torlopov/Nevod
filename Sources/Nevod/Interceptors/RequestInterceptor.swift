import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Protocol for intercepting and modifying network requests.
/// Interceptors can adapt requests (add headers, modify URL, etc.) and decide whether to retry on failure.
public protocol RequestInterceptor: Sendable {
    /// Adapts the URLRequest before it's sent to the network.
    /// - Parameter request: The original request
    /// - Returns: The adapted request
    /// - Throws: NetworkError if adaptation fails
    func adapt(_ request: URLRequest) async throws -> URLRequest

    /// Determines whether the request should be retried after a failure.
    /// - Parameters:
    ///   - request: The original request that failed
    ///   - response: The HTTP response (if available)
    ///   - error: The error that occurred
    /// - Returns: true if the request should be retried, false otherwise
    /// - Throws: NetworkError if retry logic fails
    func retry(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        error: NetworkError
    ) async throws -> Bool
}

// Default implementation for simpler interceptors
public extension RequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        request
    }

    func retry(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        error: NetworkError
    ) async throws -> Bool {
        false
    }
}
