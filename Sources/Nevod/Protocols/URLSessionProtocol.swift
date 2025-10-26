import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
public typealias URLSessionType = FoundationNetworking.URLSession
#else
public typealias URLSessionType = Foundation.URLSession
#endif

public protocol URLSessionProtocol {
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
