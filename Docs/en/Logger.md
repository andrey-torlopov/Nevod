# NevodLogger - Flexible Logging System

NevodLogger is a flexible, closure-based logging system built on top of OSLog. It allows you to completely customize logging behavior for each log level while providing sensible defaults.

## Key Features

- **OSLog-based by default** - Uses Apple's unified logging system
- **Fully customizable** - Override any log level with custom handlers
- **Type-safe** - Built with Swift's strong type system
- **Actor-based** - Thread-safe by design
- **Zero dependencies** - No external logging frameworks needed
- **Flexible payload** - Attach structured data to logs

## Basic Usage

### Default OSLog Logger

```swift
let logger = NevodLogger()

await logger.debug("Starting request", payload: ["endpoint": "/users"])
await logger.info("Request completed")
await logger.warning("Slow response time")
await logger.error("Request failed", payload: ["error": "timeout"])
```

### Console Logger

For simple debugging or when OSLog is unavailable:

```swift
let logger = NevodLogger(config: .console)
await logger.info("This will print to console")
```

### Silent Logger

Disable all logging (useful for tests or production):

```swift
let logger = NevodLogger(config: .silent)
await logger.debug("This won't be logged")
```

## Custom Configuration

### Selective Logging

Disable specific log levels:

```swift
let config = LoggerConfiguration(
    debugHandler: nil, // Disable debug logs
    infoHandler: { context in
        print("ℹ️ \(context.message)")
    },
    warningHandler: { context in
        print("⚠️ \(context.message)")
    },
    errorHandler: { context in
        print("❌ \(context.message)")
        // Send to analytics
        Analytics.trackError(context.message, metadata: context.payload)
    }
)

let logger = NevodLogger(config: config)
```

### Custom OSLog Configuration

Specify your own subsystem and category:

```swift
let config = LoggerConfiguration.oslog(
    subsystem: "com.myapp.network",
    category: "NetworkRequests"
)

let logger = NevodLogger(config: config)
```

## Integration with NetworkProvider

### Using with NetworkProvider

```swift
// Custom logger for network operations
let networkLogger = NevodLogger(
    config: .oslog(subsystem: "com.myapp", category: "Network")
)

let provider = NetworkProvider.quick(
    baseURL: URL(string: "https://api.example.com")!,
    logger: networkLogger
)
```

### Using with LoggingInterceptor

```swift
let interceptorLogger = NevodLogger(
    config: .oslog(subsystem: "com.myapp", category: "Requests")
)

let interceptor = LoggingInterceptor(
    logger: interceptorLogger,
    hideHeaderFields: ["authorization", "api-key"]
)

let provider = NetworkProvider(
    config: config,
    interceptor: interceptor
)
```

## Advanced Usage

### Environment-Based Configuration

```swift
let config: LoggerConfiguration

#if DEBUG
config = .console
#else
config = LoggerConfiguration(
    debugHandler: nil,
    infoHandler: nil,
    errorHandler: { context in
        CrashReporter.log(context.message, metadata: context.payload)
    }
)
#endif

let logger = NevodLogger(config: config)
```

### Multiple Actions per Log Level

```swift
let config = LoggerConfiguration(
    errorHandler: { context in
        // 1. Log to OSLog
        Logger(subsystem: "com.myapp", category: "Errors")
            .error("\(context.message)")
        
        // 2. Send to crash reporting
        CrashReporter.log(context)
        
        // 3. Write to file
        FileLogger.write(context)
        
        // 4. Show debug alert
        #if DEBUG
        showDebugAlert(context.message)
        #endif
    }
)
```

### Custom Log Handler

```swift
func createCustomHandler(level: String) -> LogHandler {
    return { context in
        let timestamp = ISO8601DateFormatter().string(from: context.timestamp)
        let fileName = (context.file as NSString).lastPathComponent
        let payloadString = context.payload.isEmpty 
            ? "" 
            : " | \(context.payload)"
        
        print("[\(timestamp)] [\(level)] [\(fileName):\(context.line)] \(context.message)\(payloadString)")
    }
}

let config = LoggerConfiguration(
    debugHandler: createCustomHandler(level: "DEBUG"),
    infoHandler: createCustomHandler(level: "INFO"),
    warningHandler: createCustomHandler(level: "WARNING"),
    errorHandler: createCustomHandler(level: "ERROR")
)
```

## LogContext Structure

Each log handler receives a `LogContext` with:

```swift
public struct LogContext {
    public let level: LogLevel          // .debug, .info, .warning, .error
    public let message: String          // The log message
    public let payload: [String: String] // Additional structured data
    public let file: String             // Source file path
    public let function: String         // Function name
    public let line: Int                // Line number
    public let timestamp: Date          // When log was created
}
```

## Best Practices

1. **Use appropriate log levels**
   - `debug`: Detailed diagnostic information
   - `info`: General informational messages
   - `warning`: Warning messages for potentially harmful situations
   - `error`: Error events that might still allow the app to continue

2. **Disable debug logs in production**
   ```swift
   let config = LoggerConfiguration(
       debugHandler: nil, // Disable in production
       // ... other handlers
   )
   ```

3. **Use payload for structured data**
   ```swift
   await logger.error("Request failed", payload: [
       "endpoint": "/users",
       "status_code": "500",
       "error_code": "TIMEOUT"
   ])
   ```

4. **Hide sensitive data in LoggingInterceptor**
   ```swift
   let interceptor = LoggingInterceptor(
       hideHeaderFields: ["authorization", "api-key", "password", "token"]
   )
   ```

5. **Use different loggers for different subsystems**
   ```swift
   let networkLogger = NevodLogger(
       config: .oslog(subsystem: "com.myapp", category: "Network")
   )
   
   let authLogger = NevodLogger(
       config: .oslog(subsystem: "com.myapp", category: "Auth")
   )
   ```

## Migration from Letopis

The previous Letopis dependency has been replaced with NevodLogger. Key differences:

**Before (Letopis):**
```swift
let logger = Letopis(interceptors: [ConsoleInterceptor()])
logger.debug("Message", payload: ["key": "value"])
logger.event(NetworkEventType.api).action(NetworkAction.start).info("Message")
```

**After (NevodLogger):**
```swift
let logger = NevodLogger() // or NevodLogger(config: .console)
await logger.debug("Message", payload: ["key": "value"])
await logger.info("Message", payload: ["event": "api", "action": "start"])
```

The main changes:
- No external dependencies
- Simpler, more focused API
- Built on OSLog
- Fully customizable through closures
- `await` required (actor-based)
