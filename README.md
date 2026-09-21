[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev) [![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0-0175C2?style=flat&logo=dart&logoColor=white)](https://dart.dev) [![CI](https://img.shields.io/github/actions/workflow/status/Syzygy-Hub/syzygy-services-flutter/ci.yml?label=ci&style=flat)](https://github.com/Syzygy-Hub/syzygy-services-flutter/actions/workflows/ci.yml) [![Version](https://img.shields.io/badge/version-1.2.0-D85A30?style=flat)](https://github.com/Syzygy-Hub/syzygy-services-flutter/releases) [![License](https://img.shields.io/badge/License-MIT-green?style=flat)](LICENSE)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/Syzygy-Hub/.github/main/brand/assets/banners/syzygy-banner-dark-1200.png">
  <img src="https://raw.githubusercontent.com/Syzygy-Hub/.github/main/brand/assets/banners/syzygy-banner-light-1200.png" alt="Syzygy" width="600">
</picture>

# syzygy-services-flutter

Concrete I/O service implementations for the Syzygy Flutter ecosystem — networking, persistence, auth, file management, push notifications, device services, remote config, analytics, crash reporting, and WebSocket.

## Modules

| Module | Abstract Class | Concrete Implementation | Description |
|--------|---------------|------------------------|-------------|
| `networking` | `NetworkClientProtocol` | `HttpNetworkClient` | HTTP GET/POST via dart:io HttpClient |
| `persistence` | `StorageProvider` | `InMemoryStorageProvider` | Key-value storage (SharedPreferences-ready) |
| `auth` | `AuthProvider` | `TokenAuthProvider` | JWT token storage and refresh |
| `filemanagement` | `FileProvider` | `IoFileProvider` | File I/O via dart:io |
| `pushnotifications` | `PushProvider` | `InMemoryPushProvider` | Push token registration |
| `deviceservices` | `DeviceProvider` | `IoDeviceProvider` | OS name and version via Platform |
| `remoteconfig` | `RemoteConfigProvider` | `NetworkRemoteConfigProvider` | Networked remote configuration with cache TTL |
| `analytics` | `AnalyticsProvider` | `ConsoleAnalyticsProvider` | Console analytics event logging |
| `crashreporting` | `CrashReporter` | `InMemoryCrashReporter` | In-memory breadcrumb buffer with crash recording |
| `websocket` | `WebSocketProvider` | `DartWebSocketProvider` | WebSocket via dart:io |

## Installation

```yaml
dependencies:
  syzygy_services_flutter: ^1.2.0
```

## Requirements

- Dart SDK `>=3.0.0`
- Flutter 3.0+

## Dependencies

- [`syzygy_foundation_flutter`](https://pub.dev/packages/syzygy_foundation_flutter) `^1.2.0`

## Ecosystem

`syzygy-services-flutter` is the I/O layer of the Syzygy Flutter ecosystem. It depends only on `syzygy_foundation_flutter` from pub.dev and never on syzygy-core. Each module exposes an abstract class (protocol) alongside a concrete implementation, making it easy to swap implementations in tests or production.

| Repository | Layer | Description |
|------------|-------|-------------|
| [syzygy-foundation-flutter](https://github.com/Syzygy-Hub/syzygy-foundation-flutter) | Foundation | Primitives, extensions, and base utilities |
| **syzygy-services-flutter** | **Services** | **Concrete I/O service implementations** |
| [syzygy-core-flutter](https://github.com/Syzygy-Hub/syzygy-core-flutter) | Core | Business logic and domain layer |

## Push Notifications

`PushProvider` abstracts FCM (Android + iOS) and APNs (iOS) push-notification delivery behind a platform-agnostic interface.

### FCM Integration (Android + iOS)

```dart
// 1. Obtain the FCM token and register it with your backend.
final token = await FirebaseMessaging.instance.getToken();
if (token != null) myPushProvider.registerToken(token);

// 2. Handle foreground messages.
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  myPushProvider.handleNotification(NotificationPayload(
    title: message.notification?.title ?? '',
    body:  message.notification?.body  ?? '',
    data:  message.data,
  ));
});
```

### APNs Integration (iOS)

```dart
// Retrieve the raw APNs token when not using FCM as the bridge.
final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
if (apnsToken != null) myPushProvider.registerToken(apnsToken);
```

Enable **Push Notifications** in the Xcode capability pane and ensure
`GoogleService-Info.plist` is present in the iOS Runner directory.

### Factory Helpers

`NotificationPayload` provides named constructors for common notification types:

```dart
// Alert — no extra data.
final alert = NotificationPayload.alert(title: 'Hi', body: 'You have mail');

// Deep-link — stores the route under the "route" key.
final nav = NotificationPayload.deepLink(
  title: 'Open inbox',
  body: 'Tap to view',
  route: '/inbox',
);

// Silent — no visible alert, useful for background refresh.
final silent = NotificationPayload.silent({'refresh': 'true'});

// Badge — updates the app-icon badge count.
final badge = NotificationPayload.badge(title: '', body: '', badgeCount: 5);
```

### Testing

Use `InMemoryPushProvider` in unit and widget tests:

```dart
final push = InMemoryPushProvider();
await push.requestPermission(); // returns true immediately
push.registerToken('test-token');

push.onNotification.listen((payload) {
  // handle payload in test
});

push.handleNotification(NotificationPayload.alert(title: 'Test', body: 'body'));
```

## License

MIT — see [LICENSE](LICENSE).
