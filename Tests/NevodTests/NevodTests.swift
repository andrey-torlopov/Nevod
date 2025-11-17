import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Nevod

// MARK: - Mock Storage

private final class MockStorage: KeyValueStorage, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    private let lock = NSLock()

    nonisolated func string(for key: StorageKey) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key.value] as? String
    }

    nonisolated func data(for key: StorageKey) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key.value] as? Data
    }

    nonisolated func set(_ value: String?, for key: StorageKey) {
        lock.lock()
        defer { lock.unlock() }
        storage[key.value] = value
    }

    nonisolated func set(_ value: Data?, for key: StorageKey) {
        lock.lock()
        defer { lock.unlock() }
        storage[key.value] = value
    }

    nonisolated func remove(for key: StorageKey) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key.value)
    }
}

private final class MockSession: URLSessionProtocol, @unchecked Sendable {
    let handler: (URLRequest) async throws -> (Data, URLResponse)
    private(set) var lastDelegate: URLSessionTaskDelegate?

    init(handler: @escaping (URLRequest) async throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func requestData(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate?
    ) async throws -> (Data, URLResponse) {
        lastDelegate = delegate
        return try await handler(request)
    }
}

private final class MockDelegate: NSObject, URLSessionTaskDelegate {}

// Test domain
private enum TestDomain: ServiceDomain {
    case api

    var identifier: String { "test-api" }
}

struct NevodTests {
    private func makeProvider(
        _ handler: @escaping (URLRequest) async throws -> (Data, URLResponse),
        interceptor: (any RequestInterceptor)? = nil,
        rateLimiter: (any RateLimiting)? = nil
    ) -> NetworkProvider {
        let session = MockSession(handler: handler)
        let networkConfig = NetworkConfig(
            environments: [
                TestDomain.api: SimpleEnvironment(
                    baseURL: URL(string: "https://example.com")!
                )
            ],
            timeout: 1
        )
        return NetworkProvider(config: networkConfig, session: session, interceptor: interceptor, rateLimiter: rateLimiter)
    }

    private struct TestRoute: Route {
        typealias Response = TestModel
        typealias Domain = TestDomain

        let domain = TestDomain.api
        let endpoint: String = "/test"
        let method: HTTPMethod = .get
        let parameters: [String: String]? = nil
    }

    private struct TestModel: Codable, Equatable {
        let id: Int
    }

    private actor MockRateLimiter: RateLimiting {
        private(set) var callCount = 0

        func acquirePermit() async {
            callCount += 1
        }

        func invocations() async -> Int { callCount }
    }

    @Test func successfulRequest() async {
        let expected = TestModel(id: 1)
        let provider = makeProvider { request in
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute())
        switch result {
        case .success(let model):
            #expect(model == expected)
        default:
            #expect(Bool(false))
        }
    }

    @Test func parsingError() async {
        let provider = makeProvider { request in
            let data = Data("invalid".utf8)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute())
        switch result {
        case .failure(let error):
            if case .parsingError = error {
                #expect(Bool(true))
            } else {
                #expect(Bool(false))
            }
        default:
            #expect(Bool(false))
        }
    }

    @Test func timeoutError() async {
        let provider = makeProvider { _ in
            throw URLError(.timedOut)
        }
        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute())
        switch result {
        case .failure(let error):
            if case .timeout = error {
                #expect(Bool(true))
            } else {
                #expect(Bool(false))
            }
        default:
            #expect(Bool(false))
        }
    }

