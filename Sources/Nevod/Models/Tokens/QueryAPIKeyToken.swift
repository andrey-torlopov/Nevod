import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Query parameter API Key authentication token
///
/// Authentication using an API key as a URL query parameter.
/// Used by some public APIs like Google Maps, certain weather services.
///
/// Example usage:
/// ```swift
/// let token = QueryAPIKeyToken(
///     apiKey: "your-api-key-here",
///     paramName: "api_key"
/// )
///
/// // Request to: https://api.example.com/data
/// // Becomes: https://api.example.com/data?api_key=your-api-key-here
/// ```
public struct QueryAPIKeyToken: Sendable, TokenModel, Codable {
    public let apiKey: String
    public let paramName: String

    public init(apiKey: String, paramName: String = "api_key") {
        self.apiKey = apiKey
        self.paramName = paramName
    }

    // MARK: - TokenModel

    /// Adds API key as a query parameter to the request URL
    public func authorize(_ request: inout URLRequest) {
        guard let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: paramName, value: apiKey))
        components.queryItems = queryItems

        request.url = components.url
    }

    public func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}
