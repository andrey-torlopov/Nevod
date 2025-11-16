import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Where to encode parameters — in the URL or in the body
public enum ParameterEncoding {
    case query
    case json
    case formUrlEncoded
    case none

    var contentType: String? {
        switch self {
        case .formUrlEncoded: return "application/x-www-form-urlencoded"
        case .json:  return "application/json"
        case .query, .none: return nil
        }
    }
}

public protocol Route {
    associatedtype Response
    associatedtype Domain: ServiceDomain

    var domain: Domain { get }
    var endpoint: String { get }
    var method: HTTPMethod { get }
    var parameters: [String: String]? { get }
    /// Can be overridden for specific routes if needed
    var parameterEncoding: ParameterEncoding { get }
    /// Additional headers if needed (route-specific headers)
    var headers: [String: String]? { get }

    func decode(_ data: Data, using decoder: JSONDecoder) throws -> Response
}

public extension Route {

    // MARK: - Default values

    var parameterEncoding: ParameterEncoding {
        // Single decision point instead of scattering if method == .get
        method == .get ? .query : .json
    }

    var headers: [String: String]? { nil }

    // MARK: - Computed properties for parameters

    /// URLQueryItems built from parameter dictionary (if query encoding chosen)
    var urlQueryItems: [URLQueryItem]? {
        guard parameterEncoding == .query, let params = parameters, !params.isEmpty else { return nil }
        // URLComponents escapes values correctly
        return params.map { URLQueryItem(name: $0.key, value: $0.value) }
    }

    /// Request body data (for JSON encoding)
    /// Note: This will be overridden by EncodableRoute for custom body encoding
    var bodyData: Data? {
        guard let params = parameters, !params.isEmpty else { return nil }

        switch parameterEncoding {
        case .json:
            // JSONSerialization works well for [String: String]
            return try? JSONSerialization.data(withJSONObject: params, options: [])

        case .formUrlEncoded:
            // Create form-urlencoded string: key1=value1&key2=value2
            let formString = params.map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }.joined(separator: "&")
            return formString.data(using: .utf8)

        case .query, .none:
            return nil
        }
    }

    // MARK: - Building URLRequest

    // MAIN: entire building as Result pipeline
    func makeRequest(with config: NetworkConfig) -> Result<URLRequest, NetworkError> {
        return config.environment(for: domain)                       // Result<NetworkEnvironmentProviding, NetworkError>
            .flatMap { env in                                         // env -> Result<URL, NetworkError>
                buildURL(base: env.baseURL, endpoint: endpoint, extraQuery: urlQueryItems)
                    .map { ($0, env) }                               // Pass environment along
            }
            .flatMap { (url, env) -> Result<URLRequest, NetworkError> in
                var request = URLRequest(url: url)
                request.httpMethod = method.stringValue
                request.timeoutInterval = config.timeout

                // Set body if needed (allow route to use config encoder)
                let body = self.bodyData(using: config.jsonEncoder)
                if let body = body {
                    request.httpBody = body
                    if body.isEmpty { return .failure(.bodyEncodingFailed) }
                }

                // Set Content-Type if needed
                if let ct = parameterEncoding.contentType {
                    request.setValue(ct, forHTTPHeaderField: "Content-Type")
                }

                // Apply route-specific headers
                headers?.forEach { key, value in
                    request.setValue(value, forHTTPHeaderField: key)
                }

                return .success(request)
            }
    }

    /// Get body data using a specific encoder (for routes that need encoding)
    /// Default implementation uses bodyData property for backward compatibility
    func bodyData(using encoder: JSONEncoder) -> Data? {
        bodyData
    }
    // MARK: - Helpers

    /// Properly joins baseURL with endpoint and adds query items (preserving existing ones).
    private func buildURL(base: URL, endpoint: String, extraQuery: [URLQueryItem]?) -> Result<URL, NetworkError> {
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)

        let basePath = (comps?.path ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath: String
        switch sanitizeEndpoint(endpoint) {
        case .success(let sanitized):
            endpointPath = sanitized
        case .failure(let error):
            return .failure(error)
        }

        let joinedPath = [basePath, endpointPath].filter { !$0.isEmpty }.joined(separator: "/")
        comps?.path = "/" + joinedPath

        let existing = comps?.queryItems
        comps?.queryItems = mergeQueryItems(existing, extraQuery)

        guard let url = comps?.url else { return .failure(.invalidURL) }
        return .success(url)
    }

    private func sanitizeEndpoint(_ endpoint: String) -> Result<String, NetworkError> {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("://") || trimmed.hasPrefix("//") {
            return .failure(.invalidURL)
        }

        let normalized = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalized.range(of: #"(^|/)(\.{1,2})(/|$)"#, options: .regularExpression) != nil {
            return .failure(.invalidURL)
        }

        if normalized.contains("\\") {
            return .failure(.invalidURL)
        }

        return .success(normalized)
    }

    /// Merge query parameters preserving order and duplicates.
    private func mergeQueryItems(_ a: [URLQueryItem]?, _ b: [URLQueryItem]?) -> [URLQueryItem]? {
        let left = a ?? []
        let right = b ?? []
        let combined = left + right
        return combined.isEmpty ? nil : combined
    }
}

public extension Route where Response: Decodable {
    func decode(_ data: Data, using decoder: JSONDecoder) throws -> Response {
        try decoder.decode(Response.self, from: data)
    }
}

public extension Route where Response == Data {
    func decode(_ data: Data, using decoder: JSONDecoder) throws -> Data {
        data
    }
}
