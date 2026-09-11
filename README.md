[![CI](https://github.com/Syzygy-Hub/syzygy-services-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/Syzygy-Hub/syzygy-services-flutter/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/Syzygy-Hub/syzygy-services-flutter/releases/tag/1.0.0)
[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0-0175C2?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/Syzygy-Hub/.github/main/assets/syzygy-banner-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/Syzygy-Hub/.github/main/assets/syzygy-banner-light.png">
  <img alt="Syzygy" src="https://raw.githubusercontent.com/Syzygy-Hub/.github/main/assets/syzygy-banner-light.png">
</picture>

# syzygy-services-flutter

Concrete I/O service implementations for the Syzygy Flutter ecosystem — networking, persistence, auth, file management, push notifications, device services, remote config, analytics, crash reporting, and WebSocket.

## Modules

| Module | Abstract Class | Concrete Implementation | Description |
|--------|---------------|------------------------|-------------|
| `networking` | `NetworkClient` | `HttpNetworkClient` | HTTP GET/POST via dart:io HttpClient |
| `persistence` | `StorageProvider` | `InMemoryStorageProvider` | Key-value storage (SharedPreferences-ready) |
| `auth` | `AuthProvider` | `JWTAuthProvider` | JWT token storage and refresh stub |
| `filemanagement` | `FileProvider` | `DartFileProvider` | File I/O via dart:io |
| `pushnotifications` | `PushProvider` | `InMemoryPushProvider` | Push token registration stub |
| `deviceservices` | `DeviceProvider` | `PlatformDeviceProvider` | OS name and version via Platform |
| `remoteconfig` | `RemoteConfigProvider` | `InMemoryRemoteConfigProvider` | In-memory remote config store |
| `analytics` | `AnalyticsProvider` | `ConsoleAnalyticsProvider` | Console analytics event logging |
| `crashreporting` | `CrashReporter` | `ConsoleCrashReporter` | Console crash and error logging |
| `websocket` | `WebSocketProvider` | `DartWebSocketProvider` | WebSocket via dart:io |

## Installation

```yaml
dependencies:
  syzygy_services_flutter: ^1.0.0
```

## Requirements

- Dart SDK `>=3.0.0`
- Flutter 3.0+

## Dependencies

- [`syzygy_foundation_flutter`](https://pub.dev/packages/syzygy_foundation_flutter) `^1.1.0`

## Ecosystem

`syzygy-services-flutter` is the I/O layer of the Syzygy Flutter ecosystem. It depends only on `syzygy_foundation_flutter` from pub.dev and never on syzygy-core. Each module exposes an abstract class (protocol) alongside a concrete implementation, making it easy to swap implementations in tests or production.

| Repository | Layer | Description |
|------------|-------|-------------|
| [syzygy-foundation-flutter](https://github.com/Syzygy-Hub/syzygy-foundation-flutter) | Foundation | Primitives, extensions, and base utilities |
| **syzygy-services-flutter** | **Services** | **Concrete I/O service implementations** |
| [syzygy-core-flutter](https://github.com/Syzygy-Hub/syzygy-core-flutter) | Core | Business logic and domain layer |

## License

MIT — see [LICENSE](LICENSE).
