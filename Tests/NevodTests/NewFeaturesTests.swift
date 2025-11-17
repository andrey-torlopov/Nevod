import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Nevod

// MARK: - Test Models

private struct ComplexUser: Codable, Equatable, Sendable {
    let id: Int
    let name: String
    let email: String
    let profile: UserProfile
    let settings: UserSettings
}

private struct UserProfile: Codable, Equatable, Sendable {
    let age: Int
    let bio: String
    let interests: [String]
}

private struct UserSettings: Codable, Equatable, Sendable {
    let notifications: Bool
    let theme: String
}

private struct APIErrorResponse: Codable, Sendable {
    let error: String
    let message: String
    let code: Int
}

// MARK: - Test Domain

private enum TestDomain: ServiceDomain {
    case api
    var identifier: String { "test-api" }
}

// MARK: - Mock Session

private final class MockSession: URLSessionProtocol, @unchecked Sendable {
    let handler: (URLRequest) async throws -> (Data, URLResponse)

    init(handler: @escaping (URLRequest) async throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func requestData(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate?
    ) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

struct NewFeaturesTests {

    // MARK: - Helpers

    private func makeProvider(
        _ handler: @escaping (URLRequest) async throws -> (Data, URLResponse),
        retryPolicy: RetryPolicy? = nil
    ) -> NetworkProvider {
        let session = MockSession(handler: handler)
        let networkConfig = NetworkConfig(
            environments: [TestDomain.api: SimpleEnvironment(baseURL: URL(string: "https://example.com")!)],
            timeout: 1,
            retryPolicy: retryPolicy
        )
        return NetworkProvider(config: networkConfig, session: session, logger: nil)
    }

    // MARK: - EncodableRoute Tests

    @Test func encodablePostRouteWithComplexJSON() async throws {
        let expectedUser = ComplexUser(
            id: 1,
            name: "John Doe",
            email: "john@example.com",
            profile: UserProfile(age: 30, bio: "Software Engineer", interests: ["coding", "music"]),
            settings: UserSettings(notifications: true, theme: "dark")
        )

        let provider = makeProvider { request in
            // Verify request method
            #expect(request.httpMethod == "POST")

            // Verify Content-Type
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            // Verify body can be decoded
            let body = try JSONDecoder().decode(ComplexUser.self, from: request.httpBody!)
            #expect(body == expectedUser)

            let responseData = try JSONEncoder().encode(expectedUser)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }

        let route = EncodablePostRoute<ComplexUser, ComplexUser, TestDomain>(
            endpoint: "/users",
            domain: .api,
            body: expectedUser
        )

        let result = try await provider.perform(route)
        #expect(result == expectedUser)
    }

    @Test func encodablePutRouteUpdatesResource() async throws {
        struct UpdateRequest: Codable {
            let name: String
            let email: String
        }

        let updateData = UpdateRequest(name: "Jane Doe", email: "jane@example.com")

        let provider = makeProvider { request in
            #expect(request.httpMethod == "PUT")

            let body = try JSONDecoder().decode(UpdateRequest.self, from: request.httpBody!)
            #expect(body.name == "Jane Doe")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = EncodablePutRoute<UpdateRequest, Data, TestDomain>(
            endpoint: "/users/1",
            domain: .api,
            body: updateData
        )

        _ = try await provider.perform(route)
    }

    @Test func encodablePatchRoutePartialUpdate() async throws {
        struct PatchRequest: Codable {
            let email: String?
            let name: String?
        }

        let patchData = PatchRequest(email: "newemail@example.com", name: nil)

        let provider = makeProvider { request in
            #expect(request.httpMethod == "PATCH")

            let body = try JSONDecoder().decode(PatchRequest.self, from: request.httpBody!)
            #expect(body.email == "newemail@example.com")
            #expect(body.name == nil)

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = EncodablePatchRoute<PatchRequest, Data, TestDomain>(
            endpoint: "/users/1",
            domain: .api,
            body: patchData
        )

        _ = try await provider.perform(route)
    }

    // MARK: - NetworkError with Response Body Tests

    @Test func networkErrorContainsResponseBody() async {
        let errorResponse = APIErrorResponse(
            error: "validation_failed",
            message: "Email is already taken",
            code: 400
        )

        let provider = makeProvider { request in
            let errorData = try JSONEncoder().encode(errorResponse)
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (errorData, response)
        }

        let route = EncodablePostRoute<ComplexUser, ComplexUser, TestDomain>(
            endpoint: "/users",
            domain: .api,
            body: ComplexUser(
                id: 1,
                name: "Test",
                email: "test@test.com",
                profile: UserProfile(age: 25, bio: "", interests: []),
                settings: UserSettings(notifications: false, theme: "light")
            )
        )

        do {
            _ = try await provider.perform(route)
            #expect(Bool(false), "Should throw error")
        } catch let error as NetworkError {
            // Verify error type
            guard case .clientError(let code, let data, let response) = error else {
                #expect(Bool(false), "Wrong error type")
                return
            }

            #expect(code == 400)
            #expect(data != nil)
            #expect(response != nil)

            // Decode error response
            do {
                let apiError = try error.decode(APIErrorResponse.self)
                #expect(apiError.error == "validation_failed")
                #expect(apiError.message == "Email is already taken")
                #expect(apiError.code == 400)
            } catch {
                #expect(Bool(false), "Failed to decode error response: \(error)")
            }
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test func networkErrorResponseStringProperty() async {
        let errorMessage = "Internal Server Error"

        let provider = makeProvider { request in
            let errorData = errorMessage.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (errorData, response)
        }

        struct EmptyRoute: Route {
            typealias Response = Data
            typealias Domain = TestDomain
            let domain = TestDomain.api
            let endpoint = "/fail"
            let method = HTTPMethod.get
            let parameters: [String: String]? = nil
        }

        do {
            _ = try await provider.perform(EmptyRoute())
            #expect(Bool(false), "Should throw error")
        } catch let error as NetworkError {
            #expect(error.responseString == errorMessage)
            #expect(error.statusCode == 500)
            #expect(error.isHTTPError == true)
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    // MARK: - RetryPolicy Tests

    @Test func retryPolicyExponentialBackoff() async {
        let policy = RetryPolicy(
            maxAttempts: 3,
            baseDelay: 0.1,
            maxDelay: 1.0,
            multiplier: 2.0,
            jitter: false
        )

        // Test delay calculation
        let delay0 = policy.delay(for: 0)
        let delay1 = policy.delay(for: 1)
        let delay2 = policy.delay(for: 2)

        #expect(delay0 == 0.1)  // 0.1 * 2^0
        #expect(delay1 == 0.2)  // 0.1 * 2^1
        #expect(delay2 == 0.4)  // 0.1 * 2^2
    }

    @Test func retryPolicyWithJitter() async {
        let policy = RetryPolicy(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            multiplier: 2.0,
            jitter: true
        )

        // With jitter, delay should be in range [0.5 * calculated, 1.5 * calculated]
        let delay = policy.delay(for: 0)
        #expect(delay >= 0.5 && delay <= 1.5)
    }

    @Test func retryPolicyMaxDelayCap() async {
        let policy = RetryPolicy(
            maxAttempts: 10,
            baseDelay: 1.0,
            maxDelay: 5.0,
            multiplier: 2.0,
            jitter: false
        )

        // Even with high attempts, delay should not exceed maxDelay
        let delay = policy.delay(for: 10)
        #expect(delay <= 5.0)
    }

    // MARK: - SimpleGetRoute with Query Parameters

    @Test func simpleGetRouteWithQueryParams() async throws {
        let provider = makeProvider { request in
            let url = request.url!
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

            let queryItems = components.queryItems!
            #expect(queryItems.contains(where: { $0.name == "page" && $0.value == "1" }))
            #expect(queryItems.contains(where: { $0.name == "limit" && $0.value == "10" }))
            #expect(queryItems.contains(where: { $0.name == "sort" && $0.value == "name" }))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = SimpleGetRoute<Data, TestDomain>(
            endpoint: "/users",
            domain: .api,
            queryParameters: ["page": "1", "limit": "10", "sort": "name"]
        )

        _ = try await provider.perform(route)
    }

    // MARK: - SimplePostRoute with Query and Body

    @Test func simplePostRouteWithQueryAndBody() async throws {
        let provider = makeProvider { request in
            // Verify query parameters
            let url = request.url!
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            let queryItems = components.queryItems!
            #expect(queryItems.contains(where: { $0.name == "notify" && $0.value == "true" }))

            // Verify body
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
            #expect(body["name"] == "John")
            #expect(body["email"] == "john@test.com")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = SimplePostRoute<Data, TestDomain>(
            endpoint: "/users",
            domain: .api,
            queryParameters: ["notify": "true"],
            bodyParameters: ["name": "John", "email": "john@test.com"]
        )

        _ = try await provider.perform(route)
    }

    // MARK: - MultipartRoute Tests

    @Test func multipartRouteUploadsFile() async throws {
        let fileData = "Hello, World!".data(using: .utf8)!
        let fileName = "test.txt"

        let provider = makeProvider { request in
            // Verify Content-Type is multipart/form-data
            let contentType = request.value(forHTTPHeaderField: "Content-Type")!
            #expect(contentType.hasPrefix("multipart/form-data; boundary="))

            // Verify body contains file data
            let bodyString = String(data: request.httpBody!, encoding: .utf8)!
            #expect(bodyString.contains(fileName))
            #expect(bodyString.contains("Hello, World!"))
            #expect(bodyString.contains("Content-Disposition: form-data"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = MultipartRoute<Data, TestDomain>.uploadFile(
            endpoint: "/upload",
            domain: .api,
            fileData: fileData,
            fileName: fileName,
            fieldName: "file",
            mimeType: "text/plain",
            additionalFields: ["userId": "123"]
        )

        _ = try await provider.perform(route)
    }

    @Test func multipartRouteUploadsImage() async throws {
        // Create minimal valid PNG data (1x1 transparent pixel)
        let pngData = Data([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82
        ])

        let provider = makeProvider { request in
            let contentType = request.value(forHTTPHeaderField: "Content-Type")!
            #expect(contentType.hasPrefix("multipart/form-data"))

            let bodyString = String(data: request.httpBody!, encoding: .utf8)!
            #expect(bodyString.contains("avatar.png"))
            #expect(bodyString.contains("image/png"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = MultipartRoute<Data, TestDomain>.uploadImage(
            endpoint: "/avatar",
            domain: .api,
            imageData: pngData,
            fileName: "avatar.png",
            imageType: .png,
            fieldName: "avatar"
        )

        _ = try await provider.perform(route)
    }

    @Test func multipartRouteWithMultipleParts() async throws {
        let parts = [
            FormDataPart(name: "description", data: "Profile photo".data(using: .utf8)!, mimeType: "text/plain"),
            FormDataPart(name: "file", filename: "photo.jpg", data: Data([0xFF, 0xD8, 0xFF]), mimeType: "image/jpeg")
        ]

        let provider = makeProvider { request in
            let contentType = request.value(forHTTPHeaderField: "Content-Type")!
            #expect(contentType.hasPrefix("multipart/form-data"))

            let bodyString = String(data: request.httpBody!, encoding: .utf8)!
            #expect(bodyString.contains("description"))
            #expect(bodyString.contains("Profile photo"))
            #expect(bodyString.contains("photo.jpg"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = MultipartRoute<Data, TestDomain>(
            endpoint: "/upload",
            domain: .api,
            parts: parts
        )

        _ = try await provider.perform(route)
    }

    // MARK: - Quick Mode API Tests

    @Test func quickModeGetRequest() async throws {
        struct User: Codable {
            let id: Int
            let name: String
        }

        let expectedUser = User(id: 1, name: "John")

        let mockSession = MockSession { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/users/1")

            let responseData = try JSONEncoder().encode(expectedUser)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }

        let provider = NetworkProvider.quick(baseURL: URL(string: "https://api.example.com")!)
        // Replace session with mock
        let config = NetworkConfig(
            environments: [DefaultDomain.default: SimpleEnvironment(baseURL: URL(string: "https://api.example.com")!)],
            timeout: 1
        )
        let testProvider = NetworkProvider(config: config, session: mockSession, logger: nil)

        let result: User = try await testProvider.get("/users/1", query: nil)
        #expect(result.id == expectedUser.id)
        #expect(result.name == expectedUser.name)
    }

    @Test func quickModePostRequest() async throws {
        struct CreateUser: Codable {
            let name: String
            let email: String
        }

        struct UserResponse: Codable {
            let id: Int
            let name: String
            let email: String
        }

        let newUser = CreateUser(name: "Jane", email: "jane@example.com")
        let expectedResponse = UserResponse(id: 2, name: "Jane", email: "jane@example.com")

        let mockSession = MockSession { request in
            #expect(request.httpMethod == "POST")

            let body = try JSONDecoder().decode(CreateUser.self, from: request.httpBody!)
            #expect(body.name == "Jane")
            #expect(body.email == "jane@example.com")

            let responseData = try JSONEncoder().encode(expectedResponse)
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }

        let config = NetworkConfig(
            environments: [DefaultDomain.default: SimpleEnvironment(baseURL: URL(string: "https://api.example.com")!)],
            timeout: 1
        )
        let testProvider = NetworkProvider(config: config, session: mockSession, logger: nil)

        let result: UserResponse = try await testProvider.post("/users", body: newUser)
        #expect(result.id == 2)
        #expect(result.name == "Jane")
    }

    @Test func quickModeUploadFile() async throws {
        let fileData = "Test content".data(using: .utf8)!

        let mockSession = MockSession { request in
            let contentType = request.value(forHTTPHeaderField: "Content-Type")!
            #expect(contentType.hasPrefix("multipart/form-data"))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let config = NetworkConfig(
            environments: [DefaultDomain.default: SimpleEnvironment(baseURL: URL(string: "https://api.example.com")!)],
            timeout: 1
        )
        let testProvider = NetworkProvider(config: config, session: mockSession, logger: nil)

        let _: Data = try await testProvider.upload(
            "/files",
            fileData: fileData,
            fileName: "test.txt",
            fieldName: "file",
            mimeType: "text/plain"
        )
    }

    // MARK: - Advanced RetryPolicy Tests

    @Test func retryPolicyWithJitterVariance() async {
        let policy = RetryPolicy(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 10.0,
            multiplier: 2.0,
            jitter: true
        )

        // Run multiple times to verify jitter variance
        var delays: [TimeInterval] = []
        for _ in 0..<10 {
            delays.append(policy.delay(for: 0))
        }

        // All delays should be in the range [0.5, 1.5]
        #expect(delays.allSatisfy { $0 >= 0.5 && $0 <= 1.5 })

        // With jitter, not all delays should be exactly the same
        let uniqueDelays = Set(delays.map { String(format: "%.3f", $0) })
        #expect(uniqueDelays.count > 1)
    }

    @Test func retryPolicyPresets() async {
        // Test default preset
        #expect(RetryPolicy.default.maxAttempts == 3)
        #expect(RetryPolicy.default.baseDelay == 1.0)
        #expect(RetryPolicy.default.jitter == true)

        // Test aggressive preset
        #expect(RetryPolicy.aggressive.maxAttempts == 5)
        #expect(RetryPolicy.aggressive.baseDelay == 0.5)

        // Test conservative preset
        #expect(RetryPolicy.conservative.maxAttempts == 2)
        #expect(RetryPolicy.conservative.jitter == false)

        // Test none preset
        #expect(RetryPolicy.none.maxAttempts == 1)
    }

    @Test func retryPolicyShouldRetryLogic() async {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 1.0, maxDelay: 10.0, multiplier: 2.0, jitter: false)

        #expect(policy.shouldRetry(attempt: 0) == true)
        #expect(policy.shouldRetry(attempt: 1) == true)
        #expect(policy.shouldRetry(attempt: 2) == false)
        #expect(policy.shouldRetry(attempt: 3) == false)
    }

    // MARK: - NetworkError Advanced Tests

    @Test func networkErrorDecodingWithCustomDecoder() async {
        struct CustomErrorResponse: Codable {
            let errorCode: String
            let timestamp: Date
        }

        let date = Date()
        let errorResponse = CustomErrorResponse(errorCode: "ERR_001", timestamp: date)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let errorData = try encoder.encode(errorResponse)

        let provider = makeProvider { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (errorData, response)
        }

        struct EmptyRoute: Route {
            typealias Response = Data
            typealias Domain = TestDomain
            let domain = TestDomain.api
            let endpoint = "/test"
            let method = HTTPMethod.get
            let parameters: [String: String]? = nil
        }

        do {
            _ = try await provider.perform(EmptyRoute())
            #expect(Bool(false), "Should throw error")
        } catch let error as NetworkError {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            do {
                let decoded = try error.decode(CustomErrorResponse.self, using: decoder)
                #expect(decoded.errorCode == "ERR_001")
                // Allow small time difference due to encoding/decoding
                #expect(abs(decoded.timestamp.timeIntervalSince(date)) < 1.0)
            } catch {
                #expect(Bool(false), "Failed to decode with custom decoder: \(error)")
            }
        }
    }

    @Test func networkErrorConvenienceProperties() async {
        let errorData = "Error message".data(using: .utf8)!

        let provider = makeProvider { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (errorData, response)
        }

        struct EmptyRoute: Route {
            typealias Response = Data
            typealias Domain = TestDomain
            let domain = TestDomain.api
            let endpoint = "/test"
            let method = HTTPMethod.get
            let parameters: [String: String]? = nil
        }

        do {
            _ = try await provider.perform(EmptyRoute())
            #expect(Bool(false), "Should throw error")
        } catch let error as NetworkError {
            #expect(error.statusCode == 404)
            #expect(error.isHTTPError == true)
            #expect(error.isConnectivityError == false)
            #expect(error.responseString == "Error message")
            #expect(error.responseData == errorData)
            #expect(error.httpResponse != nil)
        }
    }

    @Test func networkErrorConnectivityErrorFlags() async {
        // Test timeout
        let timeoutProvider = makeProvider { _ in
            throw URLError(.timedOut)
        }

        struct EmptyRoute: Route {
            typealias Response = Data
            typealias Domain = TestDomain
            let domain = TestDomain.api
            let endpoint = "/test"
            let method = HTTPMethod.get
            let parameters: [String: String]? = nil
        }

        do {
            _ = try await timeoutProvider.perform(EmptyRoute())
            #expect(Bool(false), "Should throw error")
        } catch let error as NetworkError {
            #expect(error.isConnectivityError == true)
            #expect(error.isHTTPError == false)
        }

        // Test no connection
        let noConnectionProvider = makeProvider { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await noConnectionProvider.perform(EmptyRoute())
            #expect(Bool(false), "Should throw error")
        } catch let error as NetworkError {
            #expect(error.isConnectivityError == true)
        }
    }

    // MARK: - EncodableRoute Edge Cases

    @Test func encodableRouteWithNilBody() async throws {
        let provider = makeProvider { request in
            #expect(request.httpMethod == "POST")
            // Body should be nil or empty
            #expect(request.httpBody == nil || request.httpBody?.isEmpty == true)

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = EncodablePostRoute<String?, Data, TestDomain>(
            endpoint: "/test",
            domain: .api,
            body: nil
        )

        _ = try await provider.perform(route)
    }

    @Test func encodableRouteWithCustomHeaders() async throws {
        let provider = makeProvider { request in
            #expect(request.value(forHTTPHeaderField: "X-Custom-Header") == "CustomValue")
            #expect(request.value(forHTTPHeaderField: "X-Another-Header") == "AnotherValue")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        struct TestBody: Encodable {
            let value: String
        }

        let route = EncodablePostRoute<TestBody, Data, TestDomain>(
            endpoint: "/test",
            domain: .api,
            body: TestBody(value: "test"),
            headers: [
                "X-Custom-Header": "CustomValue",
                "X-Another-Header": "AnotherValue"
            ]
        )

        _ = try await provider.perform(route)
    }

    @Test func encodableRouteWithNestedStructures() async throws {
        struct NestedProfile: Codable, Equatable {
            let bio: String
            let links: [String]
        }

        struct NestedRequest: Codable, Equatable {
            let name: String
            let profiles: [NestedProfile]
            let metadata: [String: String]
        }

        let request = NestedRequest(
            name: "Test",
            profiles: [
                NestedProfile(bio: "Bio 1", links: ["http://example.com"]),
                NestedProfile(bio: "Bio 2", links: ["http://test.com", "http://demo.com"])
            ],
            metadata: ["key1": "value1", "key2": "value2"]
        )

        let provider = makeProvider { httpRequest in
            let decodedBody = try JSONDecoder().decode(NestedRequest.self, from: httpRequest.httpBody!)
            #expect(decodedBody == request)
            #expect(decodedBody.profiles.count == 2)
            #expect(decodedBody.profiles[1].links.count == 2)

            let response = HTTPURLResponse(url: httpRequest.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = EncodablePostRoute<NestedRequest, Data, TestDomain>(
            endpoint: "/nested",
            domain: .api,
            body: request
        )

        _ = try await provider.perform(route)
    }

    // MARK: - MultipartRoute Edge Cases

    @Test func multipartRouteWithEmptyFileName() async throws {
        let fileData = "content".data(using: .utf8)!

        let provider = makeProvider { request in
            let contentType = request.value(forHTTPHeaderField: "Content-Type")!
            #expect(contentType.hasPrefix("multipart/form-data"))

            let bodyString = String(data: request.httpBody!, encoding: .utf8)!
            // Should still work with empty filename
            #expect(bodyString.contains("filename=\"\""))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = MultipartRoute<Data, TestDomain>.uploadFile(
            endpoint: "/upload",
            domain: .api,
            filename: "",
            fileData: fileData,
            mimeType: "text/plain"
        )

        _ = try await provider.perform(route)
    }

    @Test func multipartRouteWithSpecialCharactersInFilename() async throws {
        let fileData = "content".data(using: .utf8)!
        let specialFilename = "test файл (1).txt"

        let provider = makeProvider { request in
            let bodyString = String(data: request.httpBody!, encoding: .utf8)!
            // Should contain the special filename
            #expect(bodyString.contains(specialFilename))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = MultipartRoute<Data, TestDomain>.uploadFile(
            endpoint: "/upload",
            domain: .api,
            filename: specialFilename,
            fileData: fileData,
            mimeType: "text/plain"
        )

        _ = try await provider.perform(route)
    }

    @Test func multipartRouteWithLargeFile() async throws {
        // Create a 1MB file
        let fileData = Data(count: 1024 * 1024)

        let provider = makeProvider { request in
            #expect(request.httpBody != nil)
            // Body should be larger than 1MB due to multipart overhead
            #expect(request.httpBody!.count > 1024 * 1024)

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = MultipartRoute<Data, TestDomain>.uploadFile(
            endpoint: "/upload",
            domain: .api,
            filename: "large.bin",
            fileData: fileData,
            mimeType: "application/octet-stream"
        )

        _ = try await provider.perform(route)
    }

    // MARK: - Query Parameters Edge Cases

    @Test func simpleGetRouteWithSpecialCharactersInQuery() async throws {
        let provider = makeProvider { request in
            let url = request.url!
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

            // Query parameters should be properly URL encoded
            let queryString = components.percentEncodedQuery ?? ""
            #expect(queryString.contains("search="))
            #expect(queryString.contains("filter="))

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = SimpleGetRoute<Data, TestDomain>(
            endpoint: "/search",
            domain: .api,
            queryParameters: ["search": "hello world", "filter": "type=test&status=active"]
        )

        _ = try await provider.perform(route)
    }

    @Test func simpleGetRouteWithEmptyQueryParameters() async throws {
        let provider = makeProvider { request in
            let url = request.url!
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

            // No query string should be present
            #expect(components.queryItems == nil || components.queryItems?.isEmpty == true)

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }

        let route = SimpleGetRoute<Data, TestDomain>(
            endpoint: "/users",
            domain: .api,
            queryParameters: [:]
        )

        _ = try await provider.perform(route)
    }
}
