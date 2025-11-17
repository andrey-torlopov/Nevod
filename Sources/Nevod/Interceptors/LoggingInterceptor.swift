import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Interceptor that logs network requests and responses using NevodLogger.
/// Useful for debugging and monitoring network activity.
public actor LoggingInterceptor: RequestInterceptor {
    private let logger: NevodLogger
    private let hideHeaderFields: [String]

    /// Creates a logging interceptor using NevodLogger
    /// - Parameters:
    ///   - logger: Logger instance (defaults to OSLog-based logger)
    ///   - hideHeaderFields: Header field names to hide in logs for security (e.g., passwords, tokens)
    public init(
        logger: NevodLogger = NevodLogger(config: .oslog(subsystem: "com.nevod.network", category: "LoggingInterceptor")),
        hideHeaderFields: [String] = ["password", "bearer", "email", "authorization"]
    ) {
        self.logger = logger
        self.hideHeaderFields = hideHeaderFields.map { $0.lowercased() }
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        await logRequest(request)
        return request
    }

    public func retry(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        error: NetworkError
    ) async throws -> Bool {
        await logError(request: request, response: response, error: error)
        return false // Logging interceptor doesn't retry
    }

    // MARK: - Private

    private func logRequest(_ request: URLRequest) async {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "unknown URL"

        await logger.info("→ \(method) \(url)", payload: [
            "method": method,
            "url": url
        ])

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            let filteredHeaders = filterSensitiveHeaders(headers)
            await logger.debug("Headers: \(String(describing: filteredHeaders))")
        }

        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            await logger.debug("Body:\n\(prettyString)")
        }
    }

    private func logError(request: URLRequest, response: HTTPURLResponse?, error: NetworkError) async {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "unknown URL"

        if let response = response {
            await logger.error("← \(method) \(url) - HTTP \(response.statusCode)", payload: [
                "method": method,
                "url": url,
                "status_code": String(response.statusCode),
                "error": String(describing: error)
            ])
        } else {
            await logger.error("← \(method) \(url) - \(String(describing: error))", payload: [
                "method": method,
                "url": url,
                "error": String(describing: error)
            ])
        }
    }

    private func filterSensitiveHeaders(_ headers: [String: String]) -> [String: String] {
        var filtered = headers
        for key in headers.keys {
            if hideHeaderFields.contains(key.lowercased()) {
                filtered[key] = "***HIDDEN***"
            }
        }
        return filtered
    }
}
