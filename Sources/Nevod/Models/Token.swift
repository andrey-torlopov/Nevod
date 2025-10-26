import Foundation

public struct Token: ~Copyable, Sendable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}
