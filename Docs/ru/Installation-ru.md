# Руководство по установке

[English version](../en/Installation.md)

Это руководство охватывает установку Nevod и его зависимостей в ваш проект.

## Требования

- **iOS**: 17.0 или новее
- **macOS**: 15.0 или новее
- **Swift**: 6.2 или новее
- **Xcode**: 16.0 или новее

## Swift Package Manager

### Вариант 1: Через интерфейс Xcode

1. Откройте ваш проект в Xcode
2. Перейдите в `File` → `Add Package Dependencies...`
3. Введите URL репозитория:
   ```
   https://github.com/andrey-torlopov/Nevod.git
   ```
4. Выберите правило версии (рекомендуется: "Up to Next Major Version")
5. Нажмите `Add Package`

### Вариант 2: Package.swift

Добавьте Nevod в ваш файл `Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "git@github.com:andrey-torlopov/Nevod.git", from: "0.0.2")
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "Nevod", package: "Nevod")
            ]
        )
    ]
)
```

Затем выполните:
```bash
swift package update
```

## Зависимости

Nevod автоматически устанавливает свои зависимости через SPM:

### Letopis (Структурированное логирование)

**Репозиторий**: [https://github.com/andrey-torlopov/Letopis](https://github.com/andrey-torlopov/Letopis)

**Версия**: 0.0.10 или новее

**Назначение**: Логирование внутренних событий NetworkProvider

Используйте `import Letopis`, только если хотите передать собственный логгер в `NetworkProvider`.

## Минимальная настройка

```swift
import Nevod

// 1. Определяем домен сервиса
enum MyDomain: ServiceDomain {
    case api
    
    var identifier: String { "api" }
}

// 2. Создаем конфигурацию
let config = NetworkConfig(
    environments: [
        MyDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!
        )
    ],
    timeout: 30,
    retries: 3
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

## Следующие шаги

- [Руководство по быстрому старту](./QuickStart.md) - Изучите основы
- [Руководство по аутентификации](./Authentication.md) - Настройте авторизацию по токенам
- [Продвинутое использование](./Advanced.md) - Interceptor'ы, множественные сервисы, кастомные routes

## Решение проблем

### "No such module 'Nevod'"

1. Очистите сборку: `Product` → `Clean Build Folder` (Cmd+Shift+K)
2. Сбросьте кеш: `File` → `Packages` → `Reset Package Caches`
3. Обновите пакеты: `File` → `Packages` → `Update to Latest Package Versions`

### Не удалось разрешить зависимости

1. Проверьте версию Swift (требуется 6.2+)
2. Проверьте требования платформы (iOS 17+, macOS 15+)
3. Очистите derived data: `~/Library/Developer/Xcode/DerivedData`

### Ошибки сборки после обновления

```bash
swift package clean
swift package update
swift build
```
