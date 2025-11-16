import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Represents a single part of a multipart/form-data request
public struct FormDataPart: Sendable {
    /// The field name for this part
    public let name: String

    /// Optional filename (required for file uploads)
    public let filename: String?

    /// The data for this part
    public let data: Data

    /// The MIME type of the data
    public let mimeType: String

    /// Creates a form data part for a text field
    /// - Parameters:
    ///   - name: The field name
    ///   - value: The text value
    public init(name: String, value: String) {
        self.name = name
        self.filename = nil
        self.data = value.data(using: .utf8) ?? Data()
        self.mimeType = "text/plain"
    }

    /// Creates a form data part for raw data
    /// - Parameters:
    ///   - name: The field name
    ///   - data: The data to send
    ///   - mimeType: The MIME type (defaults to "application/octet-stream")
    public init(name: String, data: Data, mimeType: String = "application/octet-stream") {
        self.name = name
        self.filename = nil
        self.data = data
        self.mimeType = mimeType
    }

    /// Creates a form data part for a file upload
    /// - Parameters:
    ///   - name: The field name
    ///   - filename: The filename to send
    ///   - data: The file data
    ///   - mimeType: The MIME type of the file
    public init(name: String, filename: String, data: Data, mimeType: String) {
        self.name = name
        self.filename = filename
        self.data = data
        self.mimeType = mimeType
    }

    /// Creates a form data part for an image
    /// - Parameters:
    ///   - name: The field name
    ///   - filename: The filename to send
    ///   - imageData: The image data (JPEG or PNG)
    ///   - imageType: The image type ("jpeg" or "png")
    public static func image(name: String, filename: String, data: Data, type: ImageType) -> FormDataPart {
        FormDataPart(
            name: name,
            filename: filename,
            data: data,
            mimeType: type.mimeType
        )
    }

    /// Supported image types for convenience
    public enum ImageType {
        case jpeg
        case png
        case gif
        case webp

        var mimeType: String {
            switch self {
            case .jpeg: return "image/jpeg"
            case .png: return "image/png"
            case .gif: return "image/gif"
            case .webp: return "image/webp"
            }
        }

        var fileExtension: String {
            switch self {
            case .jpeg: return "jpg"
            case .png: return "png"
            case .gif: return "gif"
            case .webp: return "webp"
            }
        }
    }
}

/// Helper for building multipart/form-data requests
public struct MultipartFormDataBuilder: Sendable {
    private let boundary: String
    private var parts: [FormDataPart]

    /// Creates a new multipart form data builder
    /// - Parameter boundary: Optional custom boundary (a random UUID will be used if not provided)
    public init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
        self.parts = []
    }

    /// Adds a text field to the form data
    /// - Parameters:
    ///   - name: The field name
    ///   - value: The text value
    /// - Returns: Self for chaining
    @discardableResult
    public mutating func addTextField(name: String, value: String) -> Self {
        parts.append(FormDataPart(name: name, value: value))
        return self
    }

    /// Adds a file to the form data
    /// - Parameters:
    ///   - name: The field name
    ///   - filename: The filename
    ///   - data: The file data
    ///   - mimeType: The MIME type
    /// - Returns: Self for chaining
    @discardableResult
    public mutating func addFile(name: String, filename: String, data: Data, mimeType: String) -> Self {
        parts.append(FormDataPart(name: name, filename: filename, data: data, mimeType: mimeType))
        return self
    }

    /// Adds an image to the form data
    /// - Parameters:
    ///   - name: The field name
    ///   - filename: The filename
    ///   - data: The image data
    ///   - type: The image type
    /// - Returns: Self for chaining
    @discardableResult
    public mutating func addImage(name: String, filename: String, data: Data, type: FormDataPart.ImageType) -> Self {
        parts.append(FormDataPart.image(name: name, filename: filename, data: data, type: type))
        return self
    }

    /// Adds a custom form data part
    /// - Parameter part: The form data part to add
    /// - Returns: Self for chaining
    @discardableResult
    public mutating func addPart(_ part: FormDataPart) -> Self {
        parts.append(part)
        return self
    }

    /// Builds the multipart form data body
    /// - Returns: The encoded multipart form data
    public func build() -> (data: Data, contentType: String) {
        var body = Data()

        // Add each part
        for part in parts {
            // Boundary
            body.append("--\(boundary)\r\n")

            // Content-Disposition header
            var disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
            if let filename = part.filename {
                disposition += "; filename=\"\(filename)\""
            }
            body.append(disposition + "\r\n")

            // Content-Type header
            body.append("Content-Type: \(part.mimeType)\r\n\r\n")

            // Data
            body.append(part.data)
            body.append("\r\n")
        }

        // Final boundary
        body.append("--\(boundary)--\r\n")

        let contentType = "multipart/form-data; boundary=\(boundary)"
        return (data: body, contentType: contentType)
    }

    /// The boundary string used for this builder
    public var boundaryString: String { boundary }
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
