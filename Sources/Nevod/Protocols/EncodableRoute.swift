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
    var bodyData: Data? { nil }

    // Override bodyData(using:) to use the provided encoder from config
    func bodyData(using encoder: JSONEncoder) throws -> Data? {
        guard let body = body else { return nil }
        let encoder = preferredBodyEncoder(fallback: encoder)
        return try encoder.encode(body)
    }

    /// Chooses the encoder for the current route.
    /// If the route provides custom settings, they take precedence over the global config encoder.
    /// Otherwise the config-provided encoder is reused to keep global defaults (dates, keys, etc.).
    private func preferredBodyEncoder(fallback: JSONEncoder) -> JSONEncoder {
        let routeEncoder = bodyEncoder

        // Detect if the route encoder deviates from defaults
        let hasCustomSettings: Bool = {
            switch routeEncoder.dateEncodingStrategy {
            case .deferredToDate: break
            default: return true
            }

            switch routeEncoder.dataEncodingStrategy {
            case .base64: break
            default: return true
            }

            switch routeEncoder.nonConformingFloatEncodingStrategy {
            case .throw: break
            default: return true
            }

            switch routeEncoder.keyEncodingStrategy {
            case .useDefaultKeys: break
            default: return true
            }

            if !routeEncoder.outputFormatting.isEmpty { return true }
            return !routeEncoder.userInfo.isEmpty
        }()

        return hasCustomSettings ? routeEncoder : fallback
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
