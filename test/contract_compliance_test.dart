// ignore_for_file: unused_local_variable

/// Contract compliance tests for syzygy-services-flutter.
///
/// Each test verifies that a concrete service implementation:
///   1. Can be instantiated without error.
///   2. Correctly implements (is-a) the expected Foundation contract.
///   3. Primary method exists and returns the expected type.
///
/// These tests do NOT test behaviour in depth — see the per-module test files
/// for behavioural coverage. The goal here is a fast, compile-time-verified
/// smoke check that no service has drifted from its Foundation contract.
library;

import 'dart:typed_data';

import 'package:syzygy_foundation_flutter/syzygy_foundation_flutter.dart';
import 'package:syzygy_services_flutter/syzygy_services_flutter.dart';
import 'package:test/test.dart';

// A JWT valid until 2030: {"sub":"1","exp":1893456000}
const _validJwt = 'eyJhbGciOiJIUzI1NiJ9'
    '.eyJzdWIiOiIxIiwiZXhwIjoxODkzNDU2MDAwfQ'
    '.signature';

void main() {
  // -------------------------------------------------------------------------
  // NetworkClientProtocol — HttpNetworkClient
  // -------------------------------------------------------------------------
  group('HttpNetworkClient satisfies NetworkClientProtocol', () {
    test('can be instantiated', () {
      final client = HttpNetworkClient();
      expect(client, isNotNull);
      client.close();
    });

    test('is a NetworkClientProtocol', () {
      final NetworkClientProtocol client = HttpNetworkClient();
      expect(client, isA<NetworkClientProtocol>());
      (client as HttpNetworkClient).close();
    });

    test('execute() returns Future<NetworkResponse>', () {
      final client = HttpNetworkClient();
      // We only verify the return type compiles; actual call needs a live server.
      final result = client.execute(
        const NetworkRequest(
            url: 'https://example.com', method: NetworkMethod.get),
      );
      expect(result, isA<Future<NetworkResponse>>());
      client.close();
    });
  });

  // -------------------------------------------------------------------------
  // StorageProvider — InMemoryStorageProvider
  // -------------------------------------------------------------------------
  group('InMemoryStorageProvider satisfies StorageProvider', () {
    test('can be instantiated', () {
      final provider = InMemoryStorageProvider();
      expect(provider, isNotNull);
    });

    test('is a StorageProvider', () {
      final StorageProvider provider = InMemoryStorageProvider();
      expect(provider, isA<StorageProvider>());
    });

    test('get() returns null for unknown key', () {
      final provider = InMemoryStorageProvider();
      final result = provider.get<String>(const StorageKey('missing'));
      expect(result, isNull);
    });

    test('set() then get() returns stored value', () {
      final provider = InMemoryStorageProvider();
      const key = StorageKey<String>('name');
      provider.set<String>('Alice', key);
      expect(provider.get<String>(key), 'Alice');
    });

    test('remove() deletes stored value', () {
      final provider = InMemoryStorageProvider();
      const key = StorageKey<int>('count');
      provider.set<int>(42, key);
      provider.remove<int>(key);
      expect(provider.get<int>(key), isNull);
    });

    test('clear() removes all values', () {
      final provider = InMemoryStorageProvider();
      const k1 = StorageKey<String>('a');
      const k2 = StorageKey<String>('b');
      provider
        ..set('x', k1)
        ..set('y', k2)
        ..clear();
      expect(provider.get<String>(k1), isNull);
      expect(provider.get<String>(k2), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // AuthProvider — TokenAuthProvider
  // -------------------------------------------------------------------------
  group('TokenAuthProvider satisfies AuthProvider', () {
    late InMemoryStorageProvider storage;
    late TokenAuthProvider auth;

    setUp(() {
      storage = InMemoryStorageProvider();
      auth = TokenAuthProvider(storage);
    });

    tearDown(() => auth.dispose());

    test('can be instantiated', () {
      expect(auth, isNotNull);
    });

    test('is an AuthProvider', () {
      final AuthProvider provider = auth;
      expect(provider, isA<AuthProvider>());
    });

    test('state returns AuthState', () {
      final AuthState state = auth.state;
      expect(state, isA<AuthState>());
    });

    test('stateStream is a Stream<AuthState>', () {
      expect(auth.stateStream, isA<Stream<AuthState>>());
    });

    test('authenticate() transitions to Authenticated', () {
      auth.authenticate(const AuthToken(accessToken: _validJwt));
      expect(auth.state, isA<Authenticated>());
    });

    test('signOut() transitions to Unauthenticated', () {
      auth.authenticate(const AuthToken(accessToken: _validJwt));
      auth.signOut();
      expect(auth.state, isA<Unauthenticated>());
    });

    test('refresh() returns Future<AuthToken>', () async {
      auth.authenticate(const AuthToken(accessToken: _validJwt));
      final result = await auth.refresh();
      expect(result, isA<AuthToken>());
    });
  });

  // -------------------------------------------------------------------------
  // RemoteConfigProvider — InMemoryRemoteConfigProvider
  // -------------------------------------------------------------------------
  group('InMemoryRemoteConfigProvider satisfies RemoteConfigProvider', () {
    test('can be instantiated', () {
      final p = InMemoryRemoteConfigProvider();
      expect(p, isNotNull);
    });

    test('is a RemoteConfigProvider', () {
      final RemoteConfigProvider p = InMemoryRemoteConfigProvider();
      expect(p, isA<RemoteConfigProvider>());
    });

    test('fetch() returns Future<void>', () async {
      final p = InMemoryRemoteConfigProvider();
      final result = p.fetch();
      expect(result, isA<Future<void>>());
      await result;
    });

    test('getString/getInt/getBool/getDouble return correct types', () async {
      final p = InMemoryRemoteConfigProvider(
        remoteValues: {
          's': 'hello',
          'i': 42,
          'b': true,
          'd': 3.14,
        },
      );
      await p.fetch();
      expect(p.getString('s'), isA<String>());
      expect(p.getInt('i'), isA<int>());
      expect(p.getBool('b'), isA<bool>());
      expect(p.getDouble('d'), isA<double>());
    });

    test('lastFetchTime is SyzygyTimestamp after fetch', () async {
      final p = InMemoryRemoteConfigProvider();
      await p.fetch();
      expect(p.lastFetchTime, isA<SyzygyTimestamp>());
    });
  });

  // -------------------------------------------------------------------------
  // WebSocketProvider — InMemoryWebSocketProvider
  // -------------------------------------------------------------------------
  group('InMemoryWebSocketProvider satisfies WebSocketProvider', () {
    test('can be instantiated', () {
      final p = InMemoryWebSocketProvider();
      expect(p, isNotNull);
    });

    test('is a WebSocketProvider', () {
      final WebSocketProvider p = InMemoryWebSocketProvider();
      expect(p, isA<WebSocketProvider>());
    });

    test('connectionState returns WebSocketConnectionState', () {
      final p = InMemoryWebSocketProvider();
      expect(p.connectionState, isA<WebSocketConnectionState>());
    });

    test('messages is a Stream<dynamic>', () {
      final p = InMemoryWebSocketProvider();
      expect(p.messages, isA<Stream<dynamic>>());
    });

    test('connect() returns Future<void>', () async {
      final p = InMemoryWebSocketProvider();
      final result = p.connect('ws://localhost');
      expect(result, isA<Future<void>>());
      await result;
      await p.disconnect();
    });

    test('sendText() and sendBytes() work on connected provider', () async {
      final p = InMemoryWebSocketProvider();
      await p.connect('ws://localhost');
      await p.sendText('ping');
      await p.sendBytes(Uint8List.fromList([1, 2, 3]));
      await p.disconnect();
    });
  });

  // -------------------------------------------------------------------------
  // PushProvider — InMemoryPushProvider
  // -------------------------------------------------------------------------
  group('InMemoryPushProvider satisfies PushProvider', () {
    test('can be instantiated', () {
      final p = InMemoryPushProvider();
      expect(p, isNotNull);
    });

    test('is a PushProvider', () {
      final PushProvider p = InMemoryPushProvider();
      expect(p, isA<PushProvider>());
    });

    test('requestPermission() returns Future<bool>', () async {
      final p = InMemoryPushProvider();
      final result = await p.requestPermission();
      expect(result, isA<bool>());
      p.dispose();
    });

    test('onNotification is Stream<NotificationPayload>', () {
      final p = InMemoryPushProvider();
      expect(p.onNotification, isA<Stream<NotificationPayload>>());
      p.dispose();
    });

    test('registerToken sets deviceToken', () {
      final p = InMemoryPushProvider();
      p.registerToken('device-abc');
      expect(p.deviceToken, 'device-abc');
      p.dispose();
    });
  });

  // -------------------------------------------------------------------------
  // WebSocketProvider — DartWebSocketProvider (instantiation only)
  // -------------------------------------------------------------------------
  group('DartWebSocketProvider can be instantiated', () {
    test('is a WebSocketProvider', () {
      final WebSocketProvider p = DartWebSocketProvider();
      expect(p, isA<WebSocketProvider>());
    });
  });

  // -------------------------------------------------------------------------
  // NotificationPayload factory helpers
  // -------------------------------------------------------------------------
  group('NotificationPayload factory helpers', () {
    test('alert() creates payload with no extra data', () {
      final p = NotificationPayload.alert(title: 'T', body: 'B');
      expect(p.title, 'T');
      expect(p.body, 'B');
      expect(p.data, isEmpty);
    });

    test('deepLink() stores route in data', () {
      final p = NotificationPayload.deepLink(
        title: 'T',
        body: 'B',
        route: '/home',
      );
      expect(p.data['route'], '/home');
    });

    test('silent() stores data and uses empty title/body', () {
      final p = NotificationPayload.silent({'key': 'val'});
      expect(p.title, '');
      expect(p.body, '');
      expect(p.data['key'], 'val');
    });

    test('badge() stores badgeCount in data', () {
      final p = NotificationPayload.badge(title: 'T', body: 'B', badgeCount: 5);
      expect(p.data['badge'], 5);
    });
  });
}
