## Ключевые недостатки
1. **Ограниченная модель тела запроса.** `Route.parameters` — только `[String: String]`, а `SimplePost/PutRoute` вообще не позволяет использовать `Encodable`, двоичные тела, multipart, streaming. Для 99% сетевых задач нужны хотя бы generics поверх `Encodable`, поддержка `Data`, multipart/form-data и произвольных body builders.【F:Sources/Nevod/Protocols/Route.swift†L24-L91】【F:Sources/Nevod/Routing/SimpleRoutes.swift†L23-L79】
2. **Нет сложных сценариев запросов.** Отсутствуют:
   - загрузка/выгрузка файлов с прогрессом (требуется поддержка `URLSessionTaskDelegate`/streams поверх convenience API);
   - WebSocket/SSE, долгие поллинги, chunked streaming;
   - автоматическое кэширование, conditional requests, ETag/If-None-Match хелперы.
   Без этого сложно покрыть «99% сетевых задач».
3. **Минимальный контроль сериализации ответов.** `NetworkProvider` всегда использует новый `JSONDecoder()` без настройки дат, ключей, стратегии snake_case и т.д., поэтому каждому разработчику придется писать свои маршруты с кастомным `decode`. Нужен dependency injection для энкодеров/декодеров и удобные preconfigured профили.【F:Sources/Nevod/Core/NetworkProvider.swift†L78-L116】
4. **Неполная HTTP-матрица.** Нет поддержки HTTP HEAD/OPTIONS, кастомных методов, ни query массивов, ни вложенных структур. Для API вроде GraphQL или RPC это ограничение.【F:Sources/Nevod/Models/HTTPMethod.swift†L1-L7】【F:Sources/Nevod/Protocols/Route.swift†L24-L91】
5. **Rate limiting и retries плоские.** Провайдер использует один глобальный `RateLimiter` и фиксированное число попыток для всех маршрутов; нет экспоненциальной паузы, политики per-route/domain, ручных backoff hooks. Для высоконагруженных клиентов понадобится конфигурируемый retry policy и per-host лимиты.【F:Sources/Nevod/Core/NetworkProvider.swift†L19-L67】【F:Sources/Nevod/Core/RateLimiter.swift†L1-L46】
6. **DX и порог входа.** Хотя документация хороша, разработчику нужно:
   - объявлять enum доменов и `NetworkConfig`, даже если сервис один;
   - реализовать `KeyValueStorage` и хранение токена самостоятельно (нет готовой Keychain-реализации); 
   - писать свои `Route` для каждого запроса. Это мощно, но не быстро — аналог Alamofire/Moya предлагает декларативные enum-провайдеры и готовые плагины. Порог ≈4/10: разобраться можно, но продуктивность ниже, чем у конкурентов.
7. **Отсутствие готовых сценариев авторизации.** Есть интерцептор, но нет готовых OAuth2 flows (PKCE, Client Credentials), нет SSO/Sign in with Apple интеграций, нет helpers для refresh по расписанию/expiry. Все возлагается на пользователя, что замедляет внедрение сложных auth систем.【F:Sources/Nevod/Interceptors/AuthenticationInterceptor.swift†L13-L94】【F:Docs/ru/Authentication-ru.md†L1-L206】
8. **Инструментирование и дебаг.** Логирование построено на Letopis и требует внешней зависимости. Нет опции полностью отключить логгер или предоставить structured logs без стороннего фреймворка. Для библиотеки, стремящейся к универсальности, разумнее иметь lightweight логгер и интеграцию с os_log напрямую.【F:Sources/Nevod/Core/NetworkProvider.swift†L18-L34】【F:Sources/Nevod/Interceptors/LoggingInterceptor.swift†L1-L48】
9. **Интеграция с async cancellation.** `NetworkProvider` не экспонирует `Task` для запросов, нет утилит вроде `withThrowingTaskGroup` или `AsyncSequence` ответов. Это не критично, но мешает сложным сценариям (конвейеры, параллельные запросы, комбинирование). Разработчику придется строить cancelation поверх `Task { await provider.perform(...) }` вручную.
10. **Недостаток инструментов конфигурации.** `NetworkConfig` хранит только baseURL, timeout, retries. Нет опций для per-route headers, default query params, `URLSessionConfiguration` (cache policy, proxy, TLS pinning), ни удобного DI для JSONEncoder/Decoder, `URLCache`. Это делает библиотеку менее пригодной для enterprise сценариев, где такие настройки обязательны.【F:Sources/Nevod/Core/NetworkConfig.swift†L1-L61】

## Влияние недостатков
Указанные проблемы мешают библиотеке претендовать на 9–10/10:
- Без расширяемого body и encoder-инфраструктуры невозможно работать с gRPC-gateway, GraphQL, multipart загрузками, файлами и стримингом.
- Отсутствие продвинутого retry/rate-limiting и авторизационных flows делает библиотеку рискованной для критичных API.
- Порог входа и DX недостаточно «из коробки»: многие инфраструктурные блоки (storage, logger, encoder, OAuth) нужно писать вручную, что снижает привлекательность для «обычного разработчика».

## Рекомендации для выхода на 9–10/10
1. **Расширить модель `Route`:**
   - добавить generic `associatedtype Body` с протоколом `RequestBodyConvertible` или принимать `Encodable`/`Data`/`URLRequestBuilder`;
   - поддержать multipart/form-data с boundary генерацией и потоковыми телами;
   - разрешить query массивы (`[String: [String]]`) и произвольные типы параметров.
2. **Ввести конфигурируемые кодировщики/декодеры.** Передавать `JSONEncoder/Decoder`, `DateDecodingStrategy`, `KeyDecodingStrategy` в `NetworkConfig` или `Route`. Это снимет необходимость переписывать `decode` для каждой модели.
3. **Развить retries и rate limiting.** Поддержать стратегию backoff (exponential/jitter), per-host/per-route конфиги, интеграцию с HTTP Retry-After. Сделать rate limiter композитным и позволить прокинуть свои реализации.
4. **Добавить готовые плагины авторизации.** Реализовать OAuth2 (Authorization Code + PKCE, Client Credentials), Signed URL/Query, JWT refresh по expiry, интеграцию с ASWebAuthenticationSession. Предоставить готовые storage адаптеры: Keychain, EncryptedStorage.
5. **Улучшить DX:** шаблоны для одного домена, генераторы маршрутов, макросы или DSL, чтобы описывать endpoints декларативно; готовые имплементации `KeyValueStorage`; удобные shortcuts вроде `provider.get(_:query:)`, `provider.post(_:body:)`.
6. **Расширить HTTP функциональность.** Добавить WebSocket клиент, SSE, download/upload tasks с прогрессом, поддержку `URLSessionConfiguration` (cachePolicy, allowsCellularAccess, waitsForConnectivity, TLS pinning).
7. **Интеграция с Swift concurrency.** Возвращать `URLSessionTask`/`Task` для отмены, предложить `AsyncSequence` для stream-ответов, добавить вспомогательные функции `parallel`/`batch` запросов.
8. **Документация: advanced guides.** Помимо QuickStart, нужны рецепты для multipart загрузки, error mapping, конфигураций разных окружений, best practices для rate limiting и авторизации с несколькими сервисами.
9. **Тестовое покрытие сложных кейсов.** Добавить тесты на retry/backoff, одновременные refresh/login (stress), multipart body, декодирование кастомных энкодеров, сохранение токена в разных хранилищах.
