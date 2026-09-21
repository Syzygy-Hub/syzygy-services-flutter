import 'dart:convert';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';

import '../networking/network_client.dart';

/// Abstract contract for remote configuration.
///
/// Implementations should fetch values from a remote source and merge them
/// with [defaults].
abstract class RemoteConfigProvider {
  /// Returns the value for [key] cast to [T], or `null` if absent.
  T? getValue<T>(String key);

  /// Returns a [String] value for [key], or `null` if absent or wrong type.
  String? getString(String key);

  /// Returns an [int] value for [key], or `null` if absent or wrong type.
  int? getInt(String key);

  /// Returns a [bool] value for [key], or `null` if absent or wrong type.
  bool? getBool(String key);

  /// Returns a [double] value for [key], or `null` if absent or wrong type.
  double? getDouble(String key);

  /// Fetches fresh configuration from the remote source, merging with
  /// [defaults].
  Future<void> fetch();

  /// The timestamp of the most recent successful [fetch], or `null` if never
  /// fetched.
  SyzygyTimestamp? get lastFetchTime;
}

/// In-memory [RemoteConfigProvider] useful for tests and offline scenarios.
///
/// [defaults] provide fallback values. [fetch] merges an optional
/// [remoteValues] map (supplied at construction) on top of defaults.
class InMemoryRemoteConfigProvider implements RemoteConfigProvider {
  final Map<String, Object?> _defaults;
  final Map<String, Object?> _remote;
  final Map<String, Object?> _store = {};
  SyzygyTimestamp? _lastFetchTime;

  /// Creates an [InMemoryRemoteConfigProvider].
  ///
  /// [defaults] are used as fallback values.
  /// [remoteValues] simulates values returned by the remote source.
  InMemoryRemoteConfigProvider({
    Map<String, Object?> defaults = const {},
    Map<String, Object?> remoteValues = const {},
  })  : _defaults = Map.of(defaults),
        _remote = Map.of(remoteValues) {
    _store.addAll(_defaults);
  }

  @override
  T? getValue<T>(String key) {
    final v = _store[key];
    if (v is T) return v;
    return null;
  }

  @override
  String? getString(String key) => getValue<String>(key);

  @override
  int? getInt(String key) => getValue<int>(key);

  @override
  bool? getBool(String key) => getValue<bool>(key);

  @override
  double? getDouble(String key) => getValue<double>(key);

  @override
  Future<void> fetch() async {
    await Future<void>.delayed(Duration.zero); // async boundary
    _store
      ..addAll(_defaults)
      ..addAll(_remote);
    _lastFetchTime = SyzygyTimestamp.now();
  }

  @override
  SyzygyTimestamp? get lastFetchTime => _lastFetchTime;
}

/// [RemoteConfigProvider] backed by a real HTTP endpoint with cache TTL.
///
/// [fetch] hits [configUrl] only when the cache is empty or stale (older than
/// [cacheTtlSeconds] seconds). Successful responses are merged on top of
/// [defaults] and cached until the TTL expires.
///
/// The endpoint must return a JSON object whose top-level keys become config
/// values.
class NetworkRemoteConfigProvider implements RemoteConfigProvider {
  final HttpNetworkClient _client;

  /// URL that returns a JSON object of key→value pairs.
  final String configUrl;

  /// Number of seconds a successful fetch is considered fresh.
  /// Defaults to 3600 (1 hour).
  final int cacheTtlSeconds;

  final Map<String, Object?> _defaults;
  final Map<String, Object?> _store = {};
  SyzygyTimestamp? _lastFetchTime;

  /// Optional logger. When non-null, fetch failures and recoveries are logged.
  final LoggerProtocol? _logger;

  /// Creates a [NetworkRemoteConfigProvider].
  ///
  /// [client] is the HTTP client used to fetch remote config.
  /// [configUrl] is the endpoint returning a JSON config object.
  /// [cacheTtlSeconds] controls how long a cached result is reused (default 3600).
  /// [defaults] provide fallback values used before and between fetches.
  /// [logger] receives warnings on fetch failure and info on recovery.
  NetworkRemoteConfigProvider({
    required HttpNetworkClient client,
    required this.configUrl,
    this.cacheTtlSeconds = 3600,
    Map<String, Object?> defaults = const {},
    LoggerProtocol? logger,
  })  : _client = client,
        _defaults = Map.of(defaults),
        _logger = logger {
    _store.addAll(_defaults);
  }

  bool get _isCacheStale {
    final last = _lastFetchTime;
    if (last == null) return true;
    final age = DateTime.now().difference(last.toDateTime()).inSeconds;
    return age >= cacheTtlSeconds;
  }

  @override
  T? getValue<T>(String key) {
    final v = _store[key];
    if (v is T) return v;
    return null;
  }

  @override
  String? getString(String key) => getValue<String>(key);

  @override
  int? getInt(String key) => getValue<int>(key);

  @override
  bool? getBool(String key) => getValue<bool>(key);

  @override
  double? getDouble(String key) => getValue<double>(key);

  /// Fetches remote config from [configUrl] if the cache is stale or empty.
  ///
  /// Returns immediately without hitting the network when the cache is still
  /// fresh (within [cacheTtlSeconds]).
  @override
  Future<void> fetch() async {
    if (!_isCacheStale) return;

    try {
      final response = await _client.get(configUrl);

      if (!response.isSuccess) {
        _logger?.warning(
          'RemoteConfigProvider: fetch failed — HTTP ${response.statusCode}',
        );
        return;
      }

      final body = jsonDecode(utf8.decode(response.data));
      if (body is Map<String, dynamic>) {
        _store
          ..addAll(_defaults)
          ..addAll(body);
        final wasStale = _lastFetchTime == null;
        _lastFetchTime = SyzygyTimestamp.now();
        if (!wasStale) {
          _logger?.info('RemoteConfigProvider: fetch recovered');
        }
      }
    } catch (e) {
      _logger?.warning('RemoteConfigProvider: fetch failed — $e');
    }
  }

  @override
  SyzygyTimestamp? get lastFetchTime => _lastFetchTime;
}
