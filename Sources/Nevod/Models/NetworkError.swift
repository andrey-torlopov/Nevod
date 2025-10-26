import Foundation

public enum NetworkError: Error, Equatable {
    case invalidURL
    case parsingError
    case timeout
    case noConnection
    case unauthorized
    case clientError(Int)
    case serverError(Int)
    case bodyEncodingFailed
    case unknown(Error)

    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
            (.parsingError, .parsingError),
            (.timeout, .timeout),
            (.noConnection, .noConnection),
            (.bodyEncodingFailed, .bodyEncodingFailed),
            (.unauthorized, .unauthorized):
            return true
        case (.clientError(let lCode), .clientError(let rCode)):
            return lCode == rCode
        case (.serverError(let lCode), .serverError(let rCode)):
            return lCode == rCode
        default:
            return false
        }
    }
}
