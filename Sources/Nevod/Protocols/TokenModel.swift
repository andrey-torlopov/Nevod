import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Protocol for authentication token models
///
/// Token models are simple data structures that know how to:
/// - Authorize requests by adding appropriate headers
/// - Serialize/deserialize themselves for storage
///
/// Token models should NOT contain refresh logic - that's handled externally
public protocol TokenModel: Sendable {
    /// Adds authorization to the request (e.g., Bearer token, API key)
    /// - Parameter request: The request to authorize
    func authorize(_ request: inout URLRequest)
    
    /// Encodes the token for storage
    func encode() throws -> Data
    
    /// Decodes the token from storage
    static func decode(from data: Data) throws -> Self
}
