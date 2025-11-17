import Foundation

/// A helper for handling paginated API responses
///
/// Example:
/// ```swift
/// struct Page<T: Decodable>: Decodable {
///     let items: [T]
///     let hasMore: Bool
///     let nextCursor: String?
/// }
///
/// let paginator = Paginator<User, Page<User>, MyDomain>(
///     provider: networkProvider,
///     endpoint: "/users",
///     domain: .api,
///     style: .pageNumber(pageSize: 20)
/// )
///
/// // Load first page
/// let users = try await paginator.loadNext()
///
/// // Load more pages
/// while paginator.hasMore {
///     let moreUsers = try await paginator.loadNext()
///     // Process moreUsers
/// }
///
/// // Or reset and start over
/// paginator.reset()
/// ```
public actor Paginator<Item: Decodable & Sendable, PageResponse: Decodable & Sendable, Domain: ServiceDomain> {
    /// Pagination style
    public enum Style: Sendable {
        /// Offset-based pagination: ?offset=20&limit=20
        case offset(pageSize: Int)

        /// Page number pagination: ?page=2&limit=20
        case pageNumber(pageSize: Int)

        /// Cursor-based pagination: ?cursor=abc123&limit=20
        case cursor(cursorKey: String, limitKey: String?, pageSize: Int?)
    }

    /// Response parser to extract items and pagination info from the response
    public struct ResponseParser: Sendable {
        /// Extracts items from the response
        let extractItems: @Sendable (PageResponse) -> [Item]

        /// Checks if there are more items to load
        let hasMore: @Sendable (PageResponse) -> Bool

        /// Extracts the next cursor (for cursor-based pagination)
        let nextCursor: (@Sendable (PageResponse) -> String?)?

        /// Extracts total count (optional)
        let totalCount: (@Sendable (PageResponse) -> Int?)?

        /// Creates a response parser
        /// - Parameters:
        ///   - extractItems: Closure to extract items from response
        ///   - hasMore: Closure to check if there are more items
        ///   - nextCursor: Optional closure to extract next cursor
        ///   - totalCount: Optional closure to extract total count
        public init(
            extractItems: @escaping @Sendable (PageResponse) -> [Item],
            hasMore: @escaping @Sendable (PageResponse) -> Bool,
            nextCursor: (@Sendable (PageResponse) -> String?)? = nil,
            totalCount: (@Sendable (PageResponse) -> Int?)? = nil
        ) {
            self.extractItems = extractItems
            self.hasMore = hasMore
            self.nextCursor = nextCursor
            self.totalCount = totalCount
        }
    }

    private let provider: NetworkProvider
    private let endpoint: String
    private let domain: Domain
    private let style: Style
    private let parser: ResponseParser
    private let additionalQuery: [String: String]

    // State
    private var currentOffset = 0
    private var currentPage = 1
    private var currentCursor: String?
    private var _hasMore = true
    private var _totalCount: Int?
    private var loadedItems: [Item] = []

    /// Whether there are more items to load
    public var hasMore: Bool { _hasMore }

    /// Total count of items (if available from API)
    public var totalCount: Int? { _totalCount }

    /// All items loaded so far
    public var allItems: [Item] { loadedItems }

    /// Creates a paginator
    /// - Parameters:
    ///   - provider: The network provider
    ///   - endpoint: The endpoint path
    ///   - domain: The service domain
    ///   - style: The pagination style
    ///   - parser: The response parser
    ///   - additionalQuery: Additional query parameters to include in all requests
    public init(
        provider: NetworkProvider,
        endpoint: String,
        domain: Domain,
        style: Style = .pageNumber(pageSize: 20),
        parser: ResponseParser,
        additionalQuery: [String: String] = [:]
    ) {
        self.provider = provider
        self.endpoint = endpoint
        self.domain = domain
        self.style = style
        self.parser = parser
        self.additionalQuery = additionalQuery
    }

    /// Loads the next page of items
    /// - Returns: The items from the next page
    /// - Throws: NetworkError if the request fails
    public func loadNext() async throws -> [Item] {
        guard _hasMore else { return [] }

        let query = buildQueryParams()
        let route = SimpleGetRoute<PageResponse, Domain>(
            endpoint: endpoint,
            domain: domain,
            queryParameters: query
        )

        let response = try await provider.perform(route)

        let items = parser.extractItems(response)
        _hasMore = parser.hasMore(response)

        if let totalCount = parser.totalCount?(response) {
            _totalCount = totalCount
        }

        if let nextCursor = parser.nextCursor?(response) {
            currentCursor = nextCursor
        }

        updateState(itemsCount: items.count)
        loadedItems.append(contentsOf: items)

        return items
    }

    /// Loads all remaining items
    /// - Returns: All remaining items
    /// - Throws: NetworkError if any request fails
    public func loadAll() async throws -> [Item] {
        var allItems: [Item] = []

        while _hasMore {
            let items = try await loadNext()
            allItems.append(contentsOf: items)
        }

        return allItems
    }

    /// Resets the paginator to the initial state
    public func reset() {
        currentOffset = 0
        currentPage = 1
        currentCursor = nil
        _hasMore = true
        _totalCount = nil
        loadedItems.removeAll()
    }

    // MARK: - Private

    private func buildQueryParams() -> [String: String] {
        var params = additionalQuery

        switch style {
        case .offset(let pageSize):
            params["offset"] = "\(currentOffset)"
            params["limit"] = "\(pageSize)"

        case .pageNumber(let pageSize):
            params["page"] = "\(currentPage)"
            params["limit"] = "\(pageSize)"

        case .cursor(let cursorKey, let limitKey, let pageSize):
            if let cursor = currentCursor {
                params[cursorKey] = cursor
            }
            if let limitKey = limitKey, let pageSize = pageSize {
                params[limitKey] = "\(pageSize)"
            }
        }

        return params
    }

    private func updateState(itemsCount: Int) {
        switch style {
        case .offset(let pageSize):
            currentOffset += pageSize

        case .pageNumber:
            currentPage += 1

        case .cursor:
            // Cursor is updated from response
            break
        }
    }
}

