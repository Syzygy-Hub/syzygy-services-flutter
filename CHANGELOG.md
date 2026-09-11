# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/Syzygy-Hub/syzygy-services-flutter/releases/tag/1.0.0
