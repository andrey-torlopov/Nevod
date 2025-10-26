import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Chains multiple interceptors together, applying them in sequence.
/// Adapt phase: interceptors are applied in order (first to last)
/// Retry phase: interceptors are checked in reverse order (last to first)
public actor InterceptorChain: RequestInterceptor {
    private let interceptors: [any RequestInterceptor]

    /// Creates a chain of interceptors
    /// - Parameter interceptors: Array of interceptors to chain. They will be applied in order during adapt phase.
    public init(_ interceptors: [any RequestInterceptor]) {
        self.interceptors = interceptors
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var req = request

        // Apply interceptors in order
        for interceptor in interceptors {
            req = try await interceptor.adapt(req)
        }

        return req
    }

    public func retry(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        error: NetworkError
    ) async throws -> Bool {
        // Try retry in reverse order (last interceptor gets first chance)
        // This allows auth interceptors (typically last) to handle 401 first
        for interceptor in interceptors.reversed() {
            if try await interceptor.retry(request, response: response, error: error) {
                return true
            }
        }

        return false
    }
}
