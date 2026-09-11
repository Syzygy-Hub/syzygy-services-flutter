import 'dart:io';

/// Defines the contract for accessing device information.
abstract class DeviceProvider {
  /// The OS name (e.g. 'macos', 'linux', 'android', 'ios').
  String get operatingSystem;

  /// The OS version string.
  String get operatingSystemVersion;
}

/// A [DeviceProvider] backed by [Platform].
class PlatformDeviceProvider implements DeviceProvider {
  @override
  String get operatingSystem => Platform.operatingSystem;

  @override
  String get operatingSystemVersion => Platform.operatingSystemVersion;
}
