# Руководство по быстрому старту

[English version](../en/QuickStart.md)

Начните работу с Nevod за несколько минут. Это руководство охватывает основные шаги по интеграции Nevod в ваш проект.

## Установка

Добавьте Nevod в ваш `Package.swift`:

```swift
dependencies: [
    .package(url: "git@github.com:andrey-torlopov/Nevod.git", from: "0.0.5")
]
```

## Базовая настройка

### 1. Определите домен сервиса

```swift
import Nevod

enum MyDomain: ServiceDomain {
    case api
    
    var identifier: String { "api" }
}
```

### 2. Создайте конфигурацию

```swift
let config = NetworkConfig(
    environments: [
        MyDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!
        )
    ],
    timeout: 30,
    retries: 3
)
```

### 3. Создайте провайдер

```swift
let provider = NetworkProvider(config: config)
```

## Выполнение запросов

### GET запрос

```swift
struct User: Decodable {
    let id: Int
    let name: String
}

let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

let user = try await provider.perform(route)
```

### POST запрос

```swift
struct CreateUserRequest: Encodable {
    let name: String
    let email: String
}

let route = SimplePostRoute<User, MyDomain>(
    endpoint: "/users",
    domain: .api,
    parameters: ["name": "John", "email": "john@example.com"]
)

let user = try await provider.perform(route)
```

### PUT запрос

```swift
let route = SimplePutRoute<User, MyDomain>(
    endpoint: "/users/123",
    domain: .api,
    parameters: ["name": "Jane"]
)

let user = try await provider.perform(route)
```

### DELETE запрос

```swift
struct DeleteResponse: Decodable {
    let success: Bool
}

let route = SimpleDeleteRoute<DeleteResponse, MyDomain>(
    endpoint: "/users/123",
    domain: .api
)

let response = try await provider.perform(route)
```

## Аутентификация

Nevod поддерживает несколько методов аутентификации из коробки.

### Bearer Token

```swift
// 1. Создайте хранилище
let storage = TokenStorage<Token>(storage: yourKeyValueStorage)

// 2. Создайте interceptor аутентификации
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        let newToken = try await refreshToken(oldToken?.value)
        return Token(value: newToken)
    }
)

// 3. Создайте провайдер с аутентификацией
let provider = NetworkProvider(
    config: config,
    interceptor: authInterceptor
)
```

### Cookie аутентификация

```swift
let cookieStorage = TokenStorage<CookieToken>(storage: keychain)

let cookieInterceptor = CookieAuthenticationInterceptor(
    cookieStorage: cookieStorage,
    loginStrategy: {
        let response = try await performLogin(email: email, password: password)
        let cookies = HTTPCookieStorage.shared.cookies(for: loginURL) ?? []
        return CookieToken(sessionCookies: cookies)
    }
)

let provider = NetworkProvider(config: config, interceptor: cookieInterceptor)
```

### API Key (в заголовке)

```swift
let token = APIKeyToken(apiKey: "your-key", headerName: "X-API-Key")
let storage = TokenStorage<APIKeyToken>(storage: userDefaults)
await storage.save(token)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { _ in throw NetworkError.unauthorized }
)
```

### API Key (параметр запроса)

```swift
let token = QueryAPIKeyToken(apiKey: "your-key", paramName: "api_key")
let storage = TokenStorage<QueryAPIKeyToken>(storage: userDefaults)
await storage.save(token)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { _ in throw NetworkError.unauthorized }
)
```

## Логирование

### Логирование HTTP запросов/ответов

```swift
import OSLog

let logger = Logger(subsystem: "com.myapp", category: "Network")
let loggingInterceptor = LoggingInterceptor(logger: logger, logLevel: .verbose)

let provider = NetworkProvider(
    config: config,
    interceptor: loggingInterceptor
)
```

## Обработка ошибок

```swift
do {
    let user = try await provider.perform(route)
} catch let error as NetworkError {
    switch error {
    case .unauthorized:
        // Обработка ошибки авторизации
    case .timeout:
        // Обработка таймаута
    case .noConnection:
        // Обработка отсутствия соединения
    case .parsingError:
        // Обработка ошибки парсинга
    case .clientError(let code):
        // Обработка клиентской ошибки
    case .serverError(let code):
        // Обработка серверной ошибки
    default:
        // Обработка других ошибок
    }
}
```

## Множественные сервисы

```swift
enum AppDomains: ServiceDomain {
    case mainAPI
    case cdn
    
    var identifier: String {
        switch self {
        case .mainAPI: return "main"
        case .cdn: return "cdn"
        }
    }
}

let config = NetworkConfig(
    environments: [
        AppDomains.mainAPI: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!
        ),
        AppDomains.cdn: SimpleEnvironment(
            baseURL: URL(string: "https://cdn.example.com")!
        )
    ]
)

// Используйте разные домены
let userRoute = SimpleGetRoute<User, AppDomains>(
    endpoint: "/users/me",
    domain: .mainAPI
)

let imageRoute = SimpleGetRoute<Data, AppDomains>(
    endpoint: "/images/avatar.png",
    domain: .cdn
)
```

## Объединение Interceptor'ов

```swift
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        LoggingInterceptor(logger: logger, logLevel: .detailed),
        HeadersInterceptor(headers: ["User-Agent": "MyApp/1.0"]),
        AuthenticationInterceptor(tokenStorage: storage, refreshStrategy: refreshBlock)
    ])
)
```

## Кастомные маршруты

Для большего контроля создайте кастомные маршруты:

```swift
struct GetUserPostsRoute: Route {
    typealias Response = [Post]
    typealias Domain = MyDomain
    
    let userId: Int
    
    var domain: MyDomain { .api }
    var endpoint: String { "/users/\(userId)/posts" }
    var method: HTTPMethod { .get }
    var parameters: [String: String]? {
        ["limit": "10"]
    }
}

let route = GetUserPostsRoute(userId: 123)
let posts = try await provider.perform(route)
```

## Реализация KeyValueStorage

Для хранения токенов реализуйте `KeyValueStorage`:

```swift
final class UserDefaultsStorage: KeyValueStorage {
    private let defaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }
    
    nonisolated func string(for key: StorageKey) -> String? {
        defaults.string(forKey: key.rawValue)
    }
    
    nonisolated func data(for key: StorageKey) -> Data? {
        defaults.data(forKey: key.rawValue)
    }
    
    nonisolated func set(_ value: String?, for key: StorageKey) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    nonisolated func set(_ value: Data?, for key: StorageKey) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    nonisolated func remove(for key: StorageKey) {
        defaults.removeObject(forKey: key.rawValue)
    }
}
```

**Примечание:** Для production используйте Keychain для безопасного хранения токенов.

## Следующие шаги

- [Руководство по аутентификации](./Authentication-ru.md) - Изучите все методы аутентификации
- [Руководство по установке](./Installation-ru.md) - Детали установки

Для дополнительной информации смотрите основной [README](../../README-ru.md).
