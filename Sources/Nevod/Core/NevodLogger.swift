import Foundation
import os.log

// MARK: - Log Level

/// Log levels for Nevod
public enum LogLevel: Sendable {
    case debug
    case info
    case warning
    case error
}

// MARK: - Log Context

/// Log context - all information for log processing
public struct LogContext: Sendable {
    /// Log level
    public let level: LogLevel

    /// Text message
    public let message: String

    /// Additional data as a dictionary
    public let payload: [String: String]

    /// File where logging occurred
    public let file: String

    /// Function where logging occurred
    public let function: String

    /// Line where logging occurred
    public let line: Int

    /// Timestamp of logging
    public let timestamp: Date

    public init(
        level: LogLevel,
        message: String,
        payload: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        timestamp: Date = Date()
    ) {
        self.level = level
        self.message = message
        self.payload = payload
        self.file = file
        self.function = function
        self.line = line
        self.timestamp = timestamp
    }
}

// MARK: - Log Handler

/// Closure for handling logs
public typealias LogHandler = @Sendable (LogContext) -> Void

// MARK: - Logger Configuration

/// Logger configuration with customizable handlers for each level
public struct LoggerConfiguration: Sendable {
    /// Debug log handler (optional)
    public let debugHandler: LogHandler?

    /// Info log handler (optional)
    public let infoHandler: LogHandler?

    /// Warning log handler (optional)
    public let warningHandler: LogHandler?

    /// Error log handler (optional)
    public let errorHandler: LogHandler?

    /// Creates a custom logger configuration
    /// - Parameters:
    ///   - debugHandler: Handler for debug logs. If nil - debug logs won't be processed
    ///   - infoHandler: Handler for info logs. If nil - info logs won't be processed
    ///   - warningHandler: Handler for warning logs. If nil - warning logs won't be processed
    ///   - errorHandler: Handler for error logs. If nil - error logs won't be processed
    ///
    /// Example:
    /// ```swift
    /// let config = LoggerConfiguration(
    ///     debugHandler: nil, // disable debug logs
    ///     infoHandler: { context in
    ///         print("[INFO] \(context.message)")
    ///     },
    ///     warningHandler: { context in
    ///         print("[WARNING] \(context.message)")
    ///     },
    ///     errorHandler: { context in
    ///         // Send to analytics
    ///         Analytics.logError(context.message, metadata: context.payload)
    ///     }
    /// )
    /// ```
    public init(
        debugHandler: LogHandler? = nil,
        infoHandler: LogHandler? = nil,
        warningHandler: LogHandler? = nil,
        errorHandler: LogHandler? = nil
    ) {
        self.debugHandler = debugHandler
        self.infoHandler = infoHandler
        self.warningHandler = warningHandler
        self.errorHandler = errorHandler
    }

    /// Creates a configuration with default OSLog implementation
    /// - Parameters:
    ///   - subsystem: Subsystem identifier for OSLog (usually bundle identifier)
    ///   - category: Log category for convenient filtering
    /// - Returns: Configuration with OSLog handlers
    ///
    /// Example:
    /// ```swift
    /// let config = LoggerConfiguration.oslog(
    ///     subsystem: "com.myapp.network",
    ///     category: "NetworkProvider"
    /// )
    /// ```
    public static func oslog(
        subsystem: String = "com.nevod.network",
        category: String = "Nevod"
    ) -> LoggerConfiguration {
        let osLogger = Logger(subsystem: subsystem, category: category)

        let debugHandler: LogHandler = { context in
            let payloadString = context.payload.isEmpty ? "" : " | \(context.payload)"
            osLogger.debug("\(context.message)\(payloadString)")
        }

        let infoHandler: LogHandler = { context in
            let payloadString = context.payload.isEmpty ? "" : " | \(context.payload)"
            osLogger.info("\(context.message)\(payloadString)")
        }

        let warningHandler: LogHandler = { context in
            let payloadString = context.payload.isEmpty ? "" : " | \(context.payload)"
            osLogger.warning("\(context.message)\(payloadString)")
        }

        let errorHandler: LogHandler = { context in
            let payloadString = context.payload.isEmpty ? "" : " | \(context.payload)"
            osLogger.error("\(context.message)\(payloadString)")
        }

        return LoggerConfiguration(
            debugHandler: debugHandler,
            infoHandler: infoHandler,
            warningHandler: warningHandler,
            errorHandler: errorHandler
        )
    }

