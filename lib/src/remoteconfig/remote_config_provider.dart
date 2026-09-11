/// Defines the contract for fetching remote configuration values.
abstract class RemoteConfigProvider {
  /// Returns the string value for [key], or null if not set.
  String? getString(String key);

  /// Returns the boolean value for [key], or null if not set.
  bool? getBoolean(String key);

  /// Sets a value for [key].
  void setValue(String key, Object? value);
}

/// A [RemoteConfigProvider] backed by an in-memory map.
class InMemoryRemoteConfigProvider implements RemoteConfigProvider {
  final _store = <String, Object?>{};

  /// Initialises the provider with optional [initialValues].
  InMemoryRemoteConfigProvider({Map<String, Object?>? initialValues}) {
    if (initialValues != null) _store.addAll(initialValues);
  }

  @override
  String? getString(String key) {
    final v = _store[key];
    return v is String ? v : null;
  }

  @override
  bool? getBoolean(String key) {
    final v = _store[key];
    return v is bool ? v : null;
  }

  @override
  void setValue(String key, Object? value) => _store[key] = value;
}
