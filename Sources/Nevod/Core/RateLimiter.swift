import Foundation

/// Configuration that limits the number of requests that can be executed during the specified interval.
public struct RateLimitConfiguration: Sendable {
    public let requests: Int
    public let perInterval: TimeInterval

    public init(requests: Int, perInterval: TimeInterval) {
        self.requests = max(1, requests)
        self.perInterval = max(0.001, perInterval)
    }
}

/// Protocol that allows plugging custom rate-limiting strategies into the provider.
public protocol RateLimiting: Sendable {
    func acquirePermit() async throws
}

/// Simple sliding-window based rate limiter that enforces the configuration limits.
public actor RateLimiter: RateLimiting {
    private let configuration: RateLimitConfiguration
    private var timestamps: [Date] = []
    private var headIndex: Int = 0

    public init(configuration: RateLimitConfiguration) {
        self.configuration = configuration
    }

    public func acquirePermit() async throws {
        while true {
            try Task.checkCancellation()
            let now = Date()
            cleanupExpiredTimestamps(now)

            if activeCount < configuration.requests {
                timestamps.append(now)
                return
            }

            guard headIndex < timestamps.count else {
                continue
            }

            let earliest = timestamps[headIndex]
            let elapsed = now.timeIntervalSince(earliest)
            let waitTime = configuration.perInterval - elapsed

            if waitTime > 0 {
                let nanoseconds = UInt64(waitTime * 1_000_000_000)
                do {
                    try await Task.sleep(nanoseconds: nanoseconds)
                } catch {
                    throw error
                }
            } else {
                headIndex += 1
                compactIfNeeded()
            }
        }
    }

    private var activeCount: Int {
        timestamps.count - headIndex
    }

    private func cleanupExpiredTimestamps(_ now: Date) {
        while headIndex < timestamps.count,
              now.timeIntervalSince(timestamps[headIndex]) >= configuration.perInterval {
            headIndex += 1
        }
        compactIfNeeded()
    }

    private func compactIfNeeded() {
        guard headIndex > 0, headIndex * 2 >= timestamps.count else { return }
        timestamps.removeFirst(headIndex)
        headIndex = 0
    }
}
