import 'dart:async';
import 'dart:io';

/// Connection lifecycle states for a [WebSocketProvider].
enum WebSocketConnectionState {
  /// No active connection and no reconnection in progress.
  disconnected,

  /// Establishing the initial connection or reconnecting.
  connecting,

  /// The WebSocket handshake has completed successfully.
  connected,
}

/// Abstract contract for WebSocket communication.
abstract class WebSocketProvider {
  /// Connects to [url].
  Future<void> connect(String url);

  /// Sends a text [message].
  Future<void> sendText(String message);

  /// Sends binary [data].
  Future<void> sendBytes(List<int> data);

  /// Stream of incoming messages (String or List<int>).
  Stream<dynamic> get messages;

  /// The current connection state.
  WebSocketConnectionState get connectionState;

  /// Disconnects and releases resources.
  Future<void> disconnect();
}

/// [WebSocketProvider] backed by [dart:io] [WebSocket] with automatic
/// reconnection and exponential backoff.
class DartWebSocketProvider implements WebSocketProvider {
  WebSocket? _socket;
  StreamController<dynamic>? _messageController;
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  String? _lastUrl;
  int _retryCount = 0;

  static const int _maxRetries = 5;

  @override
  WebSocketConnectionState get connectionState => _state;

  @override
  Stream<dynamic> get messages {
    _messageController ??= StreamController<dynamic>.broadcast();
    return _messageController!.stream;
  }

  @override
  Future<void> connect(String url) async {
    _lastUrl = url;
    _retryCount = 0;
    await _doConnect(url);
  }

  Future<void> _doConnect(String url) async {
    _state = WebSocketConnectionState.connecting;
    try {
      _socket = await WebSocket.connect(url);
      _state = WebSocketConnectionState.connected;
      _retryCount = 0;

      _messageController ??= StreamController<dynamic>.broadcast();
      _socket!.listen(
        (event) => _messageController?.add(event),
        onDone: _onDisconnect,
        onError: (Object e) => _onDisconnect(),
        cancelOnError: false,
      );
    } on Exception {
      _state = WebSocketConnectionState.disconnected;
      await _scheduleReconnect();
    }
  }

  Future<void> _onDisconnect() async {
    _state = WebSocketConnectionState.disconnected;
    if (_lastUrl != null) {
      await _scheduleReconnect();
    }
  }

  Future<void> _scheduleReconnect() async {
    if (_retryCount >= _maxRetries || _lastUrl == null) return;
    final delay = Duration(milliseconds: 200 * (1 << _retryCount));
    _retryCount++;
    await Future<void>.delayed(delay);
    await _doConnect(_lastUrl!);
  }

  @override
  Future<void> sendText(String message) async {
    if (_socket == null || _state != WebSocketConnectionState.connected) {
      throw StateError('WebSocket is not connected');
    }
    _socket!.add(message);
  }

  @override
  Future<void> sendBytes(List<int> data) async {
    if (_socket == null || _state != WebSocketConnectionState.connected) {
      throw StateError('WebSocket is not connected');
    }
    _socket!.add(data);
  }

  @override
  Future<void> disconnect() async {
    _lastUrl = null;
    _state = WebSocketConnectionState.disconnected;
    await _socket?.close();
    _socket = null;
    await _messageController?.close();
    _messageController = null;
  }
}

/// In-memory [WebSocketProvider] for tests — no real network I/O.
///
/// Messages sent to [sendText] / [sendBytes] are echoed back on [messages].
class InMemoryWebSocketProvider implements WebSocketProvider {
  final _controller = StreamController<dynamic>.broadcast();
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;

  @override
  WebSocketConnectionState get connectionState => _state;

  @override
  Stream<dynamic> get messages => _controller.stream;

  @override
  Future<void> connect(String url) async {
    _state = WebSocketConnectionState.connected;
  }

  @override
  Future<void> sendText(String message) async {
    if (_state != WebSocketConnectionState.connected) {
      throw StateError('Not connected');
    }
    _controller.add(message);
  }

  @override
  Future<void> sendBytes(List<int> data) async {
    if (_state != WebSocketConnectionState.connected) {
      throw StateError('Not connected');
    }
    _controller.add(data);
  }

  @override
  Future<void> disconnect() async {
    _state = WebSocketConnectionState.disconnected;
    await _controller.close();
  }
}
