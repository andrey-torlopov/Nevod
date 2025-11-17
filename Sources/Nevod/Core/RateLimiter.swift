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

/// Clock abstraction used by RateLimiter to allow deterministic testing while relying on monotonic time.
struct RateLimiterClock {
    let now: @Sendable () -> DispatchTime
    let sleep: @Sendable (_ nanoseconds: UInt64) async throws -> Void

    static let live = RateLimiterClock(
        now: { DispatchTime.now() },
        sleep: { try await Task.sleep(nanoseconds: $0) }
    )
}

/// Simple sliding-window based rate limiter that enforces the configuration limits.
public actor RateLimiter: RateLimiting {
    private let configuration: RateLimitConfiguration
    private let clock: RateLimiterClock
    private let intervalNanoseconds: UInt64
    private var timestamps: [DispatchTime] = []
    private var headIndex: Int = 0

    public init(configuration: RateLimitConfiguration) {
        self.configuration = configuration
        self.clock = .live
        self.intervalNanoseconds = max(
            1,
            UInt64(configuration.perInterval * 1_000_000_000.0)
        )
    }

    init(configuration: RateLimitConfiguration, clock: RateLimiterClock) {
        self.configuration = configuration
        self.clock = clock
        self.intervalNanoseconds = max(
            1,
            UInt64(configuration.perInterval * 1_000_000_000.0)
        )
    }

    public func acquirePermit() async throws {
        while true {
            try Task.checkCancellation()
            let now = clock.now()
            cleanupExpiredTimestamps(now)

            if activeCount < configuration.requests {
                timestamps.append(now)
                return
            }

            guard headIndex < timestamps.count else {
                continue
            }

            let earliest = timestamps[headIndex]
            let elapsed = elapsedNanoseconds(since: earliest, now: now)

            if elapsed >= intervalNanoseconds {
                headIndex += 1
                compactIfNeeded()
                continue
            }

            let waitTime = intervalNanoseconds - elapsed
            do {
                try await clock.sleep(waitTime)
            } catch {
                throw error
            }
        }
    }

    private var activeCount: Int {
        timestamps.count - headIndex
    }

    private func cleanupExpiredTimestamps(_ now: DispatchTime) {
        while headIndex < timestamps.count,
              elapsedNanoseconds(since: timestamps[headIndex], now: now) >= intervalNanoseconds {
            headIndex += 1
        }
        compactIfNeeded()
    }

    private func compactIfNeeded() {
        guard headIndex > 0, headIndex * 2 >= timestamps.count else { return }
        timestamps.removeFirst(headIndex)
        headIndex = 0
    }

    private func elapsedNanoseconds(since instant: DispatchTime, now: DispatchTime) -> UInt64 {
        let nowValue = now.uptimeNanoseconds
        let thenValue = instant.uptimeNanoseconds
        return nowValue >= thenValue ? nowValue - thenValue : 0
    }
}
