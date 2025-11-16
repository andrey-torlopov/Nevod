# Руководство по аутентификации

[English version](../en/Authentication.md)

Nevod предоставляет гибкую generic систему токенов, которая поддерживает множественные методы аутентификации из коробки.

## Обзор

Система аутентификации Nevod основана на:
- **TokenModel** протокол - Определите любой тип токена
- **TokenStorage<Token>** - Generic, типобезопасное хранилище токенов
- **AuthenticationInterceptor<Token>** - Автоматическая вставка токена и обновление
- **CookieAuthenticationInterceptor** - Специализированное управление сессиями на основе cookie

## Встроенные типы токенов

### 1. Bearer Token

Стандартная OAuth 2.0 Bearer token аутентификация.

```swift
import Nevod

// Создаем токен
let token = Token(value: "your-access-token")

// Настраиваем хранилище
let storage = TokenStorage<Token>(storage: keychain)
await storage.save(token)

// Создаем auth interceptor
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        guard let oldToken = oldToken else {
            throw NetworkError.unauthorized
        }
        
        // Вызываем ваш refresh endpoint
        let response: RefreshResponse = try await authService.refresh(oldToken.value)
        return Token(value: response.accessToken)
    }
)

// Создаем provider
let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

**Как это работает:**
- Добавляет заголовок `Authorization: Bearer {token}` к запросам
- При ошибке 401 вызывает refreshStrategy
- Повторяет запрос с новым токеном
- Дедуплицирует конкурентные вызовы refresh

### 2. Cookie аутентификация

Аутентификация на основе сессий с использованием HTTP cookies.

```swift
import Nevod

let cookieStorage = TokenStorage<CookieToken>(storage: keychain)

let cookieInterceptor = CookieAuthenticationInterceptor(
    cookieStorage: cookieStorage,
    loginStrategy: {
        // Ваша логика логина
        let credentials = ["email": email, "password": password]
        let loginURL = URL(string: "https://api.example.com/login")!
        
        // Выполняем логин
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(credentials)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        // Извлекаем cookies
        if let httpResponse = response as? HTTPURLResponse,
           let cookies = HTTPCookie.cookies(withResponseHeaderFields: 
               httpResponse.allHeaderFields as? [String: String] ?? [:],
               for: loginURL) {
            return CookieToken(sessionCookies: cookies)
        }
        
        throw NetworkError.unauthorized
    }
)

let provider = NetworkProvider(config: config, interceptor: cookieInterceptor)
```

**Сценарии использования:**
- Традиционные веб-API
- Сервисы без поддержки OAuth
- Легаси системы
- API вроде Space-Track.org

### 3. API Key (в заголовке)

API ключ передается в кастомном заголовке.

```swift
import Nevod

let apiKeyToken = APIKeyToken(
    apiKey: "your-api-key-12345",
    headerName: "X-API-Key"  // Настройте имя заголовка
)

let storage = TokenStorage<APIKeyToken>(storage: userDefaults)
await storage.save(apiKeyToken)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { _ in
        // API ключи обычно не обновляются
        throw NetworkError.unauthorized
    }
)

let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

**Сценарии использования:**
- OpenWeatherMap
- NewsAPI
- Многие публичные API

### 4. API Key (параметр запроса)

API ключ передается как параметр URL запроса.

```swift
import Nevod

let queryToken = QueryAPIKeyToken(
    apiKey: "your-api-key-12345",
    paramName: "api_key"  // или "key", "apikey" и т.д.
)

let storage = TokenStorage<QueryAPIKeyToken>(storage: userDefaults)
await storage.save(queryToken)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { _ in throw NetworkError.unauthorized }
)

// Запросы к /users?limit=10 станут /users?limit=10&api_key=your-api-key-12345
let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

**Сценарии использования:**
- Google Maps API
- Некоторые погодные сервисы
- API, требующие auth через query

## Кастомные типы токенов

Создайте свой тип токена для сложных схем аутентификации:

```swift
import Nevod

