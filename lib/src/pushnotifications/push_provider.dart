import 'dart:async';

/// Holds the data delivered with an incoming push notification.
///
/// ## FCM Integration
///
/// When using Firebase Cloud Messaging (FCM) on Android and iOS, map the
/// incoming `RemoteMessage` to a [NotificationPayload] inside your
/// `FirebaseMessaging.onMessage` listener:
///
/// ```dart
/// FirebaseMessaging.onMessage.listen((RemoteMessage message) {
///   final payload = NotificationPayload(
///     title: message.notification?.title ?? '',
///     body:  message.notification?.body  ?? '',
///     data:  message.data,
///   );
///   myPushProvider.handleNotification(payload);
/// });
/// ```
///
/// To obtain the FCM device token, call `FirebaseMessaging.instance.getToken()`
/// and pass the result to `PushProvider.registerToken()`:
///
/// ```dart
/// final token = await FirebaseMessaging.instance.getToken();
/// if (token != null) myPushProvider.registerToken(token);
/// ```
///
/// Register the token with your backend so it can address push messages to this
/// device.
///
/// ## APNs Integration (iOS)
///
/// On iOS, push notifications are delivered through APNs. Flutter's
/// `firebase_messaging` package handles the APNs↔FCM bridge automatically when
/// configured correctly. If you need the raw APNs token (e.g. for a custom
/// push provider), use `FirebaseMessaging.instance.getAPNSToken()`:
///
/// ```dart
/// final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
/// ```
///
/// Ensure `Runner` has the **Push Notifications** capability enabled in Xcode
/// and that `GoogleService-Info.plist` is present in the iOS Runner directory.
///
/// ## Background / Terminated State
///
/// - **Background:** Handle via `FirebaseMessaging.onBackgroundMessage`.
/// - **Terminated:** Inspect `FirebaseMessaging.instance.getInitialMessage()` on
///   app launch to process the notification that opened the app.
///
/// ## Factory Helpers
///
/// Use the named constructors below to build payloads for common notification
/// types without manually setting `data` keys:
///
/// ```dart
/// final alert = NotificationPayload.alert(
///   title: 'New message',
///   body: 'You have 3 unread messages',
/// );
///
/// final deepLink = NotificationPayload.deepLink(
///   title: 'Open screen',
///   body: 'Tap to navigate',
///   route: '/inbox',
/// );
/// ```
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

  /// Creates a simple alert notification with no extra data.
  ///
  /// Use for informational messages that do not require deep-linking or
  /// additional payload processing.
  factory NotificationPayload.alert({
    required String title,
    required String body,
  }) =>
      NotificationPayload(title: title, body: body);

  /// Creates a deep-link notification that carries a [route] in [data].
  ///
  /// The [route] value is stored under the `"route"` key and can be read by
  /// your notification-tap handler to navigate the user to the correct screen:
  ///
  /// ```dart
  /// provider.onNotification.listen((payload) {
  ///   final route = payload.data['route'] as String?;
  ///   if (route != null) navigatorKey.currentState?.pushNamed(route);
  /// });
  /// ```
  factory NotificationPayload.deepLink({
    required String title,
    required String body,
    required String route,
    Map<String, dynamic> extra = const {},
  }) =>
      NotificationPayload(
        title: title,
        body: body,
        data: {'route': route, ...extra},
      );

  /// Creates a data-only (silent) notification.
  ///
  /// Silent notifications do not display a visible alert. They are useful for
  /// background data refresh. On iOS set `content-available: 1` in the APNs
  /// payload; on FCM set `priority: "high"` and omit the `notification` block.
  factory NotificationPayload.silent(Map<String, dynamic> data) =>
      NotificationPayload(title: '', body: '', data: data);

  /// Creates a badge-update notification carrying a [badgeCount].
  ///
  /// The [badgeCount] is stored under the `"badge"` key so the app icon badge
  /// can be updated when the notification is received.
  factory NotificationPayload.badge({
    required String title,
    required String body,
    required int badgeCount,
  }) =>
      NotificationPayload(
        title: title,
        body: body,
        data: {'badge': badgeCount},
      );

  @override
  String toString() => 'NotificationPayload(title: $title, body: $body)';
}

/// Abstract contract for push notification services.
///
/// ## Real Implementation Notes
///
/// ### Firebase Cloud Messaging (FCM — Android + iOS)
///
/// 1. Add `firebase_messaging` to `pubspec.yaml` and run `flutter pub get`.
/// 2. Follow the FlutterFire setup guide to configure `google-services.json`
///    (Android) and `GoogleService-Info.plist` (iOS).
/// 3. Subclass [PushProvider] and implement [requestPermission] by calling
///    `FirebaseMessaging.instance.requestPermission()`.
/// 4. Implement [registerToken] by sending the FCM token to your backend.
/// 5. Listen to `FirebaseMessaging.onMessage` (foreground) and
///    `FirebaseMessaging.onBackgroundMessage` (background) to call
///    [handleNotification] with a mapped [NotificationPayload].
///
/// ### APNs (iOS only, without FCM)
///
/// 1. Enable Push Notifications in the Xcode capability pane.
/// 2. Use the `flutter_local_notifications` or `onesignal_flutter` package to
///    request the APNs device token.
/// 3. Implement [registerToken] with the raw APNs token and forward it to your
///    push server (e.g. AWS SNS, custom APNs gateway).
///
/// ### Testing
///
/// Use [InMemoryPushProvider] in unit and widget tests — it grants permission
/// immediately, accepts any token, and lets you inject notifications via
/// [handleNotification].
abstract class PushProvider {
  /// Requests permission to display notifications.
  ///
  /// Returns `true` if permission was granted.
  ///
  /// On real devices this displays the system permission dialog on first call.
  /// Subsequent calls return the previously granted state without showing a
  /// dialog.
  Future<bool> requestPermission();

  /// Registers [deviceToken] with the push service.
  ///
  /// The token is typically an FCM registration token or a raw APNs token.
  /// Forward it to your backend so it can address push messages to this device.
  void registerToken(String deviceToken);

  /// Unregisters the current device token.
  ///
  /// Call this on sign-out to stop receiving push notifications for the user.
  void unregisterToken();

  /// The currently registered device token, or `null` if not registered.
  String? get deviceToken;

  /// Stream of incoming [NotificationPayload]s.
  ///
  /// Subscribe to receive notifications while the app is in the foreground.
  /// Background and terminated-state handling requires platform-specific setup
  /// (see [PushProvider] class-level docs).
  Stream<NotificationPayload> get onNotification;

  /// Handles an incoming [payload] — used for foreground delivery or testing.
  ///
  /// In a real implementation this is called from your FCM/APNs message
  /// listener. In tests, call this directly to simulate an incoming push
  /// notification.
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
