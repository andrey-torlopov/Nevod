import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Letopis

/// Interceptor that logs network requests and responses using OSLog.
/// Useful for debugging and monitoring network activity.
public actor LoggingInterceptor: RequestInterceptor {
    private let logger: Letopis
    
    /// Creates a logging interceptor using Letopis
    /// - Parameters:
    public init(logger: Letopis = Letopis(interceptors: [ConsoleInterceptor()]), hideHeaderFields: [String] = ["password", "bearer", "email", "authorization"]) {
        self.logger = logger
        logger.addSensitiveKeys(hideHeaderFields)
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
        logger
            .event(NetworkEventType.api)
            .action(NetworkAction.start)
            .info("→ \(method) \(url)")
        
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
    
    private func logError(request: URLRequest, response: HTTPURLResponse?, error: NetworkError) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "unknown URL"
        
        if let response = response {
            logger
                .event(NetworkEventType.api)
                .action(NetworkAction.failure)
                .error("← \(method) \(url) - HTTP \(response.statusCode) - \(String(describing: error))")
        } else {
            logger
                .event(NetworkEventType.api)
                .action(NetworkAction.failure)
                .error("← \(method) \(url) - \(String(describing: error))")
        }
    }
}
