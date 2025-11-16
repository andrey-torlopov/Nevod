import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Letopis

// MARK: - Default Domain for Quick Mode

/// Default domain for simple single-API scenarios
public enum DefaultDomain: ServiceDomain {
    case `default`

    public var identifier: String { "default" }
}

// MARK: - Quick Mode Extensions

public extension NetworkProvider {
    /// Creates a quick network provider for simple scenarios with a single API
    /// - Parameters:
    ///   - baseURL: The base URL for the API
    ///   - timeout: Request timeout (default: 30 seconds)
    ///   - retries: Number of retries (default: 3)
    ///   - retryPolicy: Optional retry policy with exponential backoff
    /// - Returns: A configured NetworkProvider
    ///
    /// Example:
    /// ```swift
    /// let provider = NetworkProvider.quick(
    ///     baseURL: URL(string: "https://api.example.com")!
    /// )
    /// ```
    static func quick(
        baseURL: URL,
        timeout: TimeInterval = 30,
        retries: Int = 3,
        rateLimit: RateLimitConfiguration? = nil,
        retryPolicy: RetryPolicy? = nil,
        jsonEncoder: JSONEncoder = JSONEncoder(),
        jsonDecoder: JSONDecoder = JSONDecoder(),
        session: URLSessionProtocol = URLSessionType.shared,
        interceptor: (any RequestInterceptor)? = nil,
        rateLimiter: (any RateLimiting)? = nil,
        logger: Letopis? = Letopis(interceptors: [ConsoleInterceptor()])
    ) -> NetworkProvider {
        let config = NetworkConfig(
            environments: [DefaultDomain.default: SimpleEnvironment(baseURL: baseURL)],
            timeout: timeout,
            retries: retries,
            rateLimit: rateLimit,
            jsonEncoder: jsonEncoder,
            jsonDecoder: jsonDecoder,
            retryPolicy: retryPolicy
        )
        return NetworkProvider(
            config: config,
            session: session,
            interceptor: interceptor,
            rateLimiter: rateLimiter,
            logger: logger
        )
    }

    /// Performs a simple GET request
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - query: Optional query parameters
    /// - Returns: The decoded response
    ///
    /// Example:
    /// ```swift
    /// let users: [User] = try await provider.get("/users", query: ["page": "1"])
    /// ```
    func get<T: Decodable>(
        _ endpoint: String,
        query: [String: String]? = nil
    ) async throws -> T {
        let route = SimpleGetRoute<T, DefaultDomain>(
            endpoint: endpoint,
            domain: .default,
            queryParameters: query
        )
        return try await perform(route)
    }

    /// Performs a simple POST request with a dictionary body
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - query: Optional query parameters
    ///   - body: Dictionary body parameters
    /// - Returns: The decoded response
    ///
    /// Example:
    /// ```swift
    /// let user: User = try await provider.post("/users", body: ["name": "John", "email": "john@test.com"])
    /// ```
    func post<T: Decodable>(
        _ endpoint: String,
        query: [String: String]? = nil,
        body: [String: String]? = nil
    ) async throws -> T {
        let route = SimplePostRoute<T, DefaultDomain>(
            endpoint: endpoint,
            domain: .default,
            queryParameters: query,
            bodyParameters: body
        )
        return try await perform(route)
    }

    /// Performs a POST request with an encodable body
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - query: Optional query parameters
    ///   - body: Encodable body object
    /// - Returns: The decoded response
    ///
    /// Example:
    /// ```swift
    /// struct CreateUserRequest: Encodable {
    ///     let name: String
    ///     let email: String
    ///     let profile: UserProfile
    /// }
    ///
    /// let request = CreateUserRequest(name: "John", email: "john@test.com", profile: profile)
    /// let user: User = try await provider.post("/users", body: request)
    /// ```
    func post<Body: Encodable, Response: Decodable>(
        _ endpoint: String,
        query: [String: String]? = nil,
        body: Body
    ) async throws -> Response {
        let route = EncodablePostRoute<Body, Response, DefaultDomain>(
            endpoint: endpoint,
            domain: .default,
            queryParameters: query,
            body: body
        )

        return try await perform(route)
    }

