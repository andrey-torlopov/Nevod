# NevodLogger - Гибкая система логирования

NevodLogger - это гибкая система логирования на основе замыканий, построенная поверх OSLog. Она позволяет полностью настроить поведение логирования для каждого уровня, предоставляя при этом разумные настройки по умолчанию.

## Ключевые особенности

- **OSLog по умолчанию** - использует унифицированную систему логирования Apple
- **Полностью настраиваемый** - переопределяйте любой уровень логирования своими обработчиками
- **Типобезопасный** - построен на строгой системе типов Swift
- **Actor-based** - потокобезопасен по дизайну
- **Без зависимостей** - не требует внешних фреймворков для логирования
- **Гибкий payload** - прикрепляйте структурированные данные к логам

## Базовое использование

### Логгер OSLog по умолчанию

```swift
let logger = NevodLogger()

await logger.debug("Начало запроса", payload: ["endpoint": "/users"])
await logger.info("Запрос завершён")
await logger.warning("Медленное время отклика")
await logger.error("Запрос не удался", payload: ["error": "timeout"])
```

### Консольный логгер

Для простой отладки или когда OSLog недоступен:

```swift
let logger = NevodLogger(config: .console)
await logger.info("Будет выведено в консоль")
```

### Тихий логгер

Отключить всё логирование (полезно для тестов или production):

```swift
let logger = NevodLogger(config: .silent)
await logger.debug("Это не будет залогировано")
```

## Кастомная конфигурация

### Выборочное логирование

Отключите определённые уровни логирования:

```swift
let config = LoggerConfiguration(
    debugHandler: nil, // Отключаем debug логи
    infoHandler: { context in
        print("ℹ️ \(context.message)")
    },
    warningHandler: { context in
        print("⚠️ \(context.message)")
    },
    errorHandler: { context in
        print("❌ \(context.message)")
        // Отправляем в аналитику
        Analytics.trackError(context.message, metadata: context.payload)
    }
)

let logger = NevodLogger(config: config)
```

### Кастомная конфигурация OSLog

Укажите свою подсистему и категорию:

```swift
let config = LoggerConfiguration.oslog(
    subsystem: "com.myapp.network",
    category: "NetworkRequests"
)

let logger = NevodLogger(config: config)
```

## Интеграция с NetworkProvider

### Использование с NetworkProvider

```swift
// Кастомный логгер для сетевых операций
let networkLogger = NevodLogger(
    config: .oslog(subsystem: "com.myapp", category: "Network")
)

let provider = NetworkProvider.quick(
    baseURL: URL(string: "https://api.example.com")!,
    logger: networkLogger
)
```

### Использование с LoggingInterceptor

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

## Продвинутое использование

### Конфигурация в зависимости от окружения

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

### Множественные действия для одного уровня

```swift
let config = LoggerConfiguration(
    errorHandler: { context in
        // 1. Логируем в OSLog
        Logger(subsystem: "com.myapp", category: "Errors")
            .error("\(context.message)")
        
        // 2. Отправляем в crash reporting
        CrashReporter.log(context)
        
        // 3. Записываем в файл
        FileLogger.write(context)
        
        // 4. Показываем алерт в debug режиме
        #if DEBUG
        showDebugAlert(context.message)
        #endif
    }
)
```

### Кастомный обработчик логов

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

## Структура LogContext

Каждый обработчик логов получает `LogContext` с:

```swift
public struct LogContext {
    public let level: LogLevel          // .debug, .info, .warning, .error
    public let message: String          // Сообщение лога
    public let payload: [String: String] // Дополнительные структурированные данные
    public let file: String             // Путь к файлу исходника
    public let function: String         // Имя функции
    public let line: Int                // Номер строки
    public let timestamp: Date          // Время создания лога
}
```

## Лучшие практики

1. **Используйте подходящие уровни логирования**
   - `debug`: Детальная диагностическая информация
   - `info`: Общие информационные сообщения
   - `warning`: Предупреждения о потенциально опасных ситуациях
   - `error`: События ошибок, которые всё же позволяют приложению продолжать работу

2. **Отключайте debug логи в production**
   ```swift
   let config = LoggerConfiguration(
       debugHandler: nil, // Отключаем в production
       // ... другие обработчики
   )
   ```

3. **Используйте payload для структурированных данных**
   ```swift
   await logger.error("Запрос не удался", payload: [
       "endpoint": "/users",
       "status_code": "500",
       "error_code": "TIMEOUT"
   ])
   ```

4. **Скрывайте чувствительные данные в LoggingInterceptor**
   ```swift
   let interceptor = LoggingInterceptor(
       hideHeaderFields: ["authorization", "api-key", "password", "token"]
   )
   ```

5. **Используйте разные логгеры для разных подсистем**
   ```swift
   let networkLogger = NevodLogger(
       config: .oslog(subsystem: "com.myapp", category: "Network")
   )
   
   let authLogger = NevodLogger(
       config: .oslog(subsystem: "com.myapp", category: "Auth")
   )
   ```

## Миграция с Letopis

Предыдущая зависимость Letopis была заменена на NevodLogger. Ключевые отличия:

**Раньше (Letopis):**
```swift
let logger = Letopis(interceptors: [ConsoleInterceptor()])
logger.debug("Сообщение", payload: ["key": "value"])
logger.event(NetworkEventType.api).action(NetworkAction.start).info("Сообщение")
```

**Сейчас (NevodLogger):**
```swift
let logger = NevodLogger() // или NevodLogger(config: .console)
await logger.debug("Сообщение", payload: ["key": "value"])
await logger.info("Сообщение", payload: ["event": "api", "action": "start"])
```

Основные изменения:
- Нет внешних зависимостей
- Более простой и сфокусированный API
- Построен на OSLog
- Полностью настраиваемый через замыкания
- Требуется `await` (основан на actor)

## Примеры использования

### Пример 1: Отключение debug в production

```swift
#if DEBUG
let logger = NevodLogger(config: .console)
#else
let logger = NevodLogger(config: LoggerConfiguration(
    debugHandler: nil,
    infoHandler: nil,
    warningHandler: { context in
        Logger(subsystem: "com.myapp", category: "Production")
            .warning("\(context.message)")
    },
    errorHandler: { context in
        Logger(subsystem: "com.myapp", category: "Production")
            .error("\(context.message)")
        CrashReporter.log(context)
    }
))
#endif
```

### Пример 2: Собственная система логирования

```swift
class MyCustomLogger {
    static func log(_ context: LogContext) {
        // Своя логика логирования
        saveToDatabase(context)
        sendToServer(context)
    }
}

let config = LoggerConfiguration(
    errorHandler: { context in
        MyCustomLogger.log(context)
    }
)

let logger = NevodLogger(config: config)
```

### Пример 3: Логирование с метриками

```swift
let config = LoggerConfiguration(
    infoHandler: { context in
        print("ℹ️ \(context.message)")
        Metrics.increment("logs.info")
    },
    errorHandler: { context in
        print("❌ \(context.message)")
        Metrics.increment("logs.error")
        Metrics.gauge("last_error_timestamp", value: context.timestamp.timeIntervalSince1970)
    }
)
```