// MARK: - Convenience Factory Methods

public extension Paginator where PageResponse == [Item] {
    /// Creates a paginator for simple array responses
    /// - Parameters:
    ///   - provider: The network provider
    ///   - endpoint: The endpoint path
    ///   - domain: The service domain
    ///   - style: The pagination style
    ///   - pageSize: Items per page (used to determine if there are more items)
    ///   - additionalQuery: Additional query parameters
    static func simple(
        provider: NetworkProvider,
        endpoint: String,
        domain: Domain,
        style: Style = .pageNumber(pageSize: 20),
        pageSize: Int = 20,
        additionalQuery: [String: String] = [:]
    ) -> Paginator {
        let parser = ResponseParser(
            extractItems: { $0 },
            hasMore: { $0.count >= pageSize }
        )

        return Paginator(
            provider: provider,
            endpoint: endpoint,
            domain: domain,
            style: style,
            parser: parser,
            additionalQuery: additionalQuery
        )
    }
}

// MARK: - Standard Page Response Models

/// Standard page response with items and hasMore flag
public struct StandardPageResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    public let items: [Item]
    public let hasMore: Bool
    public let total: Int?

    enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
        case total
    }
}

/// Cursor-based page response
public struct CursorPageResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    public let items: [Item]
    public let nextCursor: String?
    public let hasMore: Bool
    public let total: Int?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
        case total
    }
}

// MARK: - Standard Parsers

public extension Paginator where PageResponse == StandardPageResponse<Item> {
    /// Creates a paginator with a standard page response parser
    static func standard(
        provider: NetworkProvider,
        endpoint: String,
        domain: Domain,
        style: Style = .pageNumber(pageSize: 20),
        additionalQuery: [String: String] = [:]
    ) -> Paginator {
        let parser = ResponseParser(
            extractItems: { $0.items },
            hasMore: { $0.hasMore },
            totalCount: { $0.total }
        )

        return Paginator(
            provider: provider,
            endpoint: endpoint,
            domain: domain,
            style: style,
            parser: parser,
            additionalQuery: additionalQuery
        )
    }
}

public extension Paginator where PageResponse == CursorPageResponse<Item> {
    /// Creates a paginator with a cursor-based page response parser
    static func cursor(
        provider: NetworkProvider,
        endpoint: String,
        domain: Domain,
        cursorKey: String = "cursor",
        limitKey: String? = "limit",
        pageSize: Int? = 20,
        additionalQuery: [String: String] = [:]
    ) -> Paginator {
        let parser = ResponseParser(
            extractItems: { $0.items },
            hasMore: { $0.hasMore },
            nextCursor: { $0.nextCursor },
            totalCount: { $0.total }
        )

        return Paginator(
            provider: provider,
            endpoint: endpoint,
            domain: domain,
            style: .cursor(cursorKey: cursorKey, limitKey: limitKey, pageSize: pageSize),
            parser: parser,
            additionalQuery: additionalQuery
        )
    }
}
