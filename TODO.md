# TODO

## Критические
- [ ] Исправить `EncodableRoute`: не проглатывать ошибки при кодировании тела; вернуть ошибку `.bodyEncodingFailed` вместо продолжения запроса при неудачном `JSONEncoder.encode` (см. `Sources/Nevod/Protocols/EncodableRoute.swift`).
- [ ] Разрешить осознанно отправлять пустое тело: в `Route.makeRequest` различать `nil` и `Data()` и не считать пустое тело фатальной ошибкой (см. `Sources/Nevod/Protocols/Route.swift`).
- [ ] Учитывать `bodyEncoder` маршрута: использовать кастомный `JSONEncoder` из `EncodableRoute`, а не всегда `config.jsonEncoder`; покрыть тестами формат дат/ключей (см. `EncodableRoute.swift`, `Route.swift`).
- [ ] Перевести `RateLimiter` на монотонное время (`ContinuousClock`/`DispatchTime`), чтобы скачки системных часов не ломали лимиты; добавить тесты на изменение wall-clock (см. `Sources/Nevod/Core/RateLimiter.swift`).
- [ ] При работе с delegate сохранять всю конфигурацию `URLSession` на Linux: не терять кеш, protocol classes, cookie storage и т. п.; покрыть сценарий с кастомной конфигурацией (см. `Sources/Nevod/Protocols/URLSessionProtocol.swift`).
