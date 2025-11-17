import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Nevod

private struct PageItem: Codable, Equatable, Sendable {
    let id: Int
}

private enum PaginatorTestDomain: ServiceDomain {
    case api
    var identifier: String { "paginator-api" }
}

private final class PaginatorMockSession: URLSessionProtocol, @unchecked Sendable {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    func requestData(
        for request: URLRequest,
        delegate: URLSessionTaskDelegate?
    ) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

private actor QueryCollector {
    private var values: [[String: String]] = []

    func append(_ value: [String: String]) {
        values.append(value)
    }

    func all() -> [[String: String]] { values }
}

private func makeProvider(
    handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
) -> NetworkProvider {
    let session = PaginatorMockSession(handler: handler)
    let config = NetworkConfig(
        environments: [
            PaginatorTestDomain.api: SimpleEnvironment(
                baseURL: URL(string: "https://example.com")!
            )
        ],
        timeout: 1
    )
    return NetworkProvider(config: config, session: session, logger: nil)
}

private func queryParameters(from request: URLRequest) -> [String: String] {
    guard let url = request.url,
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return [:]
    }

    var parameters: [String: String] = [:]
    components.queryItems?.forEach { item in
        parameters[item.name] = item.value
    }
    return parameters
}

struct PaginatorTests {
    @Test func pageNumberPaginatorLoadsSequentialPages() async throws {
        let queryCollector = QueryCollector()
        let totalItems = 4

        let provider = makeProvider { request in
            let params = queryParameters(from: request)
            await queryCollector.append(params)

            let page = Int(params["page"] ?? "1") ?? 1
            let limit = Int(params["limit"] ?? "2") ?? 2
            let start = (page - 1) * limit + 1
            let end = min(start + limit - 1, totalItems)
            let items: [PageItem]
            if start <= end {
                items = (start...end).map(PageItem.init)
            } else {
                items = []
            }
            let hasMore = end < totalItems
            let response = StandardPageResponse(items: items, hasMore: hasMore, total: totalItems)
            let data = try JSONEncoder().encode(response)
            let url = request.url ?? URL(string: "https://example.com")!
            let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, httpResponse)
        }

        let paginator = Paginator<PageItem, StandardPageResponse<PageItem>, PaginatorTestDomain>.standard(
            provider: provider,
            endpoint: "/items",
            domain: .api,
            style: .pageNumber(pageSize: 2)
        )

        let firstPage = try await paginator.loadNext()
        #expect(firstPage.map(\.id) == [1, 2])
        #expect(await paginator.allItems.count == 2)
        #expect(await paginator.totalCount == totalItems)

        let secondPage = try await paginator.loadNext()
        #expect(secondPage.map(\.id) == [3, 4])
        #expect(await paginator.hasMore == false)

        // Third request should not hit the network because hasMore is false
        let thirdPage = try await paginator.loadNext()
        #expect(thirdPage.isEmpty)

        let recordedQueries = await queryCollector.all()
        #expect(recordedQueries.count == 2)
        #expect(recordedQueries.first?["page"] == "1")
        #expect(recordedQueries.first?["limit"] == "2")
        #expect(recordedQueries.last?["page"] == "2")
    }

    @Test func cursorPaginatorUsesNextCursorParameter() async throws {
        let queryCollector = QueryCollector()
        var responses = [
            CursorPageResponse(items: [PageItem(id: 1)], nextCursor: "abc", hasMore: true, total: nil),
            CursorPageResponse(items: [PageItem(id: 2)], nextCursor: nil, hasMore: false, total: nil)
        ]

        let provider = makeProvider { request in
            let params = queryParameters(from: request)
            await queryCollector.append(params)

            guard !responses.isEmpty else {
                #expect(Bool(false), "No more responses available")
                return (Data(), URLResponse())
            }

            let response = responses.removeFirst()
            let data = try JSONEncoder().encode(response)
            let url = request.url ?? URL(string: "https://example.com")!
            let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, httpResponse)
        }

        let paginator = Paginator<PageItem, CursorPageResponse<PageItem>, PaginatorTestDomain>.cursor(
            provider: provider,
            endpoint: "/items",
            domain: .api,
            cursorKey: "cursor",
            limitKey: "limit",
            pageSize: 1
        )

        let firstPage = try await paginator.loadNext()
        #expect(firstPage.map(\.id) == [1])
        #expect(await paginator.hasMore == true)

        let secondPage = try await paginator.loadNext()
        #expect(secondPage.map(\.id) == [2])
        #expect(await paginator.hasMore == false)

        let recordedQueries = await queryCollector.all()
        #expect(recordedQueries.count == 2)
        #expect(recordedQueries[0]["cursor"] == nil)
        #expect(recordedQueries[0]["limit"] == "1")
        #expect(recordedQueries[1]["cursor"] == "abc")
        #expect(recordedQueries[1]["limit"] == "1")
    }

    @Test func resetRestoresInitialPaginationState() async throws {
        let queryCollector = QueryCollector()
        let totalItems = 3

        let provider = makeProvider { request in
            let params = queryParameters(from: request)
            await queryCollector.append(params)

            let page = Int(params["page"] ?? "1") ?? 1
            let limit = Int(params["limit"] ?? "1") ?? 1
            let start = (page - 1) * limit + 1
            let end = min(start + limit - 1, totalItems)
            let items: [PageItem]
            if start <= end {
                items = (start...end).map(PageItem.init)
            } else {
                items = []
            }
            let hasMore = end < totalItems
            let response = StandardPageResponse(items: items, hasMore: hasMore, total: totalItems)
            let data = try JSONEncoder().encode(response)
            let url = request.url ?? URL(string: "https://example.com")!
            let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, httpResponse)
        }

        let paginator = Paginator<PageItem, StandardPageResponse<PageItem>, PaginatorTestDomain>.standard(
            provider: provider,
            endpoint: "/items",
            domain: .api,
            style: .pageNumber(pageSize: 1)
        )

        _ = try await paginator.loadNext()
        _ = try await paginator.loadNext()
        #expect(await paginator.hasMore == true)
        #expect(await paginator.allItems.count == 2)

        await paginator.reset()
        #expect(await paginator.hasMore == true)
        #expect(await paginator.allItems.isEmpty)

        let pageAfterReset = try await paginator.loadNext()
        #expect(pageAfterReset.map(\.id) == [1])

        let recordedQueries = await queryCollector.all()
        #expect(recordedQueries[0]["page"] == "1")
        #expect(recordedQueries[1]["page"] == "2")
        #expect(recordedQueries[2]["page"] == "1")
    }
}
