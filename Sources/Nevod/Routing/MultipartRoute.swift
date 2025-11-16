import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A route that sends multipart/form-data
/// Use this for file uploads and complex form submissions
///
/// Example:
/// ```swift
/// var builder = MultipartFormDataBuilder()
/// builder.addTextField(name: "title", value: "My Photo")
/// builder.addImage(name: "photo", filename: "avatar.jpg", data: imageData, type: .jpeg)
///
/// let route = MultipartRoute<UploadResponse, MyDomain>(
///     endpoint: "/upload",
///     domain: .api,
///     formData: builder
/// )
/// ```
public struct MultipartRoute<Response: Decodable, Domain: ServiceDomain>: Route {
    public typealias Response = Response
    public typealias Domain = Domain

    public let domain: Domain
    public let endpoint: String
    public let method: HTTPMethod

    private let formData: MultipartFormDataBuilder
    private let builtData: (data: Data, contentType: String)

    // Route protocol requirements
    public var parameters: [String: String]? { nil }

    public var headers: [String: String]? {
        ["Content-Type": builtData.contentType]
    }

    public var bodyData: Data? {
        builtData.data
    }

    /// Creates a multipart route
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - domain: The service domain
    ///   - method: The HTTP method (defaults to POST)
    ///   - formData: The multipart form data builder
    public init(
        endpoint: String,
        domain: Domain,
        method: HTTPMethod = .post,
        formData: MultipartFormDataBuilder
    ) {
        self.endpoint = endpoint
        self.domain = domain
        self.method = method
        self.formData = formData
        self.builtData = formData.build()
    }

    /// Creates a multipart route with parts
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - domain: The service domain
    ///   - method: The HTTP method (defaults to POST)
    ///   - parts: Array of form data parts
    ///   - boundary: Optional custom boundary
    public init(
        endpoint: String,
        domain: Domain,
        method: HTTPMethod = .post,
        parts: [FormDataPart],
        boundary: String = UUID().uuidString
    ) {
        var builder = MultipartFormDataBuilder(boundary: boundary)
        for part in parts {
            builder.addPart(part)
        }

        self.init(
            endpoint: endpoint,
            domain: domain,
            method: method,
            formData: builder
        )
    }
}

// MARK: - Convenience Extensions

public extension MultipartRoute {
    /// Creates a multipart route for uploading a single file
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - domain: The service domain
    ///   - fieldName: The field name for the file (defaults to "file")
    ///   - filename: The filename
    ///   - fileData: The file data
    ///   - mimeType: The MIME type
    ///   - additionalFields: Optional additional text fields
    static func uploadFile(
        endpoint: String,
        domain: Domain,
        fieldName: String = "file",
        filename: String,
        fileData: Data,
        mimeType: String,
        additionalFields: [String: String] = [:]
    ) -> MultipartRoute {
        var builder = MultipartFormDataBuilder()

        // Add additional text fields
        for (key, value) in additionalFields {
            builder.addTextField(name: key, value: value)
        }

        // Add file
        builder.addFile(name: fieldName, filename: filename, data: fileData, mimeType: mimeType)

        return MultipartRoute(
            endpoint: endpoint,
            domain: domain,
            formData: builder
        )
    }

    /// Creates a multipart route for uploading an image
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - domain: The service domain
    ///   - fieldName: The field name for the image (defaults to "image")
    ///   - filename: The filename
    ///   - imageData: The image data
    ///   - imageType: The image type
    ///   - additionalFields: Optional additional text fields
    static func uploadImage(
        endpoint: String,
        domain: Domain,
        fieldName: String = "image",
        filename: String,
        imageData: Data,
        imageType: FormDataPart.ImageType,
        additionalFields: [String: String] = [:]
    ) -> MultipartRoute {
        var builder = MultipartFormDataBuilder()

        // Add additional text fields
        for (key, value) in additionalFields {
            builder.addTextField(name: key, value: value)
        }

        // Add image
        builder.addImage(name: fieldName, filename: filename, data: imageData, type: imageType)

        return MultipartRoute(
            endpoint: endpoint,
            domain: domain,
            formData: builder
        )
    }
}
