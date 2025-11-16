# Advanced Features

This guide covers advanced features of Nevod including encodable routes, multipart uploads, retry policies, and error handling.

## Table of Contents

- [Encodable Routes](#encodable-routes)
- [Multipart File Uploads](#multipart-file-uploads)
- [Retry Policy](#retry-policy)
- [Advanced Error Handling](#advanced-error-handling)
- [Quick Mode API](#quick-mode-api)

## Encodable Routes

Nevod provides specialized route types for sending complex JSON structures using `Encodable` types.

### POST Requests with Encodable Body

```swift
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
    let profile: UserProfile
}

struct UserProfile: Encodable {
    let age: Int
    let bio: String
    let interests: [String]
}

let request = CreateUserRequest(
    name: "John Doe",
    email: "john@example.com",
    profile: UserProfile(
        age: 30,
        bio: "Software Engineer",
        interests: ["coding", "music", "travel"]
    )
)

let route = EncodablePostRoute<CreateUserRequest, User, MyDomain>(
    endpoint: "/users",
    domain: .api,
    body: request
)

let user: User = try await provider.perform(route)
```

### PUT and PATCH Requests

```swift
// Full update with PUT
struct UpdateUserRequest: Encodable {
    let name: String
    let email: String
    let profile: UserProfile
}

let putRoute = EncodablePutRoute<UpdateUserRequest, User, MyDomain>(
    endpoint: "/users/123",
    domain: .api,
    body: updateRequest
)

// Partial update with PATCH
struct PatchUserRequest: Encodable {
    let email: String?
    let bio: String?
}

let patchRoute = EncodablePatchRoute<PatchUserRequest, User, MyDomain>(
    endpoint: "/users/123",
    domain: .api,
    body: PatchUserRequest(email: "newemail@example.com", bio: nil)
)
```

### Custom JSON Encoder

```swift
let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase
encoder.dateEncodingStrategy = .iso8601

let route = EncodablePostRoute<CreateUserRequest, User, MyDomain>(
    endpoint: "/users",
    domain: .api,
    body: request,
    encoder: encoder
)
```

### Custom Headers

```swift
let route = EncodablePostRoute<CreateUserRequest, User, MyDomain>(
    endpoint: "/users",
    domain: .api,
    body: request,
    headers: [
        "X-API-Version": "2.0",
        "X-Client-ID": "mobile-app"
    ]
)
```

## Multipart File Uploads

Nevod supports multipart/form-data for file uploads with a convenient builder API.

### Simple File Upload

```swift
let route = MultipartRoute<UploadResponse, MyDomain>.uploadFile(
    endpoint: "/upload",
    domain: .api,
    filename: "document.pdf",
    fileData: pdfData,
    mimeType: "application/pdf",
    additionalFields: ["title": "My Document", "category": "reports"]
)

let response = try await provider.perform(route)
```

### Image Upload

```swift
let route = MultipartRoute<UploadResponse, MyDomain>.uploadImage(
    endpoint: "/avatar",
    domain: .api,
    filename: "avatar.jpg",
    imageData: jpegData,
    imageType: .jpeg,
    additionalFields: ["userId": "123"]
)
```

Supported image types:
- `.jpeg` - JPEG images
- `.png` - PNG images
- `.gif` - GIF images
- `.bmp` - BMP images
- `.tiff` - TIFF images
- `.webp` - WebP images

### Complex Multipart Form

```swift
var builder = MultipartFormDataBuilder()

// Add text fields
builder.addTextField(name: "title", value: "Photo Album")
builder.addTextField(name: "description", value: "Vacation photos")

// Add multiple files
builder.addImage(name: "photos", filename: "photo1.jpg", data: photo1Data, type: .jpeg)
builder.addImage(name: "photos", filename: "photo2.jpg", data: photo2Data, type: .jpeg)
builder.addFile(name: "metadata", filename: "info.json", data: metadataData, mimeType: "application/json")

let route = MultipartRoute<UploadResponse, MyDomain>(
    endpoint: "/albums",
    domain: .api,
    formData: builder
)
```

### Using FormDataPart Directly

```swift
let parts = [
    FormDataPart(name: "title", data: "My Title".data(using: .utf8)!, mimeType: "text/plain"),
    FormDataPart(name: "file", filename: "doc.pdf", data: pdfData, mimeType: "application/pdf")
]

let route = MultipartRoute<UploadResponse, MyDomain>(
    endpoint: "/upload",
    domain: .api,
    parts: parts
)
```

## Retry Policy

Configure how Nevod retries failed requests with exponential backoff.

### Basic Retry Policy

```swift
let retryPolicy = RetryPolicy(
    maxAttempts: 3,
    baseDelay: 1.0,        // 1 second base delay
    maxDelay: 60.0,        // Max 60 seconds
    multiplier: 2.0,       // Exponential backoff
    jitter: true           // Add randomness to prevent thundering herd
)

let config = NetworkConfig(
    environments: [MyDomain.api: environment],
    timeout: 30,
    retryPolicy: retryPolicy
)
```

### Preset Retry Policies

```swift
// Default: 3 attempts, 1s base delay, exponential backoff with jitter
let config = NetworkConfig(
    environments: [MyDomain.api: environment],
    retryPolicy: .default
)

// Aggressive: 5 attempts, 0.5s base delay
let config = NetworkConfig(
    environments: [MyDomain.api: environment],
    retryPolicy: .aggressive
)

// Conservative: 2 attempts, 2s base delay, no jitter
let config = NetworkConfig(
    environments: [MyDomain.api: environment],
    retryPolicy: .conservative
)

// No retries
let config = NetworkConfig(
    environments: [MyDomain.api: environment],
    retryPolicy: .none
)
```

### Understanding Exponential Backoff

With `baseDelay: 1.0` and `multiplier: 2.0`:

- Attempt 0: 1.0s delay
- Attempt 1: 2.0s delay (1.0 × 2¹)
- Attempt 2: 4.0s delay (1.0 × 2²)
- Attempt 3: 8.0s delay (1.0 × 2³)

With jitter enabled, actual delays vary by ±50% to prevent all clients retrying simultaneously.

### Custom Retry Logic

```swift
let policy = RetryPolicy(
    maxAttempts: 5,
    baseDelay: 0.5,
    maxDelay: 30.0,
    multiplier: 1.5,
    jitter: true
)

// Check if should retry
if policy.shouldRetry(attempt: currentAttempt) {
    // Calculate delay for this attempt
    let delay = policy.delay(for: currentAttempt)
    
    // Perform delay
    try await policy.performDelay(for: currentAttempt)
    
    // Retry request
    // ...
}
```

## Advanced Error Handling

Nevod provides rich error information including response data and convenient decoding methods.

### Accessing Error Response Data

```swift
do {
    let user = try await provider.perform(route)
} catch let error as NetworkError {
    // Get status code
    if let statusCode = error.statusCode {
        print("HTTP Status: \(statusCode)")
    }
    
    // Get response data
    if let data = error.responseData {
        print("Response body: \(String(data: data, encoding: .utf8) ?? "N/A")")
    }
    
    // Get response string
    if let responseString = error.responseString {
        print("Error message: \(responseString)")
    }
    
    // Get HTTP response
    if let httpResponse = error.httpResponse {
        print("Headers: \(httpResponse.allHeaderFields)")
    }
}
```

### Decoding Error Responses

```swift
struct APIError: Codable {
    let error: String
    let message: String
    let code: Int
    let details: [String]?
}

do {
    let user = try await provider.perform(route)
} catch let error as NetworkError {
    // Try to decode the error response
    if let apiError = try? error.decode(APIError.self) {
        print("Error code: \(apiError.code)")
        print("Message: \(apiError.message)")
        if let details = apiError.details {
            print("Details: \(details.joined(separator: ", "))")
        }
    } else {
        // Fallback to raw response
        print("Raw error: \(error.responseString ?? "Unknown")")
    }
}
```

### Custom JSON Decoder for Errors

```swift
struct APIError: Codable {
    let timestamp: Date
    let error: String
}

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

do {
    let user = try await provider.perform(route)
} catch let error as NetworkError {
    if let apiError = try? error.decode(APIError.self, using: decoder) {
        print("Error at: \(apiError.timestamp)")
        print("Message: \(apiError.error)")
    }
}
```

### Error Type Checking

```swift
do {
    let user = try await provider.perform(route)
} catch let error as NetworkError {
    if error.isHTTPError {
        print("HTTP error occurred")
        
        switch error {
        case .unauthorized:
            // Handle 401
            refreshToken()
        case .clientError(let code, _, _):
            print("Client error: \(code)")
        case .serverError(let code, _, _):
            print("Server error: \(code)")
        default:
            break
        }
    }
    
    if error.isConnectivityError {
        print("Network connectivity issue")
        
        switch error {
        case .timeout:
            showRetryDialog()
        case .noConnection:
            showOfflineMode()
        default:
            break
        }
    }
}
```

### Handling Specific Error Codes

```swift
do {
    let user = try await provider.perform(route)
} catch let error as NetworkError {
    switch error.statusCode {
    case 400:
        // Bad request - show validation errors
        if let validationError = try? error.decode(ValidationError.self) {
            showValidationErrors(validationError.fields)
        }
    case 404:
        // Not found
        showNotFoundMessage()
    case 409:
        // Conflict
        showConflictMessage()
    case 429:
        // Rate limited
        if let retryAfter = error.httpResponse?.value(forHTTPHeaderField: "Retry-After") {
            showRateLimitMessage(retryAfter: retryAfter)
        }
    case 500...599:
        // Server error
        showServerErrorMessage()
    default:
        showGenericError()
    }
}
```

## Quick Mode API

For simple use cases with a single API, use Quick Mode to reduce boilerplate.

### Setup

```swift
let provider = NetworkProvider.quick(
    baseURL: URL(string: "https://api.example.com")!,
    timeout: 30,
    retryPolicy: .default
)
```

### GET Requests

```swift
// Simple GET
let users: [User] = try await provider.get("/users")

// GET with query parameters
let users: [User] = try await provider.get(
    "/users",
    query: ["page": "1", "limit": "10", "sort": "name"]
)
```

### POST Requests

```swift
// POST with dictionary
let user: User = try await provider.post(
    "/users",
    body: ["name": "John", "email": "john@test.com"]
)

// POST with encodable body
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
    let profile: UserProfile
}

let request = CreateUserRequest(...)
let user: User = try await provider.post("/users", body: request)

// POST with query and body
let user: User = try await provider.post(
    "/users",
    query: ["notify": "true"],
    body: request
)
```

### PUT and PATCH Requests

```swift
// PUT with encodable body
let user: User = try await provider.put("/users/123", body: updateRequest)

// PATCH for partial updates
struct PatchRequest: Encodable {
    let email: String?
}

let user: User = try await provider.patch(
    "/users/123",
    body: PatchRequest(email: "new@email.com")
)
```

### DELETE Requests

```swift
struct DeleteResponse: Decodable {
    let success: Bool
}

let response: DeleteResponse = try await provider.delete("/users/123")
```

### File Upload

```swift
let response: UploadResponse = try await provider.upload(
    "/upload",
    filename: "document.pdf",
    fileData: pdfData,
    mimeType: "application/pdf",
    additionalFields: ["title": "My Document"]
)
```

### Image Upload

```swift
let response: UploadResponse = try await provider.uploadImage(
    "/avatar",
    filename: "avatar.jpg",
    imageData: jpegData,
    imageType: .jpeg,
    additionalFields: ["userId": "123"]
)
```

## Best Practices

### 1. Use Encodable Routes for Complex Data

```swift
// ❌ Don't use string dictionaries for complex data
let params = [
    "name": "John",
    "age": "30",
    "interests": "coding,music"  // Awkward serialization
]

// ✅ Use Encodable types
struct CreateUser: Encodable {
    let name: String
    let age: Int
    let interests: [String]
}
```

### 2. Configure Retry Policy Based on Use Case

```swift
// Critical user-facing operations
let config = NetworkConfig(
    environments: [MyDomain.api: env],
    retryPolicy: .aggressive  // More attempts, faster retries
)

// Background sync operations
let config = NetworkConfig(
    environments: [MyDomain.api: env],
    retryPolicy: .conservative  // Fewer attempts, longer delays
)

// Real-time operations (chat, live updates)
let config = NetworkConfig(
    environments: [MyDomain.api: env],
    retryPolicy: .none  // No retries, fail fast
)
```

### 3. Handle Errors Gracefully

```swift
do {
    let user = try await provider.perform(route)
    // Success
} catch let error as NetworkError {
    // Always provide user feedback
    if error.isConnectivityError {
        showAlert("Check your internet connection")
    } else if let apiError = try? error.decode(APIError.self) {
        showAlert(apiError.message)
    } else {
        showAlert("An error occurred. Please try again.")
    }
    
    // Log for debugging
    logger.error("Request failed: \(error)")
}
```

### 4. Use Quick Mode for Prototyping

```swift
// Quick Mode is perfect for:
// - Prototyping
// - Simple apps with one API
// - Scripts and tools

let provider = NetworkProvider.quick(
    baseURL: URL(string: "https://api.example.com")!
)

let data: ResponseModel = try await provider.get("/endpoint")
```

## Next Steps

- See [Authentication Guide](./Authentication.md) for auth setup
- See [Quick Start](./QuickStart.md) for basic usage
- Check out [Real Use Cases](./UseCases.md) for practical examples
