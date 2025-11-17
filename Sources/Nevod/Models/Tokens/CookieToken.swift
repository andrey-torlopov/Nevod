import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Cookie-based authentication token
///
/// This token type manages HTTP cookies for session-based authentication.
/// Common in traditional web APIs and services like Space-Track.org.
///
/// Example usage:
/// ```swift
/// // After login, create token from cookies
/// let cookies = HTTPCookieStorage.shared.cookies(for: loginURL) ?? []
/// let token = CookieToken(sessionCookies: cookies)
///
/// // Token will be automatically applied to requests
/// ```
public struct CookieToken: Sendable, TokenModel {
    public let sessionCookies: [HTTPCookie]

    public init(sessionCookies: [HTTPCookie]) {
        self.sessionCookies = sessionCookies
    }

    // MARK: - TokenModel

    /// Applies cookies to the request
    /// Cookies are added via the Cookie header field
    public func authorize(_ request: inout URLRequest) {
        guard !sessionCookies.isEmpty else { return }

        let cookieHeader = HTTPCookie.requestHeaderFields(with: sessionCookies)
        cookieHeader.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
    }

    public func encode() throws -> Data {
        let codableList = sessionCookies.map { CookieCodable($0) }
        return try JSONEncoder().encode(codableList)
    }

    public static func decode(from data: Data) throws -> Self {
        let codableList = try JSONDecoder().decode([CookieCodable].self, from: data)
        let cookies = codableList.compactMap { $0.toCookie() }
        return CookieToken(sessionCookies: cookies)
    }
}

// MARK: - Helper for HTTPCookie serialization

/// Codable wrapper for HTTPCookie since HTTPCookie itself is not Codable
private struct CookieCodable: Codable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresDate: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool

    init(_ cookie: HTTPCookie) {
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.expiresDate = cookie.expiresDate
        self.isSecure = cookie.isSecure
        self.isHTTPOnly = cookie.isHTTPOnly
    }

    func toCookie() -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path,
            .secure: isSecure
        ]

        if let expiresDate = expiresDate {
            properties[.expires] = expiresDate
        }

        if isHTTPOnly {
            properties[HTTPCookiePropertyKey(rawValue: "HttpOnly")] = true
        }

        return HTTPCookie(properties: properties)
    }
}
