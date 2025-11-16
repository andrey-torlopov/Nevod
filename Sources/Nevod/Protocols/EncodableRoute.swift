import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A route that supports Encodable request bodies.
/// This protocol extends Route to allow sending complex JSON structures,
/// not just [String: String] dictionaries.
///
/// Example:
/// ```swift
/// struct CreateUserRequest: Encodable {
///     let user: User
///     let settings: Settings
/// }
///
/// struct CreateUserRoute: EncodableRoute {
///     typealias Response = UserResponse
///     typealias Domain = MyDomain
///     typealias Body = CreateUserRequest
///
///     let domain = MyDomain.api
///     let endpoint = "/users"
///     let method = HTTPMethod.post
///     let body: CreateUserRequest?
/// }
/// ```
public protocol EncodableRoute: Route {
    associatedtype Body: Encodable

    /// The encodable body to send with the request
    var body: Body? { get }

    /// The JSON encoder to use for encoding the body
    /// Defaults to a standard JSONEncoder
    var bodyEncoder: JSONEncoder { get }
}

public extension EncodableRoute {
    // EncodableRoute doesn't use parameters - it uses body instead
    var parameters: [String: String]? { nil }

    // Default encoder (will be overridden by config encoder if available)
    var bodyEncoder: JSONEncoder { JSONEncoder() }

    // Override bodyData to encode using the Encodable body
    var bodyData: Data? {
        guard let body = body else { return nil }
        return try? bodyEncoder.encode(body)
    }

    // Override bodyData(using:) to use the provided encoder from config
    func bodyData(using encoder: JSONEncoder) -> Data? {
        guard let body = body else { return nil }
        return try? encoder.encode(body)
    }
}

// MARK: - Route Extension for Encodable Bodies

public extension Route {
    /// Creates request body data from an Encodable object
    /// - Parameters:
    ///   - encodable: The object to encode
    ///   - encoder: The JSON encoder to use (defaults to JSONEncoder())
    /// - Returns: Encoded data or nil if encoding fails
    func encodeBody<T: Encodable>(_ encodable: T, using encoder: JSONEncoder = JSONEncoder()) -> Data? {
        try? encoder.encode(encodable)
    }
}
