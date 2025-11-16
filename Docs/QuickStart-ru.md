# Руководство по быстрому старту

[English version](./QuickStart.md)

Начните работу с Nevod за несколько минут. Это руководство охватывает наиболее распространённые случаи использования.

## Содержание

- [Базовая настройка](#базовая-настройка)
- [Простые запросы](#простые-запросы)
- [Кастомные маршруты](#кастомные-маршруты)
- [Аутентификация](#аутентификация)
- [Логирование](#логирование)
- [Обработка ошибок](#обработка-ошибок)
- [Множественные сервисы](#множественные-сервисы)
- [Продвинутые функции](#продвинутые-функции)

## Базовая настройка

### 1. Импорт необходимых модулей

```swift
import Nevod
```

Nevod включает встроенную поддержку хранения токенов. Структурированное логирование через Letopis остаётся опциональным (`import Letopis`).

### 2. Определите ваш домен сервиса

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
    environments: [
        MyDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!
        )
    ],
    timeout: 30,
    retries: 3
)
```

`SimpleEnvironment` поставляется с Nevod и соответствует `NetworkEnvironmentProviding`. Предоставьте свою реализацию, если нужна динамическая конфигурация (например, staging vs production).

Для аутентификации используйте `AuthenticationInterceptor` с моделями токенов. Для пользовательских заголовков используйте `HeadersInterceptor`.

### 4. Создайте Network Provider

```swift
let provider = NetworkProvider(config: config)
```

## Простые запросы

Nevod предоставляет готовые типы маршрутов для распространённых HTTP методов:

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

// Стиль async/await с throws
do {
    let user = try await provider.perform(route)
    print("User: \(user.name)")
} catch {
    print("Error: \(error)")
}

// Стиль Result
let result = await provider.request(route)
switch result {
case .success(let user):
    print("User: \(user.name)")
case .failure(let error):
    print("Error: \(error)")
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
        "name": "John Doe",
        "email": "john@example.com"
    ]
)

let response = try await provider.perform(route)
print("Created user with ID: \(response.id)")
```

### PUT запрос

```swift
let route = SimplePutRoute<User, MyDomain>(
    endpoint: "/users/123",
    domain: .api,
    parameters: ["name": "Jane Doe"]
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

## Кастомные маршруты

Для более сложных запросов создайте кастомные маршруты:

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

Nevod предоставляет гибкую generic систему токенов, которая работает с любыми типами токенов.

### Простая Bearer Token аутентификация

#### 1. Реализуйте KeyValueStorage

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

**Примечание**: Для production приложений используйте Keychain вместо UserDefaults для безопасного хранения токенов.

#### 2. Настройте Token Storage

```swift
let storage = UserDefaultsStorage()
let tokenStorage = TokenStorage<Token>(storage: storage)
```

#### 3. Создайте Auth Interceptor

```swift
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: tokenStorage,
    refreshStrategy: { oldToken in
        // Ваша логика обновления токена
        guard let oldToken = oldToken else {
            throw NetworkError.unauthorized
        }
        
        let newTokenValue = try await refreshAccessToken(oldToken.value)
        return Token(value: newTokenValue)
    }
)
```

#### 4. Создайте Provider с аутентификацией

```swift
let provider = NetworkProvider(
    config: config,
    interceptor: authInterceptor
)

// Все запросы теперь будут включать заголовок Authorization
// и автоматически повторяться при 401 с обновлением токена
```

### Кастомные типы токенов (OAuth)

Для более сложных схем аутентификации, таких как OAuth, создайте кастомный тип токена:

```swift
struct OAuthToken: TokenModel, Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
    // Соответствие TokenModel
    func authorize(_ request: inout URLRequest) {
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }
    
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}

// Используйте с хранилищем
let oauthStorage = TokenStorage<OAuthToken>(storage: keychainStorage)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: oauthStorage,
    refreshStrategy: { oldToken in
        guard let oldToken = oldToken else {
            throw NetworkError.unauthorized
        }
        
        // Вызываем endpoint обновления
        let response: OAuthResponse = try await baseClient.request(
            .post,
            path: "/oauth/refresh",
            body: ["refresh_token": oldToken.refreshToken]
        )
        
        return OAuthToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn)
        )
    }
)
```

### Несколько доменов с разной аутентификацией

```swift
// OAuth для api.example.com
let oauthStorage = TokenStorage<OAuthToken>(storage: keychainStorage)
let oauthInterceptor = AuthenticationInterceptor(
    tokenStorage: oauthStorage,
    refreshStrategy: { /* OAuth refresh */ },
    shouldAuthenticate: { request in
        request.url?.host == "api.example.com"
    }
)

// API Key для admin.example.com
struct APIKeyToken: TokenModel, Codable {
    let key: String
    
    func authorize(_ request: inout URLRequest) {
        request.setValue(key, forHTTPHeaderField: "X-API-Key")
    }
    
    func encode() throws -> Data {
        try JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) throws -> Self {
        try JSONDecoder().decode(Self.self, from: data)
    }
}

let apiKeyStorage = TokenStorage<APIKeyToken>(storage: userDefaults)
let apiKeyInterceptor = AuthenticationInterceptor(
    tokenStorage: apiKeyStorage,
    refreshStrategy: { /* API key refresh */ },
    shouldAuthenticate: { request in
        request.url?.host == "admin.example.com"
    }
)

// Объединяем оба interceptor'а
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([oauthInterceptor, apiKeyInterceptor])
)
```

### Полный пример аутентификации

```swift
// 1. Логин
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

