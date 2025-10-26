import Foundation

/// Simple implementation of NetworkEnvironmentProviding for basic use cases.
/// Use this when you have a single base URL with optional API key and headers.
///
/// Example:
/// ```swift
/// let environment = SimpleEnvironment(
///     baseURL: URL(string: "https://api.example.com")!,
///     apiKey: "my-api-key",
///     headers: ["X-Client-Version": "1.0"]
/// )
/// ```
public struct SimpleEnvironment: NetworkEnvironmentProviding {
    public let baseURL: URL
    public let apiKey: String?
    public let headers: [String: String]

    public init(
        baseURL: URL,
        apiKey: String? = nil,
        headers: [String: String] = [:]
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.headers = headers
    }
}
