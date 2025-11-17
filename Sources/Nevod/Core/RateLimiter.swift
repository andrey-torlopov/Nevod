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
    func acquirePermit() async
}

/// Simple sliding-window based rate limiter that enforces the configuration limits.
public actor RateLimiter: RateLimiting {
    private let configuration: RateLimitConfiguration
    private var timestamps: [Date] = []

    public init(configuration: RateLimitConfiguration) {
        self.configuration = configuration
    }

    public func acquirePermit() async {
        while true {
            let now = Date()
            cleanupExpiredTimestamps(now)

            if timestamps.count < configuration.requests {
                timestamps.append(now)
                return
            }

            guard let earliest = timestamps.first else {
                continue
            }

            let elapsed = now.timeIntervalSince(earliest)
            let waitTime = max(0, configuration.perInterval - elapsed)
            if waitTime > 0 {
                let nanoseconds = UInt64(waitTime * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            } else {
                timestamps.removeFirst()
            }
        }
    }

    private func cleanupExpiredTimestamps(_ now: Date) {
        timestamps = timestamps.filter { now.timeIntervalSince($0) < configuration.perInterval }
    }
}
