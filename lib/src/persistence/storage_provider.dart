/// Defines the contract for key-value persistence storage.
abstract class StorageProvider {
  /// Stores [value] for the given [key].
  Future<void> set(String key, String value);

  /// Retrieves the value for the given [key], or null if not set.
  Future<String?> get(String key);

  /// Removes the value for the given [key].
  Future<void> remove(String key);
}

/// A [StorageProvider] backed by an in-memory map.
/// Replace with SharedPreferences in production.
class InMemoryStorageProvider implements StorageProvider {
  final _store = <String, String>{};

  @override
  Future<void> set(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<String?> get(String key) async => _store[key];

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }
}
