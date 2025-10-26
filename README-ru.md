# Nevod

<p align="center">
  <img src="Docs/banner.png" alt="Баннер Nevod" width="600"/>
</p>

<p align="center">
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-6.1+-orange.svg?logo=swift" />
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
- **Поддержка OAuth** - Встроенная обработка автоматического обновления токенов
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
- `AuthenticationInterceptor` - управление OAuth токенами
- `LoggingInterceptor` - логирование HTTP запросов/ответов
- `HeadersInterceptor` - добавление кастомных заголовков
- `InterceptorChain` - объединение нескольких interceptor'ов

### Network Provider (Сетевой провайдер)
Actor-based исполнитель сетевых запросов с автоматическими повторными попытками и обработкой ошибок.

## Паттерны использования

### Базовый запрос
```swift
let route = SimpleGetRoute<User, MyDomain>(endpoint: "/users/me", domain: .api)
let user = try await provider.perform(route)
```

### С аутентификацией
```swift
let provider = NetworkProvider(
    config: config,
    interceptor: AuthenticationInterceptor(
        tokenStorage: tokenStorage,
        refreshToken: { try await authService.refreshToken() }
    )
)
```

### Несколько Interceptor'ов
```swift
let provider = NetworkProvider(
    config: config,
    interceptor: InterceptorChain([
        LoggingInterceptor(logger: logger, logLevel: .verbose),
        HeadersInterceptor(headers: ["User-Agent": "MyApp/1.0"]),
        AuthenticationInterceptor(tokenStorage: tokenStorage, refreshToken: refreshBlock)
    ])
)
```

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
