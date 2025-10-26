import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OSLog

/// Interceptor that logs network requests and responses using OSLog.
/// Useful for debugging and monitoring network activity.
public actor LoggingInterceptor: RequestInterceptor {
    private let logger: Logger
    private let logLevel: LogLevel

    public enum LogLevel {
        case minimal  // Only URL and method
        case detailed // + headers and status codes
        case verbose  // + request/response bodies
    }

    /// Creates a logging interceptor
    /// - Parameters:
    ///   - logger: OSLog Logger instance
    ///   - logLevel: Level of detail to log
    public init(logger: Logger = Logger(subsystem: "Nevod", category: "Network"), logLevel: LogLevel = .detailed) {
        self.logger = logger
        self.logLevel = logLevel
    }

    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        logRequest(request)
        return request
    }

    public func retry(
        _ request: URLRequest,
        response: HTTPURLResponse?,
        error: NetworkError
    ) async throws -> Bool {
        logError(request: request, response: response, error: error)
        return false // Logging interceptor doesn't retry
    }

    // MARK: - Private

    private func logRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "unknown URL"

        switch logLevel {
        case .minimal:
            logger.info("→ \(method) \(url)")

        case .detailed:
            logger.info("→ \(method) \(url)")
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                logger.debug("Headers: \(String(describing: headers))")
            }

        case .verbose:
            logger.info("→ \(method) \(url)")
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                logger.debug("Headers: \(String(describing: headers))")
            }
            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                logger.debug("Body:\n\(prettyString)")
            }
        }
    }

    private func logError(request: URLRequest, response: HTTPURLResponse?, error: NetworkError) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "unknown URL"

        if let response = response {
            logger.error("← \(method) \(url) - HTTP \(response.statusCode) - \(String(describing: error))")
        } else {
            logger.error("← \(method) \(url) - \(String(describing: error))")
        }
    }
}
