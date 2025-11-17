import Foundation
import Nevod

// MARK: - Example 1: Using default OSLog logger

func example1_DefaultOSLog() async {
    // Uses OSLog by default
    let logger = NevodLogger()

    await logger.debug("This is a debug message", payload: ["key": "value"])
    await logger.info("This is an info message")
    await logger.warning("This is a warning")
    await logger.error("This is an error", payload: ["error_code": "500"])
}

// MARK: - Example 2: Using console logger

func example2_ConsoleLogger() async {
    // Console logger for simple debugging
    let config = LoggerConfiguration.console
    let logger = NevodLogger(config: config)

    await logger.debug("Debug message in console")
    await logger.info("Info message in console")
}

// MARK: - Example 3: Silent logger (all logs disabled)

func example3_SilentLogger() async {
    // Disable all logs
    let config = LoggerConfiguration.silent
    let logger = NevodLogger(config: config)

    // These messages will not be logged
    await logger.debug("This won't be logged")
    await logger.error("This won't be logged either")
}

// MARK: - Example 4: Custom logger with selective logging

func example4_CustomLogger() async {
    // Configure only specific logging levels
    let config = LoggerConfiguration(
        debugHandler: nil, // disable debug
        infoHandler: { context in
            print("ℹ️ [INFO] \(context.message)")
        },
        warningHandler: { context in
            print("⚠️ [WARNING] \(context.message)")
        },
        errorHandler: { context in
            print("❌ [ERROR] \(context.message)")
            // Can send to analytics
            // Analytics.track(error: context.message, metadata: context.payload)
        }
    )

    let logger = NevodLogger(config: config)

    await logger.debug("This won't be logged") // debug disabled
    await logger.info("This will be logged")
    await logger.error("This error will be logged and sent to analytics")
}

// MARK: - Example 5: Using with NetworkProvider

func example5_NetworkProviderWithLogger() async throws {
    // Create custom logger for NetworkProvider
    let loggerConfig = LoggerConfiguration(
        debugHandler: nil, // disable debug in production
        infoHandler: { context in
            print("📡 [Network Info] \(context.message)")
        },
        errorHandler: { context in
            print("🔴 [Network Error] \(context.message)")
            // Send critical network errors to Sentry/Crashlytics
            // ErrorTracker.logError(context.message, metadata: context.payload)
        }
    )

    let logger = NevodLogger(config: loggerConfig)

    let provider = NetworkProvider.quick(
        baseURL: URL(string: "https://api.example.com")!,
        logger: logger
    )

    // Now all requests will be logged through our custom logger
    // let users: [User] = try await provider.get("/users")
}

// MARK: - Example 6: Using with LoggingInterceptor

func example6_LoggingInterceptor() async {
    // Create logger for interceptor
    let interceptorLogger = NevodLogger(
        config: .oslog(subsystem: "com.myapp.network", category: "RequestLogs")
    )

    let loggingInterceptor = LoggingInterceptor(
        logger: interceptorLogger,
        hideHeaderFields: ["authorization", "api-key", "password"]
    )

    let config = NetworkConfig(
        environments: [DefaultDomain.default: SimpleEnvironment(baseURL: URL(string: "https://api.example.com")!)],
        timeout: 30,
        retries: 3
    )

    let provider = NetworkProvider(
        config: config,
        interceptor: loggingInterceptor
    )

    // Now all requests will be logged through LoggingInterceptor
}

// MARK: - Example 7: Multiple handlers for same level

func example7_MultipleHandlers() async {
    // Can combine different ways of handling logs
    let config = LoggerConfiguration(
        errorHandler: { context in
            // 1. Print to console
            print("❌ Error: \(context.message)")

            // 2. Write to file
            // FileLogger.write(context)

            // 3. Send to analytics
            // Analytics.trackError(context)

            // 4. Show alert in debug mode
            #if DEBUG
            // showDebugAlert(context.message)
            #endif
        }
    )

    let logger = NevodLogger(config: config)
    await logger.error("Critical error occurred")
}

// MARK: - Example 8: Environment-based logging

func example8_EnvironmentBasedLogging() async {
    let config: LoggerConfiguration

    #if DEBUG
    // In debug mode use console with all levels
    config = .console
    #else
    // In production disable debug, keep only important logs
    config = LoggerConfiguration(
        debugHandler: nil,
        infoHandler: nil,
        warningHandler: { context in
            // Log only to OSLog
            let logger = Logger(subsystem: "com.myapp", category: "Production")
            logger.warning("\(context.message)")
        },
        errorHandler: { context in
            // Send to crash reporting
            let logger = Logger(subsystem: "com.myapp", category: "Production")
            logger.error("\(context.message)")
            // CrashReporter.log(context)
        }
    )
    #endif

    let logger = NevodLogger(config: config)
    await logger.debug("Debug info")
    await logger.error("Production error")
}
