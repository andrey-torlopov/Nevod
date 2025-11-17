import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum NetworkError: Error, Equatable {
    case invalidURL
    case missingEnvironment(domain: String)
    case parsingError(data: Data?, underlyingError: String?)
    case timeout
    case noConnection
    case cancelled
    case unauthorized(data: Data?, response: HTTPURLResponse?)
    case clientError(code: Int, data: Data?, response: HTTPURLResponse?)
    case serverError(code: Int, data: Data?, response: HTTPURLResponse?)
    case bodyEncodingFailed
    case unknown(Error)
    case authenticationFailed
    case invalidResponse(data: Data?, response: HTTPURLResponse?)

    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
            (.timeout, .timeout),
            (.noConnection, .noConnection),
            (.cancelled, .cancelled),
            (.bodyEncodingFailed, .bodyEncodingFailed),
            (.authenticationFailed, .authenticationFailed):
            return true

        case (.missingEnvironment(let lhsDomain), .missingEnvironment(let rhsDomain)):
            return lhsDomain == rhsDomain

        case (.parsingError(let lData, let lError), .parsingError(let rData, let rError)):
            return lData == rData && lError == rError

        case (.unauthorized(let lData, let lResponse), .unauthorized(let rData, let rResponse)):
            return lData == rData && lResponse?.statusCode == rResponse?.statusCode

        case (.clientError(let lCode, let lData, let lResponse), .clientError(let rCode, let rData, let rResponse)):
            return lCode == rCode && lData == rData && lResponse?.statusCode == rResponse?.statusCode

        case (.serverError(let lCode, let lData, let lResponse), .serverError(let rCode, let rData, let rResponse)):
            return lCode == rCode && lData == rData && lResponse?.statusCode == rResponse?.statusCode

        case (.invalidResponse(let lData, let lResponse), .invalidResponse(let rData, let rResponse)):
            return lData == rData && lResponse?.statusCode == rResponse?.statusCode

        default:
            return false
        }
    }
}

// MARK: - Convenience Properties

public extension NetworkError {
    /// The response data if available
    var responseData: Data? {
        switch self {
        case .parsingError(let data, _),
             .unauthorized(let data, _),
             .clientError(_, let data, _),
             .serverError(_, let data, _),
             .invalidResponse(let data, _):
            return data
        default:
            return nil
        }
    }

    /// The HTTP response if available
    var httpResponse: HTTPURLResponse? {
        switch self {
        case .unauthorized(_, let response),
             .clientError(_, _, let response),
             .serverError(_, _, let response),
             .invalidResponse(_, let response):
            return response
        default:
            return nil
        }
    }

    /// The HTTP status code if available
    var statusCode: Int? {
        switch self {
        case .unauthorized(_, let response):
            return response?.statusCode ?? 401
        case .clientError(let code, _, _),
             .serverError(let code, _, _):
            return code
        case .invalidResponse(_, let response):
            return response?.statusCode
        default:
            return nil
        }
    }

    /// Attempts to decode the response data as a specific type
    /// - Parameters:
    ///   - type: The type to decode to
    ///   - decoder: The JSON decoder to use (defaults to JSONDecoder())
    /// - Returns: The decoded object or nil if decoding fails
    func decode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard let data = responseData else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "No response data available"
                )
            )
        }
        return try decoder.decode(type, from: data)
    }

    /// Attempts to decode the response data as a specific type, returning nil if it fails
    /// - Parameters:
    ///   - type: The type to decode to
    ///   - decoder: The JSON decoder to use (defaults to JSONDecoder())
    /// - Returns: The decoded object or nil if decoding fails
    func tryDecode<T: Decodable>(_ type: T.Type, using decoder: JSONDecoder = JSONDecoder()) -> T? {
        try? decode(type, using: decoder)
    }

    /// The response body as a String (UTF-8)
    var responseString: String? {
        guard let data = responseData else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Returns true if this is an HTTP error (client or server error)
    var isHTTPError: Bool {
        switch self {
        case .unauthorized, .clientError, .serverError:
            return true
        default:
            return false
        }
    }

    /// Returns true if this is a network connectivity error
    var isConnectivityError: Bool {
        switch self {
        case .timeout, .noConnection:
            return true
        default:
            return false
        }
    }
}

// MARK: - Factory Methods

public extension NetworkError {
    /// Creates a parsing error with details
    /// - Parameters:
    ///   - data: The data that failed to parse
    ///   - error: The underlying error
    /// - Returns: A NetworkError.parsingError
    static func parsingError(data: Data?, error: Error) -> NetworkError {
        .parsingError(data: data, underlyingError: error.localizedDescription)
    }

    /// Creates a client error from an HTTP response
    /// - Parameters:
    ///   - response: The HTTP response
    ///   - data: The response data
    /// - Returns: A NetworkError.clientError or .unauthorized
    static func clientError(response: HTTPURLResponse, data: Data?) -> NetworkError {
        if response.statusCode == 401 {
            return .unauthorized(data: data, response: response)
        }
        return .clientError(code: response.statusCode, data: data, response: response)
    }

    /// Creates a server error from an HTTP response
    /// - Parameters:
    ///   - response: The HTTP response
    ///   - data: The response data
    /// - Returns: A NetworkError.serverError
    static func serverError(response: HTTPURLResponse, data: Data?) -> NetworkError {
        .serverError(code: response.statusCode, data: data, response: response)
    }
}

// MARK: - CustomStringConvertible

extension NetworkError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .missingEnvironment(let domain):
            return "Missing environment for domain: \(domain)"
        case .parsingError(let data, let error):
            var desc = "Parsing error"
            if let error = error {
                desc += ": \(error)"
            }
            if let data = data, let str = String(data: data, encoding: .utf8) {
                desc += "\nResponse: \(str.prefix(200))"
            }
            return desc
        case .timeout:
            return "Request timed out"
        case .noConnection:
            return "No internet connection"
        case .cancelled:
            return "Request was cancelled"
        case .unauthorized(let data, let response):
            var desc = "Unauthorized (401)"
            if let response = response {
                desc += " from \(response.url?.absoluteString ?? "unknown URL")"
            }
            if let data = data, let str = String(data: data, encoding: .utf8) {
                desc += "\nResponse: \(str.prefix(200))"
            }
            return desc
        case .clientError(let code, let data, let response):
            var desc = "Client error (\(code))"
            if let response = response {
                desc += " from \(response.url?.absoluteString ?? "unknown URL")"
            }
            if let data = data, let str = String(data: data, encoding: .utf8) {
                desc += "\nResponse: \(str.prefix(200))"
            }
            return desc
        case .serverError(let code, let data, let response):
            var desc = "Server error (\(code))"
            if let response = response {
                desc += " from \(response.url?.absoluteString ?? "unknown URL")"
            }
            if let data = data, let str = String(data: data, encoding: .utf8) {
                desc += "\nResponse: \(str.prefix(200))"
            }
            return desc
        case .bodyEncodingFailed:
            return "Failed to encode request body"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidResponse(let data, let response):
            var desc = "Invalid response"
            if let response = response {
                desc += " (\(response.statusCode)) from \(response.url?.absoluteString ?? "unknown URL")"
            }
            if let data = data, let str = String(data: data, encoding: .utf8) {
                desc += "\nResponse: \(str.prefix(200))"
            }
            return desc
        }
    }
}
