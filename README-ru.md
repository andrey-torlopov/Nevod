# Nevod

<p align="center">
  <img src="Docs/banner.png" alt="Баннер Nevod" width="600"/>
</p>

<p align="center">
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg?logo=swift" />
  </a>
  <a href="https://swift.org/package-manager/">
    <img src="https://img.shields.io/badge/SPM-compatible-green.svg" />
  </a>
  <img src="https://img.shields.io/badge/platforms-iOS%2017.0+%20|%20macOS%2015.0+-blue.svg" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-lightgrey.svg" />
  </a>
</p>

<p align="center">
  <b>Современный, легковесный и гибкий сетевой слой для Swift с поддержкой паттерна interceptor.</b>
</p>

<p align="center">
  <a href="README.md">English version</a>
</p>

## Обзор

Nevod — это библиотека для работы с сетью в Swift, разработанная с упором на простоту и гибкость. Она предоставляет чистый API для базовых запросов, одновременно предлагая мощные возможности, такие как interceptor'ы, поддержка множественных сервисов и автоматическое обновление токенов для продвинутых сценариев использования.

Построена на современном Swift concurrency (async/await) и actor-based архитектуре для потокобезопасности.

## Ключевые особенности

- **Простой API** - Минимум шаблонного кода для базовых запросов
- **Паттерн Interceptor** - Гибкая система middleware для адаптации запросов и retry-логики
- **Множественные сервисы** - Легкое управление различными API endpoint'ами
- **Generic система токенов** - Гибкая аутентификация с любыми типами токенов
- **Поддержка OAuth** - Встроенная обработка автоматического обновления токенов с кастомными стратегиями
- **Типобезопасность** - Protocol-oriented дизайн с полной типобезопасностью
- **Современный Swift** - async/await и actor-based concurrency
- **Тестируемость** - Архитектура, дружественная к dependency injection
- **Логирование** - Интегрированная поддержка логирования запросов/ответов через OSLog и Letopis

## Быстрый пример

```swift
// Определяем домен сервиса
enum MyDomain: ServiceDomain {
    case api
    var identifier: String { "api" }
}

// Создаем простой GET запрос
let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

// Выполняем запрос
let user = try await provider.perform(route)
```

## Установка

См. [Руководство по установке](./Docs/Installation-ru.md) для подробных инструкций.

**Swift Package Manager:**

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Nevod.git", from: "0.0.1")
]
```

## Документация

- [Быстрый старт](./Docs/QuickStart-ru.md) - Начните работу за несколько минут
- [Установка](./Docs/Installation-ru.md) - Подробная установка и зависимости
- [API Reference](./Docs/API.md) - Полная документация API

## Основные компоненты

### Routes (Маршруты)
Определяйте API endpoint'ы с типобезопасными маршрутами:
- Протокол `Route` для кастомных endpoint'ов
- `SimpleGetRoute`, `SimplePostRoute`, `SimplePutRoute`, `SimpleDeleteRoute` для типичных случаев

### Interceptors (Перехватчики)
Модифицируйте запросы и обрабатывайте повторные попытки:
- `AuthenticationInterceptor<Token>` - Generic управление токенами с кастомными стратегиями refresh
- `LoggingInterceptor` - логирование HTTP запросов/ответов
- `HeadersInterceptor` - добавление кастомных заголовков
- `InterceptorChain` - объединение нескольких interceptor'ов

### Система токенов
Гибкая аутентификация с любыми типами токенов:
- Протокол `TokenModel` - Определите свои типы токенов
- `TokenStorage<Token>` - Generic хранилище токенов
- Встроенный `Token` - Простая реализация Bearer токена

### Network Provider (Сетевой провайдер)
Actor-based исполнитель сетевых запросов с автоматическими повторными попытками и обработкой ошибок.

## Паттерны использования

### Базовый запрос
```swift
let route = SimpleGetRoute<User, MyDomain>(endpoint: "/users/me", domain: .api)
let user = try await provider.perform(route)
```

### С простым Bearer токеном
```swift
// Создаем хранилище токенов
let storage = TokenStorage<Token>(storage: myKeyValueStorage)

// Создаем interceptor аутентификации
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        // Ваша логика обновления токена
        let newTokenValue = try await authService.refreshToken(oldToken?.value)
        return Token(value: newTokenValue)
    }
)

let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

### С кастомным типом токена (OAuth)
```swift
// Определяем свой токен
struct OAuthToken: TokenModel, Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
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

// Используем с хранилищем и interceptor'ом
let storage = TokenStorage<OAuthToken>(storage: myStorage)
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        guard let oldToken = oldToken else { throw NetworkError.unauthorized }
        
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
    shouldAuthenticate: { $0.url?.host == "api.example.com" }
)

// API Key для admin.example.com
let apiKeyStorage = TokenStorage<APIKeyToken>(storage: userDefaults)
let apiKeyInterceptor = AuthenticationInterceptor(
    tokenStorage: apiKeyStorage,
    refreshStrategy: { /* API key refresh */ },
    shouldAuthenticate: { $0.url?.host == "admin.example.com" }
)

// Объединяем оба
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([oauthInterceptor, apiKeyInterceptor])
)
```

### Несколько Interceptor'ов
```swift
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        LoggingInterceptor(logger: logger, logLevel: .verbose),
        HeadersInterceptor(headers: ["User-Agent": "MyApp/1.0"]),
        AuthenticationInterceptor(tokenStorage: storage, refreshStrategy: refreshBlock)
    ])
)
```

## Преимущества архитектуры

✅ **Разделение ответственности** - Модели токенов, хранение и логика refresh разделены  
✅ **Гибкость** - Поддержка любых типов токенов через протоколы  
✅ **Масштабируемость** - Несколько interceptor'ов для разных доменов  
✅ **Типобезопасность** - Строгая типизация через generics  
✅ **Тестируемость** - Легко мокировать хранилище и стратегии refresh  
✅ **Чистая архитектура** - Внешний код настраивает поведение  

## Требования

- iOS 17.0+ / macOS 15.0+
- Swift 6.2+
- Xcode 16.0+

## Зависимости

- [Letopis](https://github.com/andrey-torlopov/Letopis) - Фреймворк структурированного логирования

## Лицензия

MIT License - см. файл [LICENSE](./LICENSE) для деталей

## Вклад в проект

Вклад приветствуется! Пожалуйста, не стесняйтесь отправлять Pull Request.
