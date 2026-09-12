import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';

/// In-memory implementation of [StorageProvider] using Foundation's typed key
/// contract.
///
/// Uses a plain [Map] under the hood — suitable for tests and as a
/// starting point for production wrappers that delegate to platform storage.
/// Secure keys are stored under a prefixed namespace to separate them from
/// non-secure values.
class InMemoryStorageProvider implements StorageProvider {
  static const _securePrefix = '__secure__';

  final _store = <String, Object?>{};

  String _resolveKey(StorageKey<dynamic> key, {bool secure = false}) =>
      secure ? '$_securePrefix${key.identifier}' : key.identifier;

  /// Retrieves a value for [key], returning [StorageKey.defaultValue] when
  /// the key is absent.
  ///
  /// Returns `null` when the stored type does not match [T].
  @override
  T? get<T>(StorageKey<T> key) {
    final raw = _store[_resolveKey(key)];
    if (raw == null) return key.defaultValue;
    if (raw is T) return raw as T;
    return key.defaultValue;
  }

  /// Stores [value] under [key].
  @override
  void set<T>(T value, StorageKey<T> key) {
    _store[_resolveKey(key)] = value;
  }

  /// Removes the entry for [key].
  @override
  void remove<T>(StorageKey<T> key) {
    _store.remove(_resolveKey(key));
  }

  /// Clears all stored values.
  @override
  void clear() => _store.clear();

  /// Stores [value] under [key] in the secure namespace.
  void setSecure<T>(T value, StorageKey<T> key) {
    _store[_resolveKey(key, secure: true)] = value;
  }

  /// Retrieves a value from the secure namespace.
  T? getSecure<T>(StorageKey<T> key) {
    final raw = _store[_resolveKey(key, secure: true)];
    if (raw == null) return key.defaultValue;
    if (raw is T) return raw as T;
    return key.defaultValue;
  }

  /// Removes a value from the secure namespace.
  void removeSecure<T>(StorageKey<T> key) {
    _store.remove(_resolveKey(key, secure: true));
  }
}
