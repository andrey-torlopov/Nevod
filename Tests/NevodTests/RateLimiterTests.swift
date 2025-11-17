import Foundation
import Testing
@testable import Nevod

struct RateLimiterTests {
    @Test func configurationClampsValues() {
        let config = RateLimitConfiguration(requests: 0, perInterval: 0)
        #expect(config.requests == 1)
        #expect(config.perInterval == 0.001)
    }

    @Test func acquirePermitDelaysWhenLimitExceeded() async throws {
        let limiter = RateLimiter(configuration: RateLimitConfiguration(requests: 1, perInterval: 0.05))

        try await limiter.acquirePermit()
        let waitStart = Date()
        try await limiter.acquirePermit()
        let elapsed = Date().timeIntervalSince(waitStart)
        #expect(elapsed >= 0.04)
    }

    @Test func permitsResumeAfterIntervalPasses() async throws {
        let limiter = RateLimiter(configuration: RateLimitConfiguration(requests: 1, perInterval: 0.03))

        try await limiter.acquirePermit()
        try await Task.sleep(nanoseconds: 60_000_000) // 60ms, longer than interval

        let waitStart = Date()
        try await limiter.acquirePermit()
        let elapsed = Date().timeIntervalSince(waitStart)
        #expect(elapsed < 0.02)
    }
}
