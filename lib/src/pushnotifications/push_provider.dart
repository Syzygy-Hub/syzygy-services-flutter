import 'dart:async';

/// Holds the data delivered with an incoming push notification.
class NotificationPayload {
  /// Notification title.
  final String title;

  /// Notification body text.
  final String body;

  /// Arbitrary key-value data attached to the notification.
  final Map<String, dynamic> data;

  /// Creates a [NotificationPayload].
  const NotificationPayload({
    required this.title,
    required this.body,
    this.data = const {},
  });

  @override
  String toString() => 'NotificationPayload(title: $title, body: $body)';
}

/// Abstract contract for push notification services.
///
/// Implementations delegate to platform push SDKs (APNs, FCM, etc.).
abstract class PushProvider {
  /// Requests permission to display notifications.
  ///
  /// Returns `true` if permission was granted.
  Future<bool> requestPermission();

  /// Registers [deviceToken] with the push service.
  void registerToken(String deviceToken);

  /// Unregisters the current device token.
  void unregisterToken();

  /// The currently registered device token, or `null` if not registered.
  String? get deviceToken;

  /// Stream of incoming [NotificationPayload]s.
  Stream<NotificationPayload> get onNotification;

  /// Handles an incoming [payload] — used for foreground delivery or testing.
  void handleNotification(NotificationPayload payload);
}

/// In-memory [PushProvider] suitable for tests and development.
class InMemoryPushProvider implements PushProvider {
  String? _deviceToken;
  final _controller = StreamController<NotificationPayload>.broadcast();

  @override
  Future<bool> requestPermission() async => true;

  @override
  void registerToken(String deviceToken) => _deviceToken = deviceToken;

  @override
  void unregisterToken() => _deviceToken = null;

  @override
  String? get deviceToken => _deviceToken;

  @override
  Stream<NotificationPayload> get onNotification => _controller.stream;

  @override
  void handleNotification(NotificationPayload payload) =>
      _controller.add(payload);

  /// Closes the underlying stream controller.
  void dispose() => _controller.close();
}
