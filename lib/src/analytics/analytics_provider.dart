/// Defines the contract for recording analytics events.
abstract class AnalyticsProvider {
  /// Records an event with the given [name] and optional [properties].
  void track(String name, {Map<String, String> properties = const {}});
}

/// An [AnalyticsProvider] that logs events to the console.
class ConsoleAnalyticsProvider implements AnalyticsProvider {
  @override
  void track(String name, {Map<String, String> properties = const {}}) {
    // ignore: avoid_print
    print('[Analytics] $name $properties');
  }
}
