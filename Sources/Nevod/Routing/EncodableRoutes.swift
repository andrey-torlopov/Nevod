import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Encodable POST Route

/// A POST route that accepts an Encodable body.
/// Use this for POST requests with complex JSON structures.
///
/// Example:
/// ```swift
/// struct CreateUserRequest: Encodable {
///     let name: String
///     let email: String
///     let profile: UserProfile
/// }
///
/// let route = EncodablePostRoute<CreateUserRequest, UserResponse, MyDomain>(
///     endpoint: "/users",
///     domain: .api,
///     body: CreateUserRequest(name: "John", email: "john@test.com", profile: profile)
/// )
/// ```
public struct EncodablePostRoute<Body: Encodable, Response: Decodable, Domain: ServiceDomain>: EncodableRoute {
    public typealias Response = Response
    public typealias Domain = Domain
    public typealias Body = Body

    public let domain: Domain
    public let endpoint: String
    public let body: Body?
    public let bodyEncoder: JSONEncoder
    public var headers: [String: String]?

    public var method: HTTPMethod { .post }

    /// Creates an encodable POST route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users")
    ///   - domain: The service domain
    ///   - body: The encodable body to send
    ///   - encoder: Optional custom JSON encoder (defaults to JSONEncoder())
    ///   - headers: Optional custom headers
    public init(
        endpoint: String,
        domain: Domain,
        body: Body? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        headers: [String: String]? = nil
    ) {
        self.endpoint = endpoint
        self.domain = domain
        self.body = body
        self.bodyEncoder = encoder
        self.headers = headers
    }
}

// MARK: - Encodable PUT Route

/// A PUT route that accepts an Encodable body.
/// Use this for PUT requests with complex JSON structures.
///
/// Example:
/// ```swift
/// struct UpdateUserRequest: Encodable {
///     let name: String
///     let settings: UserSettings
/// }
///
/// let route = EncodablePutRoute<UpdateUserRequest, UserResponse, MyDomain>(
///     endpoint: "/users/123",
///     domain: .api,
///     body: UpdateUserRequest(name: "John Updated", settings: settings)
/// )
/// ```
public struct EncodablePutRoute<Body: Encodable, Response: Decodable, Domain: ServiceDomain>: EncodableRoute {
    public typealias Response = Response
    public typealias Domain = Domain
    public typealias Body = Body

    public let domain: Domain
    public let endpoint: String
    public let body: Body?
    public let bodyEncoder: JSONEncoder
    public var headers: [String: String]?

    public var method: HTTPMethod { .put }

    /// Creates an encodable PUT route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users/123")
    ///   - domain: The service domain
    ///   - body: The encodable body to send
    ///   - encoder: Optional custom JSON encoder (defaults to JSONEncoder())
    ///   - headers: Optional custom headers
    public init(
        endpoint: String,
        domain: Domain,
        body: Body? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        headers: [String: String]? = nil
    ) {
        self.endpoint = endpoint
        self.domain = domain
        self.body = body
        self.bodyEncoder = encoder
        self.headers = headers
    }
}

// MARK: - Encodable PATCH Route

/// A PATCH route that accepts an Encodable body.
/// Use this for PATCH requests with complex JSON structures.
///
/// Example:
/// ```swift
/// struct PatchUserRequest: Encodable {
///     let email: String?
///     let profile: UserProfile?
/// }
///
/// let route = EncodablePatchRoute<PatchUserRequest, UserResponse, MyDomain>(
///     endpoint: "/users/123",
///     domain: .api,
///     body: PatchUserRequest(email: "newemail@test.com", profile: nil)
/// )
/// ```
public struct EncodablePatchRoute<Body: Encodable, Response: Decodable, Domain: ServiceDomain>: EncodableRoute {
    public typealias Response = Response
    public typealias Domain = Domain
    public typealias Body = Body

    public let domain: Domain
    public let endpoint: String
    public let body: Body?
    public let bodyEncoder: JSONEncoder
    public var headers: [String: String]?

    public var method: HTTPMethod { .patch }

    /// Creates an encodable PATCH route
    /// - Parameters:
    ///   - endpoint: The endpoint path (e.g., "/users/123")
    ///   - domain: The service domain
    ///   - body: The encodable body to send
    ///   - encoder: Optional custom JSON encoder (defaults to JSONEncoder())
    ///   - headers: Optional custom headers
    public init(
        endpoint: String,
        domain: Domain,
        body: Body? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        headers: [String: String]? = nil
    ) {
        self.endpoint = endpoint
        self.domain = domain
        self.body = body
        self.bodyEncoder = encoder
        self.headers = headers
    }
}