struct OAuthToken: TokenModel, Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
    // TokenModel conformance
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

// Использование
let storage = TokenStorage<OAuthToken>(storage: keychain)

let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        guard let oldToken = oldToken else {
            throw NetworkError.unauthorized
        }
        
        // Вызываем OAuth refresh endpoint
        let response: OAuthResponse = try await oauthService.refresh(
            refreshToken: oldToken.refreshToken
        )
        
        return OAuthToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn)
        )
    }
)
```

## Реализация KeyValueStorage

### UserDefaults (Разработка)

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

### Keychain (Production)

Полный пример реализации Keychain смотрите в [английской версии](../en/Authentication.md).

## Множественные методы аутентификации

Используйте разную аутентификацию для разных доменов:

```swift
enum AppDomains: ServiceDomain {
    case mainAPI      // OAuth
    case adminAPI     // API Key
    case legacyAPI    // Cookie
    
    var identifier: String {
        switch self {
        case .mainAPI: return "main"
        case .adminAPI: return "admin"
        case .legacyAPI: return "legacy"
        }
    }
}

// OAuth для главного API
let oauthStorage = TokenStorage<OAuthToken>(storage: keychain)
let oauthInterceptor = AuthenticationInterceptor(
    tokenStorage: oauthStorage,
    refreshStrategy: { /* OAuth refresh */ },
    shouldAuthenticate: { $0.url?.host == "api.example.com" }
)

// API Key для admin
let apiKeyStorage = TokenStorage<APIKeyToken>(storage: keychain)
let apiKeyInterceptor = AuthenticationInterceptor(
    tokenStorage: apiKeyStorage,
    refreshStrategy: { _ in throw NetworkError.unauthorized },
    shouldAuthenticate: { $0.url?.host == "admin.example.com" }
)

// Cookie для legacy
let cookieStorage = TokenStorage<CookieToken>(storage: keychain)
let cookieInterceptor = CookieAuthenticationInterceptor(
    cookieStorage: cookieStorage,
    loginStrategy: { /* логика логина */ },
    shouldAuthenticate: { $0.url?.host == "legacy.example.com" }
)

// Объединяем все
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        oauthInterceptor,
        apiKeyInterceptor,
        cookieInterceptor
    ])
)
```

## Пример Login Flow

```swift
class AuthService {
    private let provider: NetworkProvider
    private let tokenStorage: TokenStorage<Token>
    
    init(provider: NetworkProvider, tokenStorage: TokenStorage<Token>) {
        self.provider = provider
        self.tokenStorage = tokenStorage
    }
    
    func login(email: String, password: String) async throws {
        let route = SimplePostRoute<LoginResponse, MyDomain>(
            endpoint: "/auth/login",
            domain: .api,
            parameters: ["email": email, "password": password]
        )
        
        let response = try await provider.perform(route)
        
        // Сохраняем токен
        let token = Token(value: response.accessToken)
        await tokenStorage.save(token)
    }
    
    func logout() async {
        await tokenStorage.clear()
    }
    
    func isAuthenticated() async -> Bool {
        await tokenStorage.load() != nil
    }
}
```

## Лучшие практики

1. **Используйте Keychain для production** - Никогда не храните токены в UserDefaults для production приложений
2. **Очищайте токены при logout** - Вызывайте `await tokenStorage.clear()`
3. **Обрабатывайте ошибки refresh** - Показывайте экран логина при неудаче refresh
4. **Дедупликация запросов** - TokenStorage и interceptor'ы обрабатывают это автоматически
5. **Кастомные типы токенов** - Создавайте свой TokenModel для сложных схем
6. **Тестируйте логику refresh** - Мокируйте refresh strategy в тестах
7. **Безопасное хранилище** - Используйте Keychain с правильным контролем доступа
8. **Срок действия токена** - Включайте expiry в кастомные типы токенов
9. **Конкурентная безопасность** - Все операции изолированы через actor

## См. также

- [Руководство по быстрому старту](./QuickStart-ru.md)
- [Установка](./Installation-ru.md)
