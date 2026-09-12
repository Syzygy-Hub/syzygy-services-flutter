import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';

/// Abstract contract for remote configuration.
///
/// Implementations should fetch values from a remote source and merge them
/// with [defaults].
abstract class RemoteConfigProvider {
  /// Returns the value for [key] cast to [T], or `null` if absent.
  T? getValue<T>(String key);

  /// Returns a [String] value for [key], or `null` if absent or wrong type.
  String? getString(String key);

  /// Returns an [int] value for [key], or `null` if absent or wrong type.
  int? getInt(String key);

  /// Returns a [bool] value for [key], or `null` if absent or wrong type.
  bool? getBool(String key);

  /// Returns a [double] value for [key], or `null` if absent or wrong type.
  double? getDouble(String key);

  /// Fetches fresh configuration from the remote source, merging with
  /// [defaults].
  Future<void> fetch();

  /// The timestamp of the most recent successful [fetch], or `null` if never
  /// fetched.
  SyzygyTimestamp? get lastFetchTime;
}

/// In-memory [RemoteConfigProvider] useful for tests and offline scenarios.
///
/// [defaults] provide fallback values. [fetch] merges an optional
/// [remoteValues] map (supplied at construction) on top of defaults.
class InMemoryRemoteConfigProvider implements RemoteConfigProvider {
  final Map<String, Object?> _defaults;
  final Map<String, Object?> _remote;
  final Map<String, Object?> _store = {};
  SyzygyTimestamp? _lastFetchTime;

  /// Creates an [InMemoryRemoteConfigProvider].
  ///
  /// [defaults] are used as fallback values.
  /// [remoteValues] simulates values returned by the remote source.
  InMemoryRemoteConfigProvider({
    Map<String, Object?> defaults = const {},
    Map<String, Object?> remoteValues = const {},
  })  : _defaults = Map.of(defaults),
        _remote = Map.of(remoteValues) {
    _store.addAll(_defaults);
  }

  @override
  T? getValue<T>(String key) {
    final v = _store[key];
    if (v is T) return v;
    return null;
  }

  @override
  String? getString(String key) => getValue<String>(key);

  @override
  int? getInt(String key) => getValue<int>(key);

  @override
  bool? getBool(String key) => getValue<bool>(key);

  @override
  double? getDouble(String key) => getValue<double>(key);

  @override
  Future<void> fetch() async {
    await Future<void>.delayed(Duration.zero); // async boundary
    _store
      ..addAll(_defaults)
      ..addAll(_remote);
    _lastFetchTime = SyzygyTimestamp.now();
  }

  @override
  SyzygyTimestamp? get lastFetchTime => _lastFetchTime;
}