// 2. Сохраняем токен
await tokenStorage.save(Token(value: loginResponse.accessToken))

// 3. Все последующие запросы автоматически аутентифицируются
let userRoute = SimpleGetRoute<User, MyDomain>(endpoint: "/users/me", domain: .api)
let user = try await provider.perform(userRoute)
```

## Логирование

### HTTP запросов/ответов (OSLog)

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
- `.detailed` - Добавляет заголовки и коды статуса
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
    print("Success: \(user)")
} catch let error as NetworkError {
    switch error {
    case .unauthorized:
        // Перенаправление на логин
        print("Пользователь не авторизован")
    case .timeout:
        // Показать опцию повтора
        print("Запрос превысил время ожидания")
    case .noConnection:
        // Показать сообщение об отсутствии сети
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

### Определите несколько доменов

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

### Сконфигурируйте несколько URL

```swift
let config = NetworkConfig(
    environments: [
        AppDomains.mainAPI: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!
        ),
        AppDomains.analyticsAPI: SimpleEnvironment(
            baseURL: URL(string: "https://analytics.example.com")!
        ),
        AppDomains.cdn: SimpleEnvironment(
            baseURL: URL(string: "https://cdn.example.com")!
        )
    ]
)
```

### Используйте разные домены

```swift
// Запрос к главному API
let userRoute = SimpleGetRoute<User, AppDomains>(
    endpoint: "/users/me",
    domain: .mainAPI  // → api.example.com
)

// Запрос аналитики
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

## Продвинутые функции

### Объединение нескольких Interceptor'ов

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
            refreshStrategy: { try await refreshToken($0) }
        )
    ])
)
```

**Порядок выполнения**:
1. Logging логирует запрос
2. Headers добавляет кастомные заголовки
3. Auth добавляет заголовок Authorization
4. Запрос отправляется в сеть
5. При 401: Auth обновляет токен и повторяет
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

### Ответ в виде Raw Data

```swift
let route = SimpleGetRoute<Data, MyDomain>(
    endpoint: "/download/file.pdf",
    domain: .api
)

let pdfData = try await provider.perform(route)
// Используйте pdfData напрямую
```

### Task Delegation для отслеживания прогресса

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

1. **Переиспользуйте NetworkProvider**: Создайте один раз, используйте во всём приложении
2. **Чётко определяйте домены**: Используйте значимые идентификаторы доменов
3. **Грамотно обрабатывайте ошибки**: Всегда обрабатывайте случаи NetworkError
4. **Используйте Simple Routes**: Предпочитайте `SimpleGetRoute` и т.д. для стандартных запросов
5. **Кастомные Routes для сложных случаев**: Создавайте кастомные Route только при необходимости
6. **Порядок Interceptor'ов важен**: Ставьте логирование первым, auth последним в цепочке
7. **Переключение окружений**: Создавайте отдельные экземпляры `NetworkConfig` для каждого окружения
8. **Безопасность токенов**: Используйте безопасное хранилище (Keychain) для production токенов
9. **Generic токены**: Определяйте кастомные типы токенов для сложных схем аутентификации
10. **Refresh Strategy**: Держите логику refresh внешней по отношению к моделям токенов

## Следующие шаги

- Изучите [Руководство по установке](./Installation-ru.md) для деталей настройки
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
