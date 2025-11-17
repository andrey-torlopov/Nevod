import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Letopis

/// Main network provider that executes requests with optional interceptor support.
/// - Simple usage: Create with just config for basic requests
/// - Advanced usage: Add interceptor for auth, logging, custom headers, etc.
public actor NetworkProvider {
    private let session: URLSessionProtocol
    private let config: NetworkConfig
    private let interceptor: (any RequestInterceptor)?
    private let logger: Letopis?
    private let rateLimiter: (any RateLimiting)?

    /// Creates a network provider
    /// - Parameters:
    ///   - config: Network configuration with base URLs and settings
    ///   - session: URLSession instance (defaults to shared)
    ///   - interceptor: Optional interceptor for request adaptation and retry logic
    ///   - logger: Optional Letopis logger for internal events (defaults to nil)
    public init(
        config: NetworkConfig,
        session: URLSessionProtocol = URLSessionType.shared,
        interceptor: (any RequestInterceptor)? = nil,
        rateLimiter: (any RateLimiting)? = nil,
        logger: Letopis? = Letopis(interceptors: [ConsoleInterceptor()])
    ) {
        self.config = config
        self.session = session
        self.interceptor = interceptor
        self.logger = logger
        if let rateLimiter = rateLimiter {
            self.rateLimiter = rateLimiter
        } else if let rateLimit = config.rateLimit {
            self.rateLimiter = RateLimiter(configuration: rateLimit)
        } else {
            self.rateLimiter = nil
        }
    }

    /// Executes a network request
    /// - Parameters:
    ///   - route: Route describing the endpoint and parameters
    ///   - delegate: Optional URLSessionTaskDelegate for progress tracking
    /// - Returns: Result containing either the decoded response or an error
    public func request<R: Route>(
        _ route: R,
        delegate: URLSessionTaskDelegate? = nil
    ) async -> Result<R.Response, NetworkError> {
        let attempts = max(1, config.retries)

        logger?.debug("Starting request to \(route.endpoint)", payload: [
            "endpoint": route.endpoint,
            "method": route.method.stringValue,
            "max_attempts": String(attempts)
        ])

        for attempt in 0..<attempts {
            if let rateLimiter {
                await rateLimiter.acquirePermit()
            }

            logger?.debug("Request attempt \(attempt + 1) of \(attempts)", payload: [
                "attempt": String(attempt + 1),
                "endpoint": route.endpoint
            ])

            // Build base request from route
            let requestResult = route.makeRequest(with: config)

            switch requestResult {
            case .failure(let error):
                logger?.error("Failed to build request", payload: [
                    "endpoint": route.endpoint,
                    "error": String(describing: error)
                ])
                return .failure(error)

            case .success(let baseRequest):
                // Apply interceptor adaptation
                let adaptedRequest: URLRequest
                do {
                    adaptedRequest = try await applyInterceptor(to: baseRequest)
                } catch let error as NetworkError {
                    logger?.error("Interceptor adaptation failed", payload: [
                        "endpoint": route.endpoint,
                        "error": String(describing: error)
                    ])
                    return .failure(error)
                } catch {
                    logger?.error("Interceptor adaptation failed with unknown error", payload: [
                        "endpoint": route.endpoint,
                        "error": error.localizedDescription
                    ])
                    return .failure(.unknown(error))
                }

                // Execute request
                do {
                    let (data, response) = try await session.requestData(
                        for: adaptedRequest,
                        delegate: delegate
                    )

                    let httpResponse = response as? HTTPURLResponse

                    if let httpResponse = httpResponse {
                        logger?.debug("Received response", payload: [
                            "endpoint": route.endpoint,
                            "status_code": String(httpResponse.statusCode),
                            "attempt": String(attempt + 1)
                        ])
                    }

                    // Check for HTTP errors
                    if let httpResponse = httpResponse {
                        if let networkError = mapHTTPError(statusCode: httpResponse.statusCode) {
                            // Ask interceptor if we should retry
                            if try await shouldRetry(
                                request: adaptedRequest,
                                response: httpResponse,
                                error: networkError
                            ) {
                                logger?.info("Retrying request after HTTP error", payload: [
                                    "endpoint": route.endpoint,
                                    "status_code": String(httpResponse.statusCode),
                                    "error": String(describing: networkError),
                                    "attempt": String(attempt + 1)
                                ])
                                continue // Retry
                            }

                            logger?.error("Request failed with HTTP error", payload: [
                                "endpoint": route.endpoint,
                                "status_code": String(httpResponse.statusCode),
                                "error": String(describing: networkError)
                            ])
                            return .failure(networkError)
                        }
                    }

                    // Decode response
                    do {
                        let decoded = try route.decode(data, using: JSONDecoder())
                        logger?.debug("Request completed successfully", payload: [
                            "endpoint": route.endpoint,
                            "attempt": String(attempt + 1),
                            "total_attempts": String(attempt + 1)
                        ])
                        return .success(decoded)
                    } catch {
                        logger?.error("Failed to decode response", payload: [
                            "endpoint": route.endpoint,
                            "error": error.localizedDescription
                        ])
                        return .failure(.parsingError)
                    }

                } catch {
                    // Handle URLSession errors
                    let networkError = mapURLError(error)

                    // Retry on timeout or transient errors
                    if shouldRetryOnError(networkError, attempt: attempt, maxAttempts: attempts) {
                        logger?.info("Retrying request after URLSession error", payload: [
                            "endpoint": route.endpoint,
                            "error": String(describing: networkError),
                            "attempt": String(attempt + 1)
                        ])
                        continue
                    }

                    logger?.error("Request failed with URLSession error", payload: [
                        "endpoint": route.endpoint,
                        "error": String(describing: networkError),
                        "attempt": String(attempt + 1)
                    ])
                    return .failure(networkError)
                }
            }
        }

        logger?.error("Request failed after all retry attempts", payload: [
            "endpoint": route.endpoint,
            "total_attempts": String(attempts)
        ])
        return .failure(.unknown(NSError(domain: "NetworkProvider", code: -1)))
    }

    /// Executes a network request and throws on error (convenience method)
    /// - Parameters:
    ///   - route: Route describing the endpoint and parameters
    ///   - delegate: Optional URLSessionTaskDelegate for progress tracking
    /// - Returns: The decoded response
    /// - Throws: NetworkError if the request fails
    ///
    /// This is a convenience method that wraps `request(_:delegate:)` and converts
    /// the Result into async throws style for cleaner error handling.
    ///
    /// Example:
    /// ```swift
    /// do {
    ///     let user = try await provider.perform(GetUserRoute())
    ///     print("User: \(user)")
    /// } catch {
    ///     print("Error: \(error)")
    /// }
    /// ```
    public func perform<R: Route>(
        _ route: R,
        delegate: URLSessionTaskDelegate? = nil
    ) async throws -> R.Response {
        let result = await request(route, delegate: delegate)
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Private

    private func applyInterceptor(to request: URLRequest) async throws -> URLRequest {
        guard let interceptor = interceptor else {
            return request
        }
        return try await interceptor.adapt(request)
    }

    private func shouldRetry(
        request: URLRequest,
        response: HTTPURLResponse,
        error: NetworkError
    ) async throws -> Bool {
        guard let interceptor = interceptor else {
            return false
        }
        return try await interceptor.retry(request, response: response, error: error)
    }

    private func mapHTTPError(statusCode: Int) -> NetworkError? {
        switch statusCode {
        case 200..<300:
            return nil
        case 401:
            return .unauthorized
        case 400..<500:
            return .clientError(statusCode)
        case 500..<600:
            return .serverError(statusCode)
        default:
            return .unknown(NSError(domain: "HTTP", code: statusCode))
        }
    }

    private func mapURLError(_ error: Error) -> NetworkError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout
            case .notConnectedToInternet, .networkConnectionLost:
                return .noConnection
            default:
                return .unknown(urlError)
            }
        }
        return .unknown(error)
    }

    private func shouldRetryOnError(
        _ error: NetworkError,
        attempt: Int,
        maxAttempts: Int
    ) -> Bool {
        guard attempt < maxAttempts - 1 else {
            return false
        }

        switch error {
        case .timeout, .noConnection:
            return true
        default:
            return false
        }
    }
}
