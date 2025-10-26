import Foundation

/// Protocol for defining service domains.
/// Implement this protocol in your domain layer to define custom services.
public protocol ServiceDomain: Hashable, Sendable {
    /// Unique identifier for the service domain
    var identifier: String { get }
}

public extension ServiceDomain {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