    /// Creates a "silent" configuration - all logs disabled
    /// Useful for production builds or tests
    public static var silent: LoggerConfiguration {
        LoggerConfiguration(
            debugHandler: nil,
            infoHandler: nil,
            warningHandler: nil,
            errorHandler: nil
        )
    }

    /// Creates a configuration with print-based logging
    /// Useful for simple debugging or when OSLog is unavailable
    public static var console: LoggerConfiguration {
        let printHandler: (LogLevel) -> LogHandler = { level in
            return { context in
                let levelString: String
                switch level {
                case .debug: levelString = "DEBUG"
                case .info: levelString = "INFO"
                case .warning: levelString = "WARNING"
                case .error: levelString = "ERROR"
                }

                let payloadString = context.payload.isEmpty ? "" : " | \(context.payload)"
                let fileName = (context.file as NSString).lastPathComponent
                print("[\(levelString)] [\(fileName):\(context.line)] \(context.message)\(payloadString)")
            }
        }

        return LoggerConfiguration(
            debugHandler: printHandler(.debug),
            infoHandler: printHandler(.info),
            warningHandler: printHandler(.warning),
            errorHandler: printHandler(.error)
        )
    }
}

// MARK: - Nevod Logger

/// Main logger for Nevod with support for customizable handlers
///
/// The logger allows flexible configuration of log handling through closures.
/// By default uses OSLog, but you can easily override any log level.
///
/// Example with default settings:
/// ```swift
/// let logger = NevodLogger()
/// logger.info("Request started", payload: ["endpoint": "/users"])
/// ```
///
/// Example with custom configuration:
/// ```swift
/// let config = LoggerConfiguration(
///     debugHandler: nil, // disable debug
///     errorHandler: { context in
///         // Send errors to analytics
///         Analytics.logError(context.message, metadata: context.payload)
///     }
/// )
/// let logger = NevodLogger(config: config)
/// ```
public actor NevodLogger {
    private let config: LoggerConfiguration

    /// Creates a logger with the specified configuration
    /// - Parameter config: Logger configuration (default: OSLog)
    public init(config: LoggerConfiguration = .oslog()) {
        self.config = config
    }

    /// Logs a debug message
    /// - Parameters:
    ///   - message: Message text
    ///   - payload: Additional data
    ///   - file: File (automatic)
    ///   - function: Function (automatic)
    ///   - line: Line (automatic)
    public func debug(
        _ message: String,
        payload: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard let handler = config.debugHandler else { return }

        let context = LogContext(
            level: .debug,
            message: message,
            payload: payload,
            file: file,
            function: function,
            line: line
        )

        handler(context)
    }

    /// Logs an info message
    /// - Parameters:
    ///   - message: Message text
    ///   - payload: Additional data
    ///   - file: File (automatic)
    ///   - function: Function (automatic)
    ///   - line: Line (automatic)
    public func info(
        _ message: String,
        payload: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard let handler = config.infoHandler else { return }

        let context = LogContext(
            level: .info,
            message: message,
            payload: payload,
            file: file,
            function: function,
            line: line
        )

        handler(context)
    }

    /// Logs a warning message
    /// - Parameters:
    ///   - message: Message text
    ///   - payload: Additional data
    ///   - file: File (automatic)
    ///   - function: Function (automatic)
    ///   - line: Line (automatic)
    public func warning(
        _ message: String,
        payload: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard let handler = config.warningHandler else { return }

        let context = LogContext(
            level: .warning,
            message: message,
            payload: payload,
            file: file,
            function: function,
            line: line
        )

        handler(context)
    }

    /// Logs an error message
    /// - Parameters:
    ///   - message: Message text
    ///   - payload: Additional data
    ///   - file: File (automatic)
    ///   - function: Function (automatic)
    ///   - line: Line (automatic)
    public func error(
        _ message: String,
        payload: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard let handler = config.errorHandler else { return }

        let context = LogContext(
            level: .error,
            message: message,
            payload: payload,
            file: file,
            function: function,
            line: line
        )

        handler(context)
    }
}
