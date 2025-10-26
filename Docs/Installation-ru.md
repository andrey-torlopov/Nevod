# Руководство по установке

[English version](./Installation.md)

Это руководство охватывает установку Nevod и его зависимостей в ваш проект.

## Требования

- **iOS**: 17.0 или новее
- **macOS**: 15.0 или новее
- **Swift**: 6.2 или новее
- **Xcode**: 16.0 или новее

## Способы установки

### Swift Package Manager (Рекомендуется)

#### Вариант 1: Через интерфейс Xcode

1. Откройте ваш проект в Xcode
2. Перейдите в `File` → `Add Package Dependencies...`
3. Введите URL репозитория:
   ```
   https://github.com/yourusername/Nevod.git
   ```
4. Выберите правило версии (рекомендуется: "Up to Next Major Version")
5. Нажмите `Add Package`

#### Вариант 2: Package.swift

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
        .package(url: "https://github.com/yourusername/Nevod.git", from: "0.0.1")
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

Nevod требует следующие зависимости, которые будут автоматически установлены через SPM:

### Letopis (структурированное логирование)
**Назначение**: фреймворк структурированного логирования для внутренних событий

**Репозиторий**: [https://github.com/andrey-torlopov/Letopis](https://github.com/andrey-torlopov/Letopis)

**Версия**: 0.0.10 или новее

**Возможности**:
- Система логирования на основе событий
- Поддержка нескольких interceptor'ов
- Структурированные метаданные
- Вывод в консоль, файл и кастомные каналы

Используйте `import Letopis`, когда передаёте собственный логгер в `NetworkProvider`.

## Граф зависимостей

```
┌─────────────────┐
│     Nevod       │
└────────┬────────┘
         │
         v
┌─────────────────┐
│    Letopis      │
└─────────────────┘
```

## Импорт модулей

В ваших Swift файлах:

```swift
import Nevod           // Основная работа с сетью
// Опционально
import Letopis         // Для передачи кастомного логгера
```

## Минимальная настройка

Вот минимальный код для начала работы:

```swift
import Nevod

// 1. Определяем домен сервиса
enum MyDomain: ServiceDomain {
    case api

    var identifier: String {
        switch self {
        case .api: return "api"
        }
    }
}

// 2. Создаем конфигурацию сети
let config = NetworkConfig(
    environments: [
        MyDomain.api: SimpleEnvironment(
            baseURL: URL(string: "https://api.example.com")!,
            apiKey: "secret-key",
            headers: ["X-Client-Version": "1.0"]
        )
    ],
    timeout: 30,
    retries: 3
)

// 3. Создаем network provider
let provider = NetworkProvider(config: config)

// 4. Определяем route
let route = SimpleGetRoute<User, MyDomain>(
    endpoint: "/users/me",
    domain: .api
)

// 5. Выполняем запрос
let user = try await provider.perform(route)
```

`SimpleEnvironment` входит в состав Nevod и реализует `NetworkEnvironmentProviding`. При необходимости замените его собственной реализацией для переключения окружений.

## Настройка хранилища токенов (Опционально)

Nevod включает встроенную поддержку хранения токенов. Для использования реализуйте протокол `KeyValueStorage`:

```swift
import Nevod

// Пример: хранилище на основе UserDefaults
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

// Использование с TokenStorage
let storage = UserDefaultsStorage()
let tokenStorage = TokenStorage<Token>(storage: storage)

// Настройка interceptor'а аутентификации
let authInterceptor = AuthenticationInterceptor(
    tokenStorage: tokenStorage,
    refreshStrategy: { oldToken in
        // Ваша логика обновления токена
        let newValue = try await refreshTokenAPI(oldToken?.value)
        return Token(value: newValue)
    }
)

let provider = NetworkProvider(config: config, interceptor: authInterceptor)
```

Для production приложений рекомендуется использовать Keychain для безопасного хранения токенов вместо UserDefaults.

## Опционально: Настройка локального пакета

Если вы разрабатываете Nevod локально или используете его как локальный пакет:

### Структура файлов
```
YourProject/
├── LocalPackages/
│   └── Nevod/
└── YourApp/
    └── Package.swift
```

### Package.swift для локальной разработки

```swift
let package = Package(
    name: "YourApp",
    dependencies: [
        .package(path: "../LocalPackages/Nevod")
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

## Решение проблем

### Проблема: "No such module 'Nevod'"

**Решение**:
1. Очистите папку сборки: `Product` → `Clean Build Folder` (Cmd+Shift+K)
2. Сбросьте кеш пакетов: `File` → `Packages` → `Reset Package Caches`
3. Обновите пакеты: `File` → `Packages` → `Update to Latest Package Versions`

### Проблема: Не удалось разрешить зависимости

**Решение**:
1. Проверьте совместимость версии Swift (требуется 6.2+)
2. Проверьте требования платформы (iOS 17+, macOS 15+)
3. Проверьте синтаксис Package.swift
4. Очистите derived data: `~/Library/Developer/Xcode/DerivedData`

### Проблема: Ошибки сборки после обновления

**Решение**:
```bash
# Очистка и пересборка
swift package clean
swift package update
swift build
```

## Следующие шаги

- [Руководство по быстрому старту](./QuickStart-ru.md) - Изучите базовое использование
- [Примеры](../Examples/) - Посмотрите реальные примеры

## Совместимость версий

| Версия Nevod | iOS    | macOS  | Swift | Xcode  |
|--------------|--------|--------|-------|--------|
| 1.0.0+       | 17.0+  | 15.0+  | 6.2+  | 16.0+  |

## Получение помощи

Если вы столкнулись с проблемами:
1. Проверьте это руководство по установке
2. Изучите [Быстрый старт](./QuickStart-ru.md)
3. Поищите в [GitHub Issues](https://github.com/yourusername/Nevod/issues)
4. Откройте новую issue с:
   - Вашим окружением (версия iOS/macOS, версия Xcode)
   - Конфигурацией Package.swift
   - Сообщениями об ошибках
   - Шагами для воспроизведения
