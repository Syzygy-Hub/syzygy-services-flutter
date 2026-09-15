/// A breadcrumb left before a crash for additional context.
class Breadcrumb {
  /// Human-readable description of the event.
  final String message;

  /// Optional key-value metadata.
  final Map<String, String> metadata;

  /// When this breadcrumb was recorded (milliseconds since epoch).
  final int timestampMs;

  /// Creates a [Breadcrumb].
  Breadcrumb({
    required this.message,
    Map<String, String>? metadata,
  })  : metadata = metadata ?? const {},
        timestampMs = DateTime.now().millisecondsSinceEpoch;

  @override
  String toString() => 'Breadcrumb(msg=$message, meta=$metadata, ts=$timestampMs)';
}

/// Abstract contract for crash and non-fatal error reporting.
///
/// Implementations delegate to real crash-reporting SDKs such as Sentry,
/// Firebase Crashlytics, or Datadog.
abstract class CrashReporter {
  /// Records a non-fatal [error] with an optional [stackTrace] and
  /// key-value [metadata].
  void recordError(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}});

  /// Records a fatal crash. In production this should flush the report and
  /// may not return.
  void recordFatal(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}});

  /// Associates the current user session with [userId] and optional [email].
  void setUserContext({String? userId, String? email});

  /// Sets an arbitrary key-value pair that is attached to subsequent reports.
  void setCustomKey(String key, String value);

  /// Leaves a breadcrumb that will be included in subsequent crash reports.
  void leaveBreadcrumb(String message, {Map<String, String>? metadata});

  /// Clears all stored breadcrumbs.
  void clearBreadcrumbs();
}

/// Maximum number of breadcrumbs kept in memory.
const _kMaxBreadcrumbs = 20;

/// [CrashReporter] that prints events to the console.
///
/// All metadata is stored in memory so tests can inspect it.
class ConsoleCrashReporter implements CrashReporter {
  final Map<String, String> _metadata = {};
  final List<Breadcrumb> _breadcrumbs = [];
  String? _userId;
  String? _email;

  /// Returns a copy of the currently stored metadata.
  Map<String, String> get metadata => Map.unmodifiable(_metadata);

  /// The userId supplied via [setUserContext], or `null`.
  String? get userId => _userId;

  /// The email supplied via [setUserContext], or `null`.
  String? get email => _email;

  /// A read-only view of the current breadcrumbs (oldest first).
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  @override
  void recordError(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}}) {
    final merged = {..._metadata, ...metadata};
    // ignore: avoid_print
    print('[CrashReporter] NON-FATAL: $error\n'
        '  metadata=$merged\n'
        '  user=$_userId\n'
        '  breadcrumbs=$_breadcrumbs\n'
        '  ${stackTrace ?? ''}');
  }

  @override
  void recordFatal(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}}) {
    final merged = {..._metadata, ...metadata};
    // ignore: avoid_print
    print('[CrashReporter] FATAL: $error\n'
        '  metadata=$merged\n'
        '  user=$_userId\n'
        '  breadcrumbs=$_breadcrumbs\n'
        '  ${stackTrace ?? ''}');
    // Stub — does not terminate the process.
  }

  @override
  void setUserContext({String? userId, String? email}) {
    _userId = userId;
    _email = email;
  }

  @override
  void setCustomKey(String key, String value) {
    _metadata[key] = value;
  }

  @override
  void leaveBreadcrumb(String message, {Map<String, String>? metadata}) {
    if (_breadcrumbs.length >= _kMaxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
    _breadcrumbs.add(Breadcrumb(message: message, metadata: metadata));
  }

  @override
  void clearBreadcrumbs() => _breadcrumbs.clear();
}

/// [CrashReporter] that stores all reports in memory.
///
/// Keeps the last [_kMaxBreadcrumbs] (20) breadcrumbs in a circular buffer.
/// Breadcrumbs are included in the recorded crash reports for inspection.
class InMemoryCrashReporter implements CrashReporter {
  final Map<String, String> _metadata = {};
  final List<Breadcrumb> _breadcrumbs = [];
  String? _userId;
  String? _email;

  /// Recorded non-fatal error entries.
  final List<Map<String, Object?>> errors = [];

  /// Recorded fatal error entries.
  final List<Map<String, Object?>> fatals = [];

  /// Returns a copy of the currently stored metadata.
  Map<String, String> get metadata => Map.unmodifiable(_metadata);

  /// The userId supplied via [setUserContext], or `null`.
  String? get userId => _userId;

  /// The email supplied via [setUserContext], or `null`.
  String? get email => _email;

  /// A read-only view of the current breadcrumbs (oldest first, max 20).
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  @override
  void recordError(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}}) {
    errors.add({
      'error': error,
      'stackTrace': stackTrace,
      'metadata': {..._metadata, ...metadata},
      'breadcrumbs': List<Breadcrumb>.from(_breadcrumbs),
    });
  }

  @override
  void recordFatal(Object error, {StackTrace? stackTrace,
      Map<String, String> metadata = const {}}) {
    fatals.add({
      'error': error,
      'stackTrace': stackTrace,
      'metadata': {..._metadata, ...metadata},
      'breadcrumbs': List<Breadcrumb>.from(_breadcrumbs),
    });
  }

  @override
  void setUserContext({String? userId, String? email}) {
    _userId = userId;
    _email = email;
  }

  @override
  void setCustomKey(String key, String value) => _metadata[key] = value;

  @override
  void leaveBreadcrumb(String message, {Map<String, String>? metadata}) {
    if (_breadcrumbs.length >= _kMaxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
    _breadcrumbs.add(Breadcrumb(message: message, metadata: metadata));
  }

  @override
  void clearBreadcrumbs() => _breadcrumbs.clear();
}
