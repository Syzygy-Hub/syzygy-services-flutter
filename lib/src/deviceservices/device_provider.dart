import 'dart:io';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';

import '../persistence/storage_provider.dart';

const _deviceIdKey = StorageKey<String>('syzygy.device.uuid');

/// Abstract contract for accessing device-level metadata.
abstract class DeviceProvider {
  /// A stable, persistent unique identifier for this device.
  String get deviceId;

  /// Platform identifier — always `'flutter'` for this package.
  String get platform;

  /// The operating system version string (e.g. `'macOS 14.0'`).
  String get osVersion;

  /// The application version string (e.g. `'1.0.0'`).
  String get appVersion;

  /// Whether the app is running inside a simulator / emulator.
  bool get isSimulator;
}

/// [DeviceProvider] backed by [dart:io] and [InMemoryStorageProvider].
///
/// The [deviceId] is generated once and persisted via [StorageProvider] so
/// it survives process restarts within the same storage instance.
class IoDeviceProvider implements DeviceProvider {
  final InMemoryStorageProvider _storage;

  /// Creates an [IoDeviceProvider] that persists the device ID via [storage].
  IoDeviceProvider(this._storage);

  @override
  String get deviceId {
    final existing = _storage.get<String>(_deviceIdKey);
    if (existing != null) return existing;
    final id = SyzygyID.generate<IoDeviceProvider>().rawValue;
    _storage.set<String>(id, _deviceIdKey);
    return id;
  }

  @override
  String get platform => 'flutter';

  @override
  String get osVersion => Platform.operatingSystemVersion;

  @override
  String get appVersion => '1.0.0';

  @override
  bool get isSimulator =>
      Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
      Platform.environment.containsKey('SIMULATOR_UDID');
}
