import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

void main() {
  // HI-06: PII redaction test for ConsoleAnalyticsProvider
  group('ConsoleAnalyticsProvider — HI-06 redaction', () {
    test('identify does not log userId or email in plain text', () {
      final captured = <String>[];
      final provider =
          ConsoleAnalyticsProvider(logger: (msg) => captured.add(msg));

      provider.identify(
          'test@example.com', {'email': 'test@example.com', 'plan': 'pro'});

      final output = captured.join();
      expect(output, isNot(contains('test@example.com')),
          reason: 'Plain-text PII must not appear in log output');
      expect(output, contains('<redacted>'),
          reason: 'Redaction sentinel must appear in log output');
    });
  });

  late InMemoryAnalyticsProvider analytics;

  setUp(() => analytics = InMemoryAnalyticsProvider());

  group('InMemoryAnalyticsProvider', () {
    test('sessionId is non-empty', () {
      expect(analytics.sessionId, isNotEmpty);
    });

    test('track stores the event', () {
      analytics.track(AnalyticsEvent(name: 'button_tapped'));
      expect(analytics.events.any((e) => e.name == 'button_tapped'), isTrue);
    });

    test('identify stores user properties', () {
      analytics.identify('user1', {'plan': 'pro'});
      expect(analytics.userProperties('user1'), {'plan': 'pro'});
    });

    test('trackScreen adds to screenViews and events', () {
      analytics.trackScreen('HomeScreen');
      expect(analytics.screenViews, contains('HomeScreen'));
      expect(analytics.events.any((e) => e.name == 'screen_view'), isTrue);
    });

    test('reset clears events, properties and screen views', () {
      analytics.track(AnalyticsEvent(name: 'x'));
      analytics.identify('u', {'k': 'v'});
      analytics.trackScreen('S');
      analytics.reset();
      expect(analytics.events, isEmpty);
      expect(analytics.screenViews, isEmpty);
      expect(analytics.userProperties('u'), isNull);
    });

    test('multiple events are tracked in order', () {
      analytics.track(AnalyticsEvent(name: 'a'));
      analytics.track(AnalyticsEvent(name: 'b'));
      expect(analytics.events.map((e) => e.name).toList(), ['a', 'b']);
    });

    test('session_id is injected into every tracked event properties', () {
      analytics.track(AnalyticsEvent(name: 'purchase'));
      final event = analytics.events.first;
      expect(event.properties['session_id'], analytics.sessionId);
    });

    test('session_id matches sessionId across multiple events', () {
      analytics.track(AnalyticsEvent(name: 'ev1'));
      analytics.track(AnalyticsEvent(name: 'ev2'));
      for (final e in analytics.events) {
        expect(e.properties['session_id'], analytics.sessionId);
      }
    });

    test('session_id changes after reset()', () {
      final idBefore = analytics.sessionId;
      analytics.reset();
      expect(analytics.sessionId, isNot(idBefore));
    });

    test('events after reset() carry the new session_id', () {
      analytics.track(AnalyticsEvent(name: 'before'));
      final oldId = analytics.sessionId;
      analytics.reset();
      analytics.track(AnalyticsEvent(name: 'after'));
      expect(analytics.events.first.properties['session_id'], isNot(oldId));
      expect(
          analytics.events.first.properties['session_id'], analytics.sessionId);
    });
  });
}
