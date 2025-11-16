import Foundation

/// Protocol for providing network environment configuration per domain.
/// Each domain can have its own base URL.
///
/// For authentication, use `AuthenticationInterceptor` with token models.
/// For custom headers, use `HeadersInterceptor`.
///
/// Example usage:
/// ```swift
/// struct ProductionEnvironment: NetworkEnvironmentProviding {
///     let baseURL: URL
///
///     init(domain: MyDomain) {
///         switch domain {
///         case .api:
///             self.baseURL = URL(string: "https://api.example.com")!
///         case .cdn:
///             self.baseURL = URL(string: "https://cdn.example.com")!
///         }
///     }
/// }
/// ```
public protocol NetworkEnvironmentProviding: Sendable {
    /// Base URL for the service
    var baseURL: URL { get }
}
