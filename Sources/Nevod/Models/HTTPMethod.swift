public enum HTTPMethod: String {
    case get
    case post
    case put
    case patch
    case delete

    public var stringValue: String { self.rawValue.uppercased() }
}
