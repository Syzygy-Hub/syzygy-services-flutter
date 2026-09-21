# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-09-19

### Fixed
- `WebSocketProvider`: `_scheduleReconnect()` guards `_disposed` flag before and after delay — no reconnect after disposal
- `WebSocketProvider`: `StreamSubscription` stored and cancelled on disconnect/dispose — no more leaked subscriptions
- Header redaction is now case-insensitive and covers `authorization`, `cookie`, `x-api-key`, `proxy-authorization`

### Changed
- `TokenAuthProvider` depends only on Foundation `StorageProvider` abstract type — concrete dependencies removed
- `TokenAuthProvider` secure storage injection documented — caller must inject a secure-backed implementation
- `RemoteConfigProvider`: logs warn on fetch failure, info on recovery
- `flutter_lints` updated to ^6.0.0
- `verbose()` dispatches as `debug` until Foundation adds `LogLevel.verbose` — documented in CHANGELOG
- Canonical backoff policy: 500ms base, 2.0× multiplier, full jitter, 8 000ms cap, max 3 retries
- Foundation dependency updated to ^1.2.0

## [1.1.0] - 2026-09-13

### Added

- **DeviceServices** — `IoDeviceProvider.deviceId` now persists via `StorageProvider` under key `syzygy.device.uuid`; UUID is never regenerated once stored
- **Persistence** — `InMemoryStorageProvider.get<T>()` and `getSecure<T>()` now throw `StateError` with a descriptive message (key name, stored type, requested type) on type mismatch instead of silently returning null
- **NetworkClient** — `HttpNetworkClient` accepts an optional `LoggerProtocol? logger` parameter; logs request (method, URL, safe headers, body size), response (status, elapsed ms, body size), and errors; null logger incurs zero overhead
- **Analytics** — `InMemoryAnalyticsProvider` and `ConsoleAnalyticsProvider` inject `session_id` into every tracked event's properties; `reset()` generates a fresh session UUID
- **CrashReporting** — `CrashReporter` abstract class gains `leaveBreadcrumb(String, {Map<String,String>?})` and `clearBreadcrumbs()`; new `InMemoryCrashReporter` stores the last 20 breadcrumbs in a circular buffer and includes a snapshot in each crash report; `Breadcrumb` value type added
- Networking retry integration tests with mock HttpClient call counting
- Auth real token-refresh flow wired to NetworkClient with auto-refresh on expired JWT
- RemoteConfig cache TTL support (cacheTtlSeconds, default 3600)
- WebSocket binary send integration tests (Uint8List send/receive, mixed text+binary)
- PushNotifications FCM/APNs integration documentation and NotificationPayload factory helpers
- Contract compliance tests verifying all service implementations satisfy Foundation contracts
- `WebSocketProvider.binaryMessages` — `Stream<Uint8List>` aligned with Android's `binaryMessages: Flow<ByteArray>`; `InMemoryWebSocketProvider` and `DartWebSocketProvider` both implement the new typed binary stream
- `BackoffClock` typedef and injectable `backoffClock` parameter on `HttpNetworkClient`; enables deterministic backoff tests without real wall-clock delays, mirroring the Android clock-injection pattern
- PushNotifications section in README covering FCM/APNs integration, factory helpers, and test usage

### Changed

- RetryDelay typedef renamed to BackoffClock; RecordingBackoffClock made public for cross-platform naming consistency

### Fixed

- `dispose()` added to `HttpNetworkClient`, `DartWebSocketProvider`, `InMemoryWebSocketProvider`
- README install snippet version corrected to 1.1.0
- README version badge corrected to 1.1.0
- README banner updated to match cross-repo standard
- README modules table class names updated to v1.1.0 implementations

## [1.0.0] - 2026-09-12

### Added

- NetworkClient abstract class and Dio-backed HTTP client stub
- StorageProvider abstract class and SharedPreferences-backed key-value persistence stub
- AuthProvider abstract class and JWT token storage and refresh stub
- FileProvider abstract class and dart:io File-backed file I/O
- PushProvider abstract class and FCM token registration stub
- DeviceProvider abstract class and Platform/device info stub
- RemoteConfigProvider abstract class and in-memory remote config store
- AnalyticsProvider abstract class and console analytics event logging stub
- CrashReporter abstract class and console crash logging stub
- WebSocketProvider abstract class and dart:io WebSocket stub

[Unreleased]: https://github.com/Syzygy-Hub/syzygy-services-flutter/compare/1.2.0...HEAD
[1.2.0]: https://github.com/Syzygy-Hub/syzygy-services-flutter/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/Syzygy-Hub/syzygy-services-flutter/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/Syzygy-Hub/syzygy-services-flutter/releases/tag/1.0.0
