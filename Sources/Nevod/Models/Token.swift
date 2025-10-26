import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Simple Bearer token implementation
///
/// This is a basic token type that adds "Bearer {value}" to the Authorization header.
/// For more complex authentication schemes (OAuth, API keys, etc.), create your own
/// type conforming to TokenModel protocol.
public struct Token: Sendable, TokenModel, Codable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
    
    // MARK: - TokenModel
    
    public func authorize(_ request: inout URLRequest) {
        request.setValue("Bearer \(value)", forHTTPHeaderField: "Authorization")
    }
    
    public func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }
    
    public static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}
