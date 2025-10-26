# Руководство по установке

[English version](./Installation.md)

Это руководство охватывает установку Nevod и его зависимостей в ваш проект.

## Требования

- **iOS**: 17.0 или новее
- **macOS**: 15.0 или новее
- **Swift**: 6.1 или новее
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
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/yourusername/Nevod.git", from: "1.0.0")
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

### 1. Модуль Core
**Назначение**: Предоставляет базовые утилиты и конфигурацию окружения

**Репозиторий**: Локальный модуль (часть того же workspace)

**Возможности**:
- Enum `Environment` (test/production)
- Определения базовых протоколов
- Общие утилиты

### 2. Модуль Storage
**Назначение**: Абстракция хранилища ключ-значение для сохранения токенов

**Репозиторий**: Локальный модуль (часть того же workspace)

**Возможности**:
- Протокол `KeyValueStorage`
- Реализация `UserDefaultsStorage`
- Потокобезопасные операции с хранилищем

**Использование в Nevod**:
```swift
import Storage

let storage = UserDefaultsStorage()
let tokenStorage = TokenStorage(storage: storage)
```

### 3. Letopis
**Назначение**: Фреймворк структурированного логирования для внутренних событий

**Репозиторий**: [https://github.com/andrey-torlopov/Letopis](https://github.com/andrey-torlopov/Letopis)

**Версия**: 0.0.9 или новее

**Возможности**:
- Система логирования на основе событий
- Поддержка множественных interceptor'ов
- Структурированные метаданные payload
- Вывод в консоль, файл и кастомные места

**Использование в Nevod**:
```swift
import Letopis

let logger = Letopis(interceptors: [
    ConsoleInterceptor()
])

let provider = NetworkProvider(
    config: config,
    logger: logger  // Опционально
)
```

**Примечание**: Letopis опционален. Вы можете передать `nil` в качестве параметра logger, если вам не нужно внутреннее логирование.

## Граф зависимостей

```
┌─────────────────┐
│     Nevod       │
└────────┬────────┘
         │
         ├─────────────────────────────────┐
         │                                 │
         v                                 v
┌─────────────────┐              ┌─────────────────┐
│      Core       │              │    Storage      │
│                 │              │                 │
│ - Environment   │              │ - KeyValueStorage│
│ - Utilities     │              │ - UserDefaults  │
└─────────────────┘              └─────────────────┘
         │
         v
┌─────────────────┐
│    Letopis      │
│                 │
│ - Logging       │
│ - Interceptors  │
└─────────────────┘
```

## Импорт модулей

В ваших Swift файлах:

```swift
import Nevod           // Основная функциональность сети
import Storage         // Если используете TokenStorage
import Letopis         // Если используете логирование
import Core            // Если используете Environment
```

## Минимальная настройка

Вот минимальный код для начала работы:

```swift
import Nevod
import Core
import Storage

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

## Опционально: Настройка локального пакета

Если вы разрабатываете Nevod локально или используете его как локальный пакет:

### Структура файлов
```
YourProject/
├── LocalSPM/
│   └── Core/
│       ├── Core/         # Модуль Core
│       ├── Storage/      # Модуль Storage
│       └── Nevod/        # Модуль Nevod
└── YourApp/
    └── Package.swift
```

### Package.swift для локальной разработки

```swift
let package = Package(
    name: "YourApp",
    dependencies: [
        .package(path: "../LocalSPM/Core/Nevod")
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
1. Проверьте совместимость версии Swift (требуется 6.1+)
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
- [API Reference](./API.md) - Исследуйте все возможности
- [Примеры](../Examples/) - Посмотрите реальные примеры

## Совместимость версий

| Версия Nevod | iOS    | macOS  | Swift | Xcode  |
|--------------|--------|--------|-------|--------|
| 1.0.0+       | 17.0+  | 15.0+  | 6.1+  | 16.0+  |

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
