import Foundation
import Storage

public actor TokenStorage {
    private let storage: any KeyValueStorage
    private var token: Token?

    public init(storage: any KeyValueStorage) {
        self.storage = storage
        if let value = storage.string(for: .token) {
            self.token = Token(value: value)
        }
    }

    public func tokenValue() -> String? {
        token?.value
    }

    public func setToken(_ token: consuming Token?) {
        self.token = token
        storage.set(self.token?.value, for: .token)
    }
}
