import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Interceptor that adds custom HTTP headers to all requests.
/// Useful for User-Agent, API versions, client metadata, etc.
public actor HeadersInterceptor: RequestInterceptor {
    private let headers: [String: String]

    /// Creates a headers interceptor
    /// - Parameter headers: Dictionary of headers to add to every request
    public init(headers: [String: String]) {
        self.headers = headers
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        var req = request

        for (key, value) in headers {
            req.setValue(value, forHTTPHeaderField: key)
        }

        return req
    }
}

// MARK: - Convenience Initializers

public extension HeadersInterceptor {
    /// Creates an interceptor that adds a User-Agent header
    static func userAgent(_ userAgent: String) -> HeadersInterceptor {
        HeadersInterceptor(headers: ["User-Agent": userAgent])
    }

    /// Creates an interceptor that adds an API version header
    static func apiVersion(_ version: String, headerName: String = "X-API-Version") -> HeadersInterceptor {
        HeadersInterceptor(headers: [headerName: version])
    }
}
