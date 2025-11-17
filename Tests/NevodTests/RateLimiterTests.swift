import Foundation
import Dispatch
import Testing
@testable import Nevod

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var nowValue: UInt64
    private(set) var sleepDurations: [UInt64] = []

    init(now: UInt64 = 0) {
        self.nowValue = now
    }

    func now() -> DispatchTime {
        lock.lock()
        defer { lock.unlock() }
        return DispatchTime(uptimeNanoseconds: nowValue)
    }

    func advance(by nanoseconds: UInt64) {
        lock.lock()
        nowValue &+= nanoseconds
        lock.unlock()
    }

    func jumpBackward(by nanoseconds: UInt64) {
        lock.lock()
        nowValue = nowValue >= nanoseconds ? nowValue - nanoseconds : 0
        lock.unlock()
    }

    func sleep(for nanoseconds: UInt64) {
        lock.lock()
        sleepDurations.append(nanoseconds)
        nowValue &+= nanoseconds
        lock.unlock()
    }
}

private extension RateLimiter {
    static func withTestClock(_ configuration: RateLimitConfiguration, clock: TestClock) -> RateLimiter {
        RateLimiter(
            configuration: configuration,
            clock: RateLimiterClock(
                now: { clock.now() },
                sleep: { nanoseconds in
                    clock.sleep(for: nanoseconds)
                }
            )
        )
    }
}

struct RateLimiterTests {
    @Test func configurationClampsValues() {
        let config = RateLimitConfiguration(requests: 0, perInterval: 0)
        #expect(config.requests == 1)
        #expect(config.perInterval == 0.001)
    }

    @Test func acquirePermitDelaysWhenLimitExceeded() async throws {
        let clock = TestClock()
        let limiter = RateLimiter.withTestClock(
            RateLimitConfiguration(requests: 1, perInterval: 0.05),
            clock: clock
        )

        try await limiter.acquirePermit()
        try await limiter.acquirePermit()
        #expect(clock.sleepDurations.count == 1)
        #expect(clock.sleepDurations.last! >= 50_000_000)
    }

    @Test func permitsResumeAfterIntervalPasses() async throws {
        let clock = TestClock()
        let limiter = RateLimiter.withTestClock(
            RateLimitConfiguration(requests: 1, perInterval: 0.03),
            clock: clock
        )

        try await limiter.acquirePermit()
        clock.advance(by: 60_000_000) // 60ms, longer than interval

        try await limiter.acquirePermit()
        #expect(clock.sleepDurations.isEmpty)
    }

    @Test func handlesBackwardWallClockJumpsGracefully() async throws {
        let clock = TestClock(now: 100_000_000)
        let limiter = RateLimiter.withTestClock(
            RateLimitConfiguration(requests: 1, perInterval: 0.05),
            clock: clock
        )

        try await limiter.acquirePermit()
        clock.jumpBackward(by: 40_000_000) // Simulate wall-clock adjustment backwards

        try await limiter.acquirePermit()
        #expect(clock.sleepDurations.last ?? 0 >= 50_000_000)
    }
}
