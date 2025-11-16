import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// API Key authentication token
///
/// Simple authentication using an API key in a custom header.
/// Common in public APIs like OpenWeatherMap, NewsAPI, etc.
///
/// Example usage:
/// ```swift
/// let token = APIKeyToken(
///     apiKey: "your-api-key-here",
///     headerName: "X-API-Key"
/// )
///
/// let storage = TokenStorage<APIKeyToken>(...)
/// await storage.save(token)
/// ```
public struct APIKeyToken: Sendable, TokenModel, Codable {
    public let apiKey: String
    public let headerName: String

    public init(apiKey: String, headerName: String = "X-API-Key") {
        self.apiKey = apiKey
        self.headerName = headerName
    }

    // MARK: - TokenModel

    /// Applies API key to the request header
    public func authorize(_ request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: headerName)
    }

    public func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}
