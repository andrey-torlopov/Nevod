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
  <b>Современный, легковесный и гибкий сетевой слой для Swift</b>
</p>

<p align="center">
  <a href="README.md">English version</a>
</p>

## Обзор

Nevod — это библиотека для работы с сетью в Swift, разработанная с упором на простоту и гибкость. Построена на современном Swift concurrency (async/await) и actor-based архитектуре для потокобезопасности.

## Ключевые особенности

- **Простой API** - Минимум шаблонного кода для базовых запросов
- **Паттерн Interceptor** - Гибкая middleware для адаптации запросов и retry-логики
- **Множественные методы авторизации** - Bearer токены, Cookie, API ключи (заголовок и query)
- **Generic система токенов** - Типобезопасная аутентификация с любыми типами токенов
- **Автообновление токенов** - Встроенная поддержка OAuth с кастомными стратегиями refresh
- **Множественные сервисы** - Легкое управление различными API endpoint'ами
- **Типобезопасность** - Protocol-oriented дизайн с полной типобезопасностью
- **Современный Swift** - async/await и actor-based concurrency
- **Логирование** - Интегрированное логирование запросов/ответов через OSLog

## Быстрый старт

```swift
import Nevod

// 1. Определяем домен сервиса
enum MyDomain: ServiceDomain {
    case api
    var identifier: String { "api" }
}

// 2. Конфигурируем
let config = NetworkConfig(
    environments: [
        MyDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!
        )
    ]
)

// 3. Создаем провайдер
let provider = NetworkProvider(config: config)

// 4. Делаем запрос
let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

let user = try await provider.perform(route)
```

## Установка

**Swift Package Manager:**

```swift
dependencies: [
    .package(url: "https://github.com/andrey-torlopov/Nevod.git", from: "0.0.4")
]
```

См. [Руководство по установке](./Docs/ru/Installation.md) для деталей.

## Документация

- **[Руководство по быстрому старту](./Docs/ru/QuickStart.md)** - Начните за несколько минут
- **[Руководство по аутентификации](./Docs/ru/Authentication.md)** - Bearer, Cookie, API Key авторизация
- **[Установка](./Docs/ru/Installation.md)** - Настройка и зависимости

## Пример аутентификации

```swift
// Bearer Token
let storage = TokenStorage<Token>(storage: keychain)
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: storage,
    refreshStrategy: { oldToken in
        let newToken = try await refreshToken(oldToken?.value)
        return Token(value: newToken)
    }
)

let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

## Встроенные типы токенов

- `Token` - Bearer токен (Authorization заголовок)
- `CookieToken` - Аутентификация на основе сессий
- `APIKeyToken` - API ключ в кастомном заголовке
- `QueryAPIKeyToken` - API ключ как параметр URL

## Требования

- iOS 17.0+ / macOS 15.0+
- Swift 6.2+
- Xcode 16.0+

## Зависимости

- [Letopis](https://github.com/andrey-torlopov/Letopis) - Структурированное логирование

## Лицензия

MIT License - см. файл [LICENSE](./LICENSE) для деталей

## Вклад в проект

Вклад приветствуется! Пожалуйста, не стесняйтесь отправлять Pull Request.
