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
  String _sessionId;

  /// Creates a [ConsoleAnalyticsProvider] with an auto-generated session ID.
  ConsoleAnalyticsProvider()
      : _sessionId = SyzygyID.generate<ConsoleAnalyticsProvider>().rawValue;

  @override
  String get sessionId => _sessionId;

  @override
  void track(AnalyticsEvent event) {
    final enriched = AnalyticsEvent(
      name: event.name,
      properties: {'session_id': _sessionId, ...event.properties},
      timestamp: event.timestamp,
    );
    // ignore: avoid_print
    print('[Analytics] event=${enriched.name} props=${enriched.properties} '
        'session=$_sessionId ts=${enriched.timestamp.millisecondsSinceEpoch}');
  }

  @override
  void identify(String userId, Map<String, Object?> traits) {
    // ignore: avoid_print
    print('[Analytics] identify userId=$userId traits=$traits');
  }

  @override
  void reset() {
    _sessionId = SyzygyID.generate<ConsoleAnalyticsProvider>().rawValue;
    // ignore: avoid_print
    print('[Analytics] reset — new session=$_sessionId');
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
  String _sessionId;
  final List<AnalyticsEvent> events = [];
  final Map<String, Map<String, Object?>> _userProperties = {};
  final List<String> screenViews = [];

  /// Creates an [InMemoryAnalyticsProvider] with an auto-generated session ID.
  InMemoryAnalyticsProvider()
      : _sessionId = SyzygyID.generate<InMemoryAnalyticsProvider>().rawValue;

  @override
  String get sessionId => _sessionId;

  /// Tracks [event], injecting `session_id` into its properties.
  @override
  void track(AnalyticsEvent event) {
    events.add(AnalyticsEvent(
      name: event.name,
      properties: {'session_id': _sessionId, ...event.properties},
      timestamp: event.timestamp,
    ));
  }

  @override
  void identify(String userId, Map<String, Object?> traits) =>
      _userProperties[userId] = Map.of(traits);

  /// Clears all events/properties and generates a new session ID.
  @override
  void reset() {
    events.clear();
    _userProperties.clear();
    screenViews.clear();
    _sessionId = SyzygyID.generate<InMemoryAnalyticsProvider>().rawValue;
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
