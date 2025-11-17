import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
public typealias URLSessionType = FoundationNetworking.URLSession
#else
public typealias URLSessionType = Foundation.URLSession
#endif

public protocol URLSessionProtocol: Sendable {
    func requestData(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate?
    ) async throws -> (Data, URLResponse)
}

public extension URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await requestData(for: request, delegate: nil)
    }
}

extension URLSessionType: URLSessionProtocol {
    public func requestData(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate?
    ) async throws -> (Data, URLResponse) {
        #if canImport(FoundationNetworking)
        if let delegate = delegate {
            return try await withCheckedThrowingContinuation { continuation in
                let session = makeDelegateSessionPreservingConfiguration(delegate: delegate)
                let task = session.dataTask(with: request) { data, response, error in
                    session.finishTasksAndInvalidate()
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                task.resume()
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            task.resume()
        }
        #else
        return try await self.data(for: request, delegate: delegate)
        #endif
    }
}

#if canImport(FoundationNetworking)
private extension URLSessionType {
    func makeDelegateSessionPreservingConfiguration(delegate: URLSessionTaskDelegate) -> URLSession {
        var configuration = self.configuration
        configuration.httpCookieStorage = self.configuration.httpCookieStorage
        configuration.urlCache = self.configuration.urlCache
        configuration.urlCredentialStorage = self.configuration.urlCredentialStorage
        configuration.protocolClasses = self.configuration.protocolClasses
        configuration.requestCachePolicy = self.configuration.requestCachePolicy
        configuration.timeoutIntervalForRequest = self.configuration.timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = self.configuration.timeoutIntervalForResource
        configuration.networkServiceType = self.configuration.networkServiceType
        configuration.allowsCellularAccess = self.configuration.allowsCellularAccess
        if #available(macOS 12.0, *) {
            configuration.allowsExpensiveNetworkAccess = self.configuration.allowsExpensiveNetworkAccess
            configuration.allowsConstrainedNetworkAccess = self.configuration.allowsConstrainedNetworkAccess
            configuration.multipathServiceType = self.configuration.multipathServiceType
        }
        return URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: self.delegateQueue
        )
    }
}
#endif
