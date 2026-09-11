/// Defines the contract for push notification token registration.
abstract class PushProvider {
  /// Registers the device with the given [token].
  void registerToken(String token);

  /// The current push token, or null if not registered.
  String? get deviceToken;
}

/// A [PushProvider] that stores a push token in memory.
class InMemoryPushProvider implements PushProvider {
  String? _token;

  @override
  void registerToken(String token) => _token = token;

  @override
  String? get deviceToken => _token;
}
