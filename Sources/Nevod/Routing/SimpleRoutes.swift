import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Simple GET Route

/// A simple GET route with optional query parameters.
/// Use this for basic GET requests to reduce boilerplate.
///
/// Example:
/// ```swift
/// let route = SimpleGetRoute<User, MyDomain>(
///     endpoint: "/users/me",
///     domain: .api
/// )
///
/// // With query parameters
/// let route = SimpleGetRoute<[User], MyDomain>(
///     endpoint: "/users",
///     domain: .api,
///     queryParameters: ["page": "1", "limit": "10"]
/// )
/// ```
public struct SimpleGetRoute<R: Decodable, D: ServiceDomain>: Route {
    public typealias Response = R
    public typealias Domain = D

    public let domain: D
    public let endpoint: String
    public let queryParameters: [String: String]?

    public var method: HTTPMethod { .get }
    public var parameters: [String: String]? { queryParameters }
    public var parameterEncoding: ParameterEncoding { .query }

    /// Creates a simple GET route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users/me")
    ///   - domain: The service domain
    ///   - queryParameters: Optional query parameters (e.g., ["page": "1", "limit": "10"])
    public init(endpoint: String, domain: D, queryParameters: [String: String]? = nil) {
        self.endpoint = endpoint
        self.domain = domain
        self.queryParameters = queryParameters
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
///     bodyParameters: ["name": "John", "email": "john@test.com"]
/// )
///
/// // With query parameters
/// let route = SimplePostRoute<User, MyDomain>(
///     endpoint: "/users",
///     domain: .api,
///     queryParameters: ["notify": "true"],
///     bodyParameters: ["name": "John", "email": "john@test.com"]
/// )
/// ```
public struct SimplePostRoute<R: Decodable, D: ServiceDomain>: Route {
    public typealias Response = R
    public typealias Domain = D

    public let domain: D
    public let endpoint: String
    public let queryParameters: [String: String]?
    public let bodyParameters: [String: String]?

    public var method: HTTPMethod { .post }
    public var parameters: [String: String]? { bodyParameters }
    public var parameterEncoding: ParameterEncoding { .json }

    // Override urlQueryItems to include query parameters
    public var urlQueryItems: [URLQueryItem]? {
        guard let queryParams = queryParameters, !queryParams.isEmpty else { return nil }
        return queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
    }

    /// Creates a simple POST route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users")
    ///   - domain: The service domain
    ///   - queryParameters: Optional query parameters for the URL
    ///   - bodyParameters: Optional dictionary of parameters to send in the request body
    public init(
        endpoint: String,
        domain: D,
        queryParameters: [String: String]? = nil,
        bodyParameters: [String: String]? = nil
    ) {
        self.endpoint = endpoint
        self.domain = domain
        self.queryParameters = queryParameters
        self.bodyParameters = bodyParameters
    }

    /// Creates a simple POST route (backward compatibility)
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users")
    ///   - domain: The service domain
    ///   - parameters: Optional dictionary of parameters to send in the request body
    @available(*, deprecated, message: "Use init with bodyParameters instead")
    public init(endpoint: String, domain: D, parameters: [String: String]?) {
        self.endpoint = endpoint
        self.domain = domain
        self.queryParameters = nil
        self.bodyParameters = parameters
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
///     bodyParameters: ["name": "John Updated"]
/// )
///
/// // With query parameters
/// let route = SimplePutRoute<User, MyDomain>(
///     endpoint: "/users/123",
///     domain: .api,
///     queryParameters: ["notify": "true"],
///     bodyParameters: ["name": "John Updated"]
/// )
/// ```
public struct SimplePutRoute<R: Decodable, D: ServiceDomain>: Route {
    public typealias Response = R
    public typealias Domain = D

    public let domain: D
    public let endpoint: String
    public let queryParameters: [String: String]?
    public let bodyParameters: [String: String]?

    public var method: HTTPMethod { .put }
    public var parameters: [String: String]? { bodyParameters }
    public var parameterEncoding: ParameterEncoding { .json }

    // Override urlQueryItems to include query parameters
    public var urlQueryItems: [URLQueryItem]? {
        guard let queryParams = queryParameters, !queryParams.isEmpty else { return nil }
        return queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
    }

    /// Creates a simple PUT route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users/123")
    ///   - domain: The service domain
    ///   - queryParameters: Optional query parameters for the URL
    ///   - bodyParameters: Optional dictionary of parameters to send in the request body
    public init(
        endpoint: String,
        domain: D,
        queryParameters: [String: String]? = nil,
        bodyParameters: [String: String]? = nil
    ) {
        self.endpoint = endpoint
        self.domain = domain
        self.queryParameters = queryParameters
        self.bodyParameters = bodyParameters
    }

    /// Creates a simple PUT route (backward compatibility)
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users/123")
    ///   - domain: The service domain
    ///   - parameters: Optional dictionary of parameters to send in the request body
    @available(*, deprecated, message: "Use init with bodyParameters instead")
    public init(endpoint: String, domain: D, parameters: [String: String]?) {
        self.endpoint = endpoint
        self.domain = domain
        self.queryParameters = nil
        self.bodyParameters = parameters
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