    @Test func tokenRefreshAndRetry() async {
        let mockStorage = MockStorage()
        let storage = TokenStorage<Token>(storage: mockStorage)
        await storage.save(Token(value: "expired"))

        var callCount = 0
        let authInterceptor = AuthenticationInterceptor(
            tokenStorage: storage,
            refreshStrategy: { _ in
                return Token(value: "refreshed")
            }
        )

        let provider = makeProvider({ request in
            callCount += 1
            let auth = request.value(forHTTPHeaderField: "Authorization")
            if callCount == 1 {
                #expect(auth == "Bearer expired")
                let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            } else {
                #expect(auth == "Bearer refreshed")
                let data = try JSONEncoder().encode(TestModel(id: 1))
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (data, response)
            }
        }, interceptor: authInterceptor)

        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute())
        #expect(callCount == 2)
        let token = await storage.load()
        #expect(token?.value == "refreshed")
        switch result {
        case .success(let model):
            #expect(model == TestModel(id: 1))
        default:
            #expect(Bool(false))
        }
    }

    @Test func retryOnTimeout() async {
        var callCount = 0
        let expected = TestModel(id: 7)
        let provider = makeProvider { request in
            callCount += 1
            if callCount < 3 {
                throw URLError(.timedOut)
            } else {
                let data = try JSONEncoder().encode(expected)
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (data, response)
            }
        }
        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute())
        #expect(callCount == 3)
        switch result {
        case .success(let model):
            #expect(model == expected)
        default:
            #expect(Bool(false))
        }
    }

    @Test func noInterceptorWhenNotProvided() async {
        let provider = makeProvider { request in
            let auth = request.value(forHTTPHeaderField: "Authorization")
            #expect(auth == nil)
            let data = try JSONEncoder().encode(TestModel(id: 3))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute())
        switch result {
        case .success(let model):
            #expect(model == TestModel(id: 3))
        default:
            #expect(Bool(false))
        }
    }

    @Test func headersInterceptor() async {
        let headersInterceptor = HeadersInterceptor(headers: [
            "User-Agent": "TestApp/1.0",
            "X-Custom-Header": "CustomValue"
        ])

        let provider = makeProvider({ request in
            #expect(request.value(forHTTPHeaderField: "User-Agent") == "TestApp/1.0")
            #expect(request.value(forHTTPHeaderField: "X-Custom-Header") == "CustomValue")
            let data = try JSONEncoder().encode(TestModel(id: 5))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }, interceptor: headersInterceptor)

        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute())
        switch result {
        case .success(let model):
            #expect(model == TestModel(id: 5))
        default:
            #expect(Bool(false))
        }
    }

    @Test func interceptorChain() async {
        let mockStorage = MockStorage()
        let storage = TokenStorage<Token>(storage: mockStorage)
        await storage.save(Token(value: "mytoken"))

        let chain = InterceptorChain([
            HeadersInterceptor(headers: ["User-Agent": "TestApp/1.0"]),
            AuthenticationInterceptor(
                tokenStorage: storage,
                refreshStrategy: { _ in Token(value: "newtoken") }
            )
        ])

        let provider = makeProvider({ request in
            #expect(request.value(forHTTPHeaderField: "User-Agent") == "TestApp/1.0")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer mytoken")
            let data = try JSONEncoder().encode(TestModel(id: 9))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }, interceptor: chain)

        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute())
        switch result {
        case .success(let model):
            #expect(model == TestModel(id: 9))
        default:
            #expect(Bool(false))
        }
    }

    @Test func forwardsDelegateToSession() async {
        let expected = TestModel(id: 11)
        let session = MockSession { request in
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }

        let config = NetworkConfig(
            environments: [
                TestDomain.api: SimpleEnvironment(
                    baseURL: URL(string: "https://example.com")!
                )
            ],
            timeout: 1
        )

        let provider = NetworkProvider(config: config, session: session)
        let delegate = MockDelegate()

        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute(), delegate: delegate)

        #expect(session.lastDelegate === delegate)

        switch result {
        case .success(let model):
            #expect(model == expected)
        default:
            #expect(Bool(false))
        }
    }

    // MARK: - Convenience Routes Tests

    @Test func simpleGetRoute() async {
        let expected = TestModel(id: 42)
        let provider = makeProvider { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path.contains("/test") == true)
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }

        let route = SimpleGetRoute<TestModel, TestDomain>(endpoint: "/test", domain: .api)
        let result: Result<TestModel, NetworkError> = await provider.request(route)

        switch result {
        case .success(let model):
            #expect(model == expected)
        case .failure:
            #expect(Bool(false))
        }
    }

    @Test func simplePostRouteWithParameters() async {
        let expected = TestModel(id: 43)
        let provider = makeProvider { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path.contains("/create") == true)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            // Check body contains parameters
            if let body = request.httpBody,
               let json = try? JSONSerialization.jsonObject(with: body) as? [String: String] {
                #expect(json["name"] == "John")
                #expect(json["email"] == "john@test.com")
            } else {
                #expect(Bool(false), "Body should contain parameters")
            }

            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }

        let route = SimplePostRoute<TestModel, TestDomain>(
            endpoint: "/create",
            domain: .api,
            bodyParameters: ["name": "John", "email": "john@test.com"]
        )
        let result: Result<TestModel, NetworkError> = await provider.request(route)

        switch result {
        case .success(let model):
            #expect(model == expected)
        case .failure:
            #expect(Bool(false))
        }
    }

    @Test func routeGetConvenience() async {
        let expected = TestModel(id: 44)
        let provider = makeProvider { request in
            #expect(request.httpMethod == "GET")
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }

        let route = SimpleGetRoute<TestModel, TestDomain>(endpoint: "/users/me", domain: .api)
        let result: Result<TestModel, NetworkError> = await provider.request(route)

        switch result {
        case .success(let model):
            #expect(model == expected)
        case .failure:
            #expect(Bool(false))
        }
    }

    @Test func performMethodThrowsOnError() async {
        let provider = makeProvider { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }

        do {
            _ = try await provider.perform(TestRoute())
            #expect(Bool(false), "Should throw")
        } catch let error as NetworkError {
            if case .clientError(let code, _, _) = error {
                #expect(code == 404)
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }

    @Test func performMethodReturnsSuccessValue() async {
        let expected = TestModel(id: 45)
        let provider = makeProvider { request in
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }

        do {
            let model = try await provider.perform(TestRoute())
            #expect(model == expected)
        } catch {
            #expect(Bool(false), "Should not throw")
        }
    }

    @Test func rejectsDirectoryTraversalEndpoints() async {
        struct UnsafeRoute: Route {
            typealias Response = TestModel
            typealias Domain = TestDomain

            let domain: TestDomain = .api
            let endpoint: String = "../secret"
            let method: HTTPMethod = .get
            let parameters: [String: String]? = nil
        }

        let provider = makeProvider({ _ in
            #expect(Bool(false), "Request should not reach session for invalid endpoints")
            return (Data(), URLResponse())
        })

        let result: Result<TestModel, NetworkError> = await provider.request(UnsafeRoute())
        switch result {
        case .failure(let error):
            if case .invalidURL = error {
                #expect(Bool(true))
            } else {
                #expect(Bool(false), "Unexpected error")
            }
        default:
            #expect(Bool(false), "Should fail for invalid endpoint")
        }
    }

    @Test func cookieTokenRestoresHttpOnlyFlag() throws {
        let properties: [HTTPCookiePropertyKey: Any] = [
            .name: "session",
            .value: "abc",
            .domain: "example.com",
            .path: "/",
            .secure: true,
            HTTPCookiePropertyKey(rawValue: "HttpOnly"): true
        ]

        let cookie = try #require(HTTPCookie(properties: properties))
        let token = CookieToken(sessionCookies: [cookie])
        let data = try token.encode()
        let decoded = try CookieToken.decode(from: data)
        #expect(decoded.sessionCookies.first?.isHTTPOnly == true)
        #expect(decoded.sessionCookies.first?.isSecure == true)
    }

    @Test func rateLimiterIsInvokedPerRequest() async {
        let limiter = MockRateLimiter()
        let expected = TestModel(id: 46)
        let provider = makeProvider({ request in
            let data = try JSONEncoder().encode(expected)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }, rateLimiter: limiter)

        let result: Result<TestModel, NetworkError> = await provider.request(TestRoute())
        let invocations = await limiter.invocations()
        #expect(invocations == 1)

        switch result {
        case .success(let model):
            #expect(model == expected)
        default:
            #expect(Bool(false))
        }
    }
}
