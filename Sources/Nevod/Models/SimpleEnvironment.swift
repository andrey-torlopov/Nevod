import Foundation

/// Simple implementation of NetworkEnvironmentProviding for basic use cases.
/// Use this when you have a single base URL.
///
/// For authentication, use `AuthenticationInterceptor` with token models.
/// For custom headers, use `HeadersInterceptor`.
///
/// Example:
/// ```swift
/// let environment = SimpleEnvironment(
///     baseURL: URL(string: "https://api.example.com")!
/// )
/// ```
public struct SimpleEnvironment: NetworkEnvironmentProviding {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
}
