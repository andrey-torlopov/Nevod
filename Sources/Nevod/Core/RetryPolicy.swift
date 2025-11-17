import Foundation

/// Defines the retry policy for failed requests
public struct RetryPolicy: Sendable {
    /// Maximum number of retry attempts
    public let maxAttempts: Int

    /// Base delay in seconds before the first retry
    public let baseDelay: TimeInterval

    /// Maximum delay in seconds (to prevent indefinite backoff)
    public let maxDelay: TimeInterval

    /// Multiplier for exponential backoff
    public let multiplier: Double

    /// Whether to add random jitter to prevent thundering herd
    public let jitter: Bool

    /// Creates a retry policy
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - baseDelay: Base delay in seconds before the first retry (default: 1.0)
    ///   - maxDelay: Maximum delay in seconds (default: 60.0)
    ///   - multiplier: Multiplier for exponential backoff (default: 2.0)
    ///   - jitter: Whether to add random jitter (default: true)
    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 60.0,
        multiplier: Double = 2.0,
        jitter: Bool = true
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(baseDelay, maxDelay)
        self.multiplier = max(1.0, multiplier)
        self.jitter = jitter
    }

    /// Calculates the delay for a specific retry attempt
    /// - Parameter attempt: The retry attempt number (0-indexed)
    /// - Returns: The delay in seconds before the retry
    public func delay(for attempt: Int) -> TimeInterval {
        guard attempt >= 0 else { return 0 }

        // Calculate exponential delay: baseDelay * (multiplier ^ attempt)
        let exponentialDelay = baseDelay * pow(multiplier, Double(attempt))

        // Cap at maxDelay
        let cappedDelay = min(exponentialDelay, maxDelay)

        // Add jitter if enabled
        guard jitter else { return cappedDelay }

        // Jitter range: 50% to 150% of the calculated delay
        let jitterRange = 0.5...1.5
        let randomFactor = Double.random(in: jitterRange)

        return cappedDelay * randomFactor
    }

    /// Default retry policy with reasonable defaults
    public static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 60.0,
        multiplier: 2.0,
        jitter: true
    )

    /// Aggressive retry policy for critical requests
    public static let aggressive = RetryPolicy(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitter: true
    )

    /// Conservative retry policy for less critical requests
    public static let conservative = RetryPolicy(
        maxAttempts: 2,
        baseDelay: 2.0,
        maxDelay: 10.0,
        multiplier: 2.0,
        jitter: false
    )

    /// No retry policy
    public static let none = RetryPolicy(
        maxAttempts: 1,
        baseDelay: 0,
        maxDelay: 0,
        multiplier: 1.0,
        jitter: false
    )
}

// MARK: - CustomStringConvertible

extension RetryPolicy: CustomStringConvertible {
    public var description: String {
        """
        RetryPolicy(
            maxAttempts: \(maxAttempts),
            baseDelay: \(baseDelay)s,
            maxDelay: \(maxDelay)s,
            multiplier: \(multiplier),
            jitter: \(jitter)
        )
        """
    }
}

// MARK: - Convenience Methods

public extension RetryPolicy {
    /// Checks if a retry should be attempted for this attempt number
    /// - Parameter attempt: The current attempt number (0-indexed)
    /// - Returns: True if retry should be attempted
    func shouldRetry(attempt: Int) -> Bool {
        attempt < maxAttempts - 1
    }

    /// Performs a delay for the specified attempt
    /// - Parameter attempt: The retry attempt number (0-indexed)
    func performDelay(for attempt: Int) async throws {
        let delaySeconds = delay(for: attempt)
        guard delaySeconds > 0 else { return }

        let nanoseconds = UInt64(delaySeconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
