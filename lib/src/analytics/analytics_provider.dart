import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';

/// Extends the Foundation [AnalyticsProvider] contract with screen tracking
/// and session management.
abstract class ServicesAnalyticsProvider implements AnalyticsProvider {
  /// Records a screen-view event for [screenName].
  void trackScreen(String screenName, {Map<String, Object?> properties});

  /// The current session identifier (UUID).
  String get sessionId;
}

/// [ServicesAnalyticsProvider] that prints events to the console.
///
/// Suitable for debug builds. Replace with a real analytics SDK in
/// production.
class ConsoleAnalyticsProvider implements ServicesAnalyticsProvider {
  final String _sessionId;

  /// Creates a [ConsoleAnalyticsProvider] with an auto-generated session ID.
  ConsoleAnalyticsProvider()
      : _sessionId = SyzygyID.generate<ConsoleAnalyticsProvider>().rawValue;

  @override
  String get sessionId => _sessionId;

  @override
  void track(AnalyticsEvent event) {
    // ignore: avoid_print
    print('[Analytics] event=${event.name} props=${event.properties} '
        'session=$_sessionId ts=${event.timestamp.millisecondsSinceEpoch}');
  }

  @override
  void identify(String userId, Map<String, Object?> traits) {
    // ignore: avoid_print
    print('[Analytics] identify userId=$userId traits=$traits');
  }

  @override
  void reset() {
    // ignore: avoid_print
    print('[Analytics] reset');
  }

  @override
  void trackScreen(String screenName,
      {Map<String, Object?> properties = const {}}) {
    track(AnalyticsEvent(
      name: 'screen_view',
      properties: {'screen': screenName, ...properties},
    ));
  }
}

/// [ServicesAnalyticsProvider] that stores events in memory — useful for
/// tests.
class InMemoryAnalyticsProvider implements ServicesAnalyticsProvider {
  final String _sessionId;
  final List<AnalyticsEvent> events = [];
  final Map<String, Map<String, Object?>> _userProperties = {};
  final List<String> screenViews = [];

  /// Creates an [InMemoryAnalyticsProvider] with an auto-generated session ID.
  InMemoryAnalyticsProvider()
      : _sessionId = SyzygyID.generate<InMemoryAnalyticsProvider>().rawValue;

  @override
  String get sessionId => _sessionId;

  @override
  void track(AnalyticsEvent event) => events.add(event);

  @override
  void identify(String userId, Map<String, Object?> traits) =>
      _userProperties[userId] = Map.of(traits);

  @override
  void reset() {
    events.clear();
    _userProperties.clear();
    screenViews.clear();
  }

  @override
  void trackScreen(String screenName,
      {Map<String, Object?> properties = const {}}) {
    screenViews.add(screenName);
    track(AnalyticsEvent(
      name: 'screen_view',
      properties: {'screen': screenName, ...properties},
    ));
  }

  /// Returns the properties map for [userId], or `null` if not identified.
  Map<String, Object?>? userProperties(String userId) => _userProperties[userId];
}
