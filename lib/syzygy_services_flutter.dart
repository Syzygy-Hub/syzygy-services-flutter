/// Syzygy Services Flutter — concrete I/O implementations.
///
/// This library provides platform-level service implementations that fulfil
/// Foundation contracts. Import this in your application layer; depend on
/// the Foundation contracts in your domain layer.
library;

export 'src/networking/network_client.dart';
export 'src/persistence/storage_provider.dart';
export 'src/auth/auth_provider.dart';
export 'src/filemanagement/file_provider.dart';
export 'src/pushnotifications/push_provider.dart';
export 'src/deviceservices/device_provider.dart';
export 'src/remoteconfig/remote_config_provider.dart';
export 'src/analytics/analytics_provider.dart';
export 'src/crashreporting/crash_reporter.dart';
export 'src/websocket/websocket_provider.dart';
