# Руководство по быстрому старту

[English version](./QuickStart.md)

Начните работу с Nevod за несколько минут. Это руководство охватывает наиболее распространенные сценарии использования.

## Содержание

- [Базовая настройка](#базовая-настройка)
- [Простые запросы](#простые-запросы)
- [Кастомные Routes](#кастомные-routes)
- [Аутентификация](#аутентификация)
- [Логирование](#логирование)
- [Обработка ошибок](#обработка-ошибок)
- [Множественные сервисы](#множественные-сервисы)
- [Продвинутые возможности](#продвинутые-возможности)

## Базовая настройка

### 1. Импортируйте необходимые модули

```swift
import Nevod
import Core
import Storage  // Если используете аутентификацию
```

### 2. Определите домен вашего сервиса

```swift
enum MyDomain: ServiceDomain {
    case api
    case cdn
    
    var identifier: String {
        switch self {
        case .api: return "api"
        case .cdn: return "cdn"
        }
    }
}
```

### 3. Создайте конфигурацию сети

```swift
let config = NetworkConfig(
    urls: [
        MyDomain.api: (
            test: URL(string: "https://test-api.example.com")!,
            prod: URL(string: "https://api.example.com")!
        )
    ],
    environment: .production,
    timeout: 30,
    retries: 3
)
```

### 4. Создайте Network Provider

```swift
let provider = NetworkProvider(config: config)
```

## Простые запросы

Nevod предоставляет готовые типы routes для распространенных HTTP методов:

### GET запрос

```swift
struct User: Decodable {
    let id: Int
    let name: String
    let email: String
}

let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

// Стиль async/await throws
do {
    let user = try await provider.perform(route)
    print("Пользователь: \(user.name)")
} catch {
    print("Ошибка: \(error)")
}

// Стиль Result
let result = await provider.request(route)
switch result {
case .success(let user):
    print("Пользователь: \(user.name)")
case .failure(let error):
    print("Ошибка: \(error)")
}
```

### POST запрос

```swift
struct CreateUserResponse: Decodable {
    let id: Int
    let name: String
}

let route = SimplePostRoute<CreateUserResponse, MyDomain>(
    endpoint: "/users",
    domain: .api,
    parameters: [
        "name": "Иван Иванов",
        "email": "ivan@example.com"
    ]
)

let response = try await provider.perform(route)
print("Создан пользователь с ID: \(response.id)")
```

### PUT запрос

```swift
let route = SimplePutRoute<User, MyDomain>(
    endpoint: "/users/123",
    domain: .api,
    parameters: ["name": "Мария Петрова"]
)

let updatedUser = try await provider.perform(route)
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

## Кастомные Routes

Для более сложных запросов создайте кастомные routes:

```swift
struct GetUserPostsRoute: Route {
    typealias Response = [Post]
    typealias Domain = MyDomain
    
    let userId: Int
    
    var domain: MyDomain { .api }
    var endpoint: String { "/users/\(userId)/posts" }
    var method: HTTPMethod { .get }
    var parameters: [String: String]? {
        ["limit": "10", "offset": "0"]
    }
}

// Использование
let route = GetUserPostsRoute(userId: 123)
let posts = try await provider.perform(route)
```

### POST с JSON телом

```swift
struct LoginRoute: Route {
    typealias Response = AuthResponse
    typealias Domain = MyDomain
    
    let email: String
    let password: String
    
    var domain: MyDomain { .api }
    var endpoint: String { "/auth/login" }
    var method: HTTPMethod { .post }
    var parameterEncoding: ParameterEncoding { .json }
    var parameters: [String: String]? {
        ["email": email, "password": password]
    }
}

// Использование
let route = LoginRoute(email: "user@example.com", password: "secret")
let authResponse = try await provider.perform(route)
```

### Кастомные заголовки

```swift
struct UploadRoute: Route {
    typealias Response = UploadResponse
    typealias Domain = MyDomain
    
    var domain: MyDomain { .api }
    var endpoint: String { "/upload" }
    var method: HTTPMethod { .post }
    var parameters: [String: String]? { nil }
    
    var headers: [String: String]? {
        [
            "Content-Type": "application/octet-stream",
            "X-Upload-Type": "image"
        ]
    }
}
```

## Аутентификация

### Настройка хранилища токенов

```swift
import Storage

let storage = UserDefaultsStorage()
let tokenStorage = TokenStorage(storage: storage)
```

### Создание Auth Interceptor

```swift
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: tokenStorage,
    refreshToken: {
        // Ваша логика обновления токена
        let newToken = try await refreshAccessToken()
        return newToken
    }
)
```

### Создание Provider с аутентификацией

```swift
let provider = NetworkProvider(
    config: config,
    interceptor: authInterceptor
)

// Все запросы теперь будут включать заголовок Authorization
// и автоматически повторяться при 401 с обновлением токена
```

### Полный пример аутентификации

```swift
// 1. Авторизация
struct LoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

let loginRoute = SimplePostRoute<LoginResponse, MyDomain>(
    endpoint: "/auth/login",
    domain: .api,
    parameters: ["email": "user@example.com", "password": "password"]
)

let loginResponse = try await provider.perform(loginRoute)

// 2. Сохранение токена
await tokenStorage.setToken(Token(value: loginResponse.accessToken))

// 3. Все последующие запросы автоматически аутентифицированы
let userRoute = SimpleGetRoute<User, MyDomain>(endpoint: "/users/me", domain: .api)
let user = try await provider.perform(userRoute)
```

## Логирование

### Логирование HTTP запросов/ответов (OSLog)

```swift
import OSLog

let logger = Logger(subsystem: "com.myapp", category: "Network")

let loggingInterceptor = LoggingInterceptor(
    logger: logger,
    logLevel: .verbose  // .minimal, .detailed, или .verbose
)

let provider = NetworkProvider(
    config: config,
    interceptor: loggingInterceptor
)
```

**Уровни логирования**:
- `.minimal` - Логирует только метод запроса и URL
- `.detailed` - Добавляет заголовки и статус коды
- `.verbose` - Включает тела запросов/ответов

### Логирование внутренних событий (Letopis)

```swift
import Letopis

let letopis = Letopis(interceptors: [
    ConsoleInterceptor()
])

let provider = NetworkProvider(
    config: config,
    logger: letopis
)
```

### Комбинированное логирование

```swift
let provider = NetworkProvider(
    config: config,
    interceptor: LoggingInterceptor(logger: logger, logLevel: .verbose),
    logger: Letopis(interceptors: [ConsoleInterceptor()])
)
```

## Обработка ошибок

### Типы NetworkError

```swift
public enum NetworkError: Error {
    case invalidURL
    case parsingError
    case timeout
    case noConnection
    case unauthorized
    case clientError(Int)
    case serverError(Int)
    case bodyEncodingFailed
    case unknown(Error)
}
```

### Обработка ошибок

```swift
do {
    let user = try await provider.perform(route)
    print("Успех: \(user)")
} catch let error as NetworkError {
    switch error {
    case .unauthorized:
        // Перенаправление на логин
        print("Пользователь не авторизован")
    case .timeout:
        // Показать опцию повтора
        print("Превышено время ожидания запроса")
    case .noConnection:
        // Показать сообщение об оффлайн режиме
        print("Нет подключения к интернету")
    case .parsingError:
        // Логировать проблему парсинга
        print("Не удалось распарсить ответ")
    case .clientError(let code):
        print("Ошибка клиента: \(code)")
    case .serverError(let code):
        print("Ошибка сервера: \(code)")
    default:
        print("Неизвестная ошибка: \(error)")
    }
}
```

## Множественные сервисы

### Определение множественных доменов

```swift
enum AppDomains: ServiceDomain {
    case mainAPI
    case analyticsAPI
    case cdn
    
    var identifier: String {
        switch self {
        case .mainAPI: return "main"
        case .analyticsAPI: return "analytics"
        case .cdn: return "cdn"
        }
    }
}
```

### Настройка множественных URL

```swift
let config = NetworkConfig(
    urls: [
        AppDomains.mainAPI: (
            test: URL(string: "https://test-api.example.com")!,
            prod: URL(string: "https://api.example.com")!
        ),
        AppDomains.analyticsAPI: (
            test: URL(string: "https://test-analytics.example.com")!,
            prod: URL(string: "https://analytics.example.com")!
        ),
        AppDomains.cdn: (
            test: URL(string: "https://test-cdn.example.com")!,
            prod: URL(string: "https://cdn.example.com")!
        )
    ],
    environment: .production
)
```

### Использование различных доменов

```swift
// Запрос к основному API
let userRoute = SimpleGetRoute<User, AppDomains>(
    endpoint: "/users/me",
    domain: .mainAPI  // → api.example.com
)

// Запрос к аналитике
let trackRoute = SimplePostRoute<TrackResponse, AppDomains>(
    endpoint: "/events",
    domain: .analyticsAPI,  // → analytics.example.com
    parameters: ["event": "page_view"]
)

// Запрос к CDN
let imageRoute = SimpleGetRoute<Data, AppDomains>(
    endpoint: "/images/logo.png",
    domain: .cdn  // → cdn.example.com
)
```

## Продвинутые возможности

### Комбинирование множественных Interceptor'ов

```swift
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        LoggingInterceptor(logger: logger, logLevel: .detailed),
        HeadersInterceptor(headers: [
            "User-Agent": "MyApp/1.0",
            "X-Client-Platform": "iOS"
        ]),
        AuthenticationInterceptor(
            tokenStorage: tokenStorage,
            refreshToken: { try await refreshToken() }
        )
    ])
)
```

**Порядок выполнения**:
1. Logging логирует запрос
2. Headers добавляет кастомные заголовки
3. Auth добавляет заголовок Authorization
4. Запрос отправляется в сеть
5. При 401: Auth обновляет токен и повторяет запрос
6. Ответ логируется

### Кастомный Interceptor

```swift
public actor RateLimitInterceptor: RequestInterceptor {
    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval
    
    public init(minimumInterval: TimeInterval = 1.0) {
        self.minimumInterval = minimumInterval
    }
    
    public func adapt(_ request: URLRequest) async throws -> URLRequest {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                try await Task.sleep(nanoseconds: UInt64((minimumInterval - elapsed) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
        return request
    }
}

// Использование
let provider = NetworkProvider(
    config: config,
    interceptor: RateLimitInterceptor(minimumInterval: 0.5)
)
```

### Ответ как сырые данные

```swift
let route = SimpleGetRoute<Data, MyDomain>(
    endpoint: "/download/file.pdf",
    domain: .api
)

let pdfData = try await provider.perform(route)
// Используйте pdfData напрямую
```

### Делегирование задач для отслеживания прогресса

```swift
class DownloadDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        print("Прогресс загрузки: \(progress * 100)%")
    }
}

let delegate = DownloadDelegate()
let result = await provider.request(uploadRoute, delegate: delegate)
```

## Лучшие практики

1. **Переиспользуйте NetworkProvider**: Создайте один раз, используйте во всем приложении
2. **Четко определяйте домены**: Используйте осмысленные идентификаторы доменов
3. **Грамотно обрабатывайте ошибки**: Всегда обрабатывайте случаи NetworkError
4. **Используйте Simple Routes**: Предпочитайте `SimpleGetRoute` и т.д. для стандартных запросов
5. **Кастомные Routes для сложных случаев**: Создавайте кастомные Route только когда необходимо
6. **Порядок Interceptor'ов важен**: Размещайте логирование первым, аутентификацию последней в цепочке
7. **Переключение окружений**: Используйте `.test` во время разработки, `.production` для релиза
8. **Безопасность токенов**: Используйте безопасное хранилище (Keychain) для production токенов

## Следующие шаги

- Изучите [Руководство по установке](./Installation-ru.md) для зависимостей
- Проверьте [API Reference](./API.md) для полной документации
- Просмотрите примеры исходного кода в репозитории

## Общие паттерны

### Паттерн Repository

```swift
protocol UserRepository {
    func getCurrentUser() async throws -> User
    func updateUser(_ user: User) async throws -> User
}

class NetworkUserRepository: UserRepository {
    private let provider: NetworkProvider
    
    init(provider: NetworkProvider) {
        self.provider = provider
    }
    
    func getCurrentUser() async throws -> User {
        let route = SimpleGetRoute<User, MyDomain>(
            endpoint: "/users/me",
            domain: .api
        )
        return try await provider.perform(route)
    }
    
    func updateUser(_ user: User) async throws -> User {
        let route = SimplePutRoute<User, MyDomain>(
            endpoint: "/users/\(user.id)",
            domain: .api,
            parameters: ["name": user.name, "email": user.email]
        )
        return try await provider.perform(route)
    }
}
```

### Dependency Injection

```swift
@MainActor
class UserViewModel: ObservableObject {
    @Published var user: User?
    @Published var error: NetworkError?
    
    private let provider: NetworkProvider
    
    init(provider: NetworkProvider) {
        self.provider = provider
    }
    
    func loadUser() async {
        let route = SimpleGetRoute<User, MyDomain>(
            endpoint: "/users/me",
            domain: .api
        )
        
        do {
            self.user = try await provider.perform(route)
        } catch let error as NetworkError {
            self.error = error
        }
    }
}
```

Удачного программирования с Nevod!
