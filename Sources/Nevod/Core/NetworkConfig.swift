import Foundation

public struct NetworkConfig {
    private let environments: [AnyHashable: any NetworkEnvironmentProviding]
    public let timeout: TimeInterval
    public let retries: Int

    /// Initialize NetworkConfig with environment providers for each domain.
    /// This is the recommended way to configure network settings per domain.
    ///
    /// Example:
    /// ```swift
    /// let config = NetworkConfig(
    ///     environments: [
    ///         MyDomain.api: SimpleEnvironment(
    ///             baseURL: URL(string: "https://api.example.com")!,
    ///             apiKey: "secret-key"
    ///         ),
    ///         MyDomain.cdn: SimpleEnvironment(
    ///             baseURL: URL(string: "https://cdn.example.com")!
    ///         )
    ///     ],
    ///     timeout: 30,
    ///     retries: 3
    /// )
    /// ```
    public init<Domain: ServiceDomain>(
        environments: [Domain: any NetworkEnvironmentProviding],
        timeout: TimeInterval = 30,
        retries: Int = 3
    ) {
        self.environments = Dictionary(uniqueKeysWithValues: environments.map { (AnyHashable($0.key), $0.value) })
        self.timeout = timeout
        self.retries = retries
    }

    /// Initializer for aggregating multiple domain configurations from different modules
    public init(
        environmentConfigurations: [[AnyHashable: any NetworkEnvironmentProviding]],
        timeout: TimeInterval = 30,
        retries: Int = 3
    ) {
        var mergedEnvironments: [AnyHashable: any NetworkEnvironmentProviding] = [:]
        for config in environmentConfigurations {
            mergedEnvironments.merge(config) { _, new in new } // new values override old ones
        }
        self.environments = mergedEnvironments
        self.timeout = timeout
        self.retries = retries
    }

    /// Get environment provider for a specific domain
    public func environment<Domain: ServiceDomain>(
        for domain: Domain
    ) -> Result<any NetworkEnvironmentProviding, NetworkError> {
        guard let env = environments[AnyHashable(domain)] else {
            return .failure(.invalidURL)
        }
        return .success(env)
    }

    /// Convenience method to get base URL for a domain
    public func baseURL<Domain: ServiceDomain>(for domain: Domain) -> Result<URL, NetworkError> {
        environment(for: domain).map { $0.baseURL }
    }
}