    /// Performs a simple PUT request with a dictionary body
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - query: Optional query parameters
    ///   - body: Dictionary body parameters
    /// - Returns: The decoded response
    ///
    /// Example:
    /// ```swift
    /// let user: User = try await provider.put("/users/123", body: ["name": "John Updated"])
    /// ```
    func put<T: Decodable>(
        _ endpoint: String,
        query: [String: String]? = nil,
        body: [String: String]? = nil
    ) async throws -> T {
        let route = SimplePutRoute<T, DefaultDomain>(
            endpoint: endpoint,
            domain: .default,
            queryParameters: query,
            bodyParameters: body
        )
        return try await perform(route)
    }

    /// Performs a PUT request with an encodable body
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - query: Optional query parameters
    ///   - body: Encodable body object
    /// - Returns: The decoded response
    func put<Body: Encodable, Response: Decodable>(
        _ endpoint: String,
        query: [String: String]? = nil,
        body: Body
    ) async throws -> Response {
        let route = EncodablePutRoute<Body, Response, DefaultDomain>(
            endpoint: endpoint,
            domain: .default,
            queryParameters: query,
            body: body
        )

        return try await perform(route)
    }

    /// Performs a PATCH request with an encodable body
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - query: Optional query parameters
    ///   - body: Encodable body object
    /// - Returns: The decoded response
    func patch<Body: Encodable, Response: Decodable>(
        _ endpoint: String,
        query: [String: String]? = nil,
        body: Body
    ) async throws -> Response {
        let route = EncodablePatchRoute<Body, Response, DefaultDomain>(
            endpoint: endpoint,
            domain: .default,
            queryParameters: query,
            body: body
        )

        return try await perform(route)
    }

    /// Performs a simple DELETE request
    /// - Parameter endpoint: The endpoint path
    /// - Returns: The decoded response
    ///
    /// Example:
    /// ```swift
    /// let result: DeleteResponse = try await provider.delete("/users/123")
    /// ```
    func delete<T: Decodable>(_ endpoint: String) async throws -> T {
        let route = SimpleDeleteRoute<T, DefaultDomain>(
            endpoint: endpoint,
            domain: .default
        )
        return try await perform(route)
    }

    /// Uploads a file using multipart/form-data
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - fieldName: The field name for the file (default: "file")
    ///   - filename: The filename
    ///   - fileData: The file data
    ///   - mimeType: The MIME type
    ///   - additionalFields: Optional additional text fields
    /// - Returns: The decoded response
    ///
    /// Example:
    /// ```swift
    /// let response: UploadResponse = try await provider.upload(
    ///     "/upload",
    ///     filename: "document.pdf",
    ///     fileData: pdfData,
    ///     mimeType: "application/pdf",
    ///     additionalFields: ["title": "My Document"]
    /// )
    /// ```
    func upload<T: Decodable>(
        _ endpoint: String,
        fieldName: String = "file",
        filename: String,
        fileData: Data,
        mimeType: String,
        additionalFields: [String: String] = [:]
    ) async throws -> T {
        let route = MultipartRoute<T, DefaultDomain>.uploadFile(
            endpoint: endpoint,
            domain: .default,
            fieldName: fieldName,
            filename: filename,
            fileData: fileData,
            mimeType: mimeType,
            additionalFields: additionalFields
        )
        return try await perform(route)
    }

    /// Uploads an image using multipart/form-data
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - fieldName: The field name for the image (default: "image")
    ///   - filename: The filename
    ///   - imageData: The image data
    ///   - imageType: The image type (jpeg, png, etc.)
    ///   - additionalFields: Optional additional text fields
    /// - Returns: The decoded response
    ///
    /// Example:
    /// ```swift
    /// let response: UploadResponse = try await provider.uploadImage(
    ///     "/upload/avatar",
    ///     filename: "avatar.jpg",
    ///     imageData: jpegData,
    ///     imageType: .jpeg,
    ///     additionalFields: ["userId": "123"]
    /// )
    /// ```
    func uploadImage<T: Decodable>(
        _ endpoint: String,
        fieldName: String = "image",
        filename: String,
        imageData: Data,
        imageType: FormDataPart.ImageType,
        additionalFields: [String: String] = [:]
    ) async throws -> T {
        let route = MultipartRoute<T, DefaultDomain>.uploadImage(
            endpoint: endpoint,
            domain: .default,
            fieldName: fieldName,
            filename: filename,
            imageData: imageData,
            imageType: imageType,
            additionalFields: additionalFields
        )
        return try await perform(route)
    }
}
