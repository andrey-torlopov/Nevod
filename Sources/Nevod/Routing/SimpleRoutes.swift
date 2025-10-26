import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Simple GET Route

/// A simple GET route without parameters.
/// Use this for basic GET requests to reduce boilerplate.
///
/// Example:
/// ```swift
/// let route = SimpleGetRoute<User, MyDomain>(
///     endpoint: "/users/me",
///     domain: .api
/// )
/// ```
public struct SimpleGetRoute<R: Decodable, D: ServiceDomain>: Route {
    public typealias Response = R
    public typealias Domain = D

    public let domain: D
    public let endpoint: String
    public var method: HTTPMethod { .get }
    public var parameters: [String: String]? { nil }

    /// Creates a simple GET route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users/me")
    ///   - domain: The service domain
    public init(endpoint: String, domain: D) {
        self.endpoint = endpoint
        self.domain = domain
    }
}

// MARK: - Simple POST Route with Dictionary Parameters

/// A simple POST route with string dictionary parameters.
/// Use this for basic POST requests with simple key-value parameters.
///
/// Example:
/// ```swift
/// let route = SimplePostRoute<User, MyDomain>(
///     endpoint: "/users",
///     domain: .api,
///     parameters: ["name": "John", "email": "john@test.com"]
/// )
/// ```
public struct SimplePostRoute<R: Decodable, D: ServiceDomain>: Route {
    public typealias Response = R
    public typealias Domain = D

    public let domain: D
    public let endpoint: String
    public var method: HTTPMethod { .post }
    public let parameters: [String: String]?

    /// Creates a simple POST route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users")
    ///   - domain: The service domain
    ///   - parameters: Optional dictionary of parameters to send in the request body
    public init(endpoint: String, domain: D, parameters: [String: String]? = nil) {
        self.endpoint = endpoint
        self.domain = domain
        self.parameters = parameters
    }
}

// MARK: - Simple PUT Route with Dictionary Parameters

/// A simple PUT route with string dictionary parameters.
/// Use this for basic PUT requests with simple key-value parameters.
///
/// Example:
/// ```swift
/// let route = SimplePutRoute<User, MyDomain>(
///     endpoint: "/users/123",
///     domain: .api,
///     parameters: ["name": "John Updated"]
/// )
/// ```
public struct SimplePutRoute<R: Decodable, D: ServiceDomain>: Route {
    public typealias Response = R
    public typealias Domain = D

    public let domain: D
    public let endpoint: String
    public var method: HTTPMethod { .put }
    public let parameters: [String: String]?

    /// Creates a simple PUT route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users/123")
    ///   - domain: The service domain
    ///   - parameters: Optional dictionary of parameters to send in the request body
    public init(endpoint: String, domain: D, parameters: [String: String]? = nil) {
        self.endpoint = endpoint
        self.domain = domain
        self.parameters = parameters
    }
}

// MARK: - Simple DELETE Route

/// A simple DELETE route without parameters.
/// Use this for basic DELETE requests.
///
/// Example:
/// ```swift
/// let route = SimpleDeleteRoute<DeleteResponse, MyDomain>(
///     endpoint: "/users/123",
///     domain: .api
/// )
/// ```
public struct SimpleDeleteRoute<R: Decodable, D: ServiceDomain>: Route {
    public typealias Response = R
    public typealias Domain = D

    public let domain: D
    public let endpoint: String
    public var method: HTTPMethod { .delete }
    public var parameters: [String: String]? { nil }

    /// Creates a simple DELETE route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users/123")
    ///   - domain: The service domain
    public init(endpoint: String, domain: D) {
        self.endpoint = endpoint
        self.domain = domain
    }
}
