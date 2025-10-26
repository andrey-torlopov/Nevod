import Foundation

/// Protocol for providing network environment configuration per domain.
/// Each domain can have its own base URL, API key, and custom headers.
///
/// Example usage:
/// ```swift
/// struct ProductionEnvironment: NetworkEnvironmentProviding {
///     let baseURL: URL
///     let apiKey: String?
///     let headers: [String: String]
///
///     init(domain: MyDomain) {
///         switch domain {
///         case .api:
///             self.baseURL = URL(string: "https://api.example.com")!
///             self.apiKey = "prod-key"
///             self.headers = ["X-Client-Version": "1.0"]
///         case .cdn:
///             self.baseURL = URL(string: "https://cdn.example.com")!
///             self.apiKey = nil
///             self.headers = [:]
///         }
///     }
/// }
/// ```
public protocol NetworkEnvironmentProviding: Sendable {
    /// Base URL for the service
    var baseURL: URL { get }

    /// Optional API key for authentication
    var apiKey: String? { get }

    /// Additional headers to be included in all requests
    var headers: [String: String] { get }
}
