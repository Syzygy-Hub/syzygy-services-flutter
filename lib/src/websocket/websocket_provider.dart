import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
///
/// Mirrors the Android `WebSocketProvider` interface, which exposes both a
/// text [messages] stream and a typed [binaryMessages] stream so that callers
/// can consume binary frames without inspecting the runtime type of each event.
abstract class WebSocketProvider {
  /// Connects to [url].
  Future<void> connect(String url);

  /// Sends a text [message].
  Future<void> sendText(String message);

  /// Sends binary [data].
  Future<void> sendBytes(List<int> data);

  /// Stream of all incoming messages.
  ///
  /// Text frames are delivered as [String]s; binary frames are delivered as
  /// [List<int>]s (typically [Uint8List]).  Callers that only care about binary
  /// frames should prefer [binaryMessages].
  Stream<dynamic> get messages;

  /// Stream of binary frames received from the server as [Uint8List]s.
  ///
  /// Only binary WebSocket frames are emitted here — text frames are not
  /// included.  This mirrors the Android `binaryMessages: Flow<ByteArray>`
  /// property and allows typed binary-protocol consumers to avoid runtime
  /// `is List<int>` checks on the generic [messages] stream.
  ///
  /// The stream remains active until [disconnect] is called.
  Stream<Uint8List> get binaryMessages;

  /// The current connection state.
  WebSocketConnectionState get connectionState;

  /// Disconnects and releases resources.
  Future<void> disconnect();

  /// Releases all resources held by this provider.
  ///
  /// Closes any open WebSocket connection and closes internal stream
  /// controllers. Safe to call multiple times — subsequent calls are no-ops.
  void dispose();
}

/// [WebSocketProvider] backed by [dart:io] [WebSocket] with automatic
/// reconnection and exponential backoff.
class DartWebSocketProvider implements WebSocketProvider {
  WebSocket? _socket;
  StreamController<dynamic>? _messageController;
  StreamController<Uint8List>? _binaryController;
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  String? _lastUrl;
  int _retryCount = 0;
  bool _disposed = false;

  static const int _maxRetries = 5;

  @override
  WebSocketConnectionState get connectionState => _state;

  @override
  Stream<dynamic> get messages {
    _messageController ??= StreamController<dynamic>.broadcast();
    return _messageController!.stream;
  }

  /// Stream of binary frames received from the server.
  ///
  /// Binary WebSocket frames are emitted here as [Uint8List]s; text frames are
  /// not included.  Mirrors Android's `binaryMessages: Flow<ByteArray>`.
  @override
  Stream<Uint8List> get binaryMessages {
    _binaryController ??= StreamController<Uint8List>.broadcast();
    return _binaryController!.stream;
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
      _binaryController ??= StreamController<Uint8List>.broadcast();
      _socket!.listen(
        (event) {
          _messageController?.add(event);
          // Binary frames arrive as List<int>; forward them to binaryMessages.
          if (event is List<int>) {
            _binaryController?.add(Uint8List.fromList(event));
          }
        },
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
    await _binaryController?.close();
    _binaryController = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _lastUrl = null;
    _state = WebSocketConnectionState.disconnected;
    _socket?.close();
    _socket = null;
    if (_messageController != null && !_messageController!.isClosed) {
      _messageController!.close();
    }
    _messageController = null;
    if (_binaryController != null && !_binaryController!.isClosed) {
      _binaryController!.close();
    }
    _binaryController = null;
  }
}

/// In-memory [WebSocketProvider] for tests — no real network I/O.
///
/// Messages sent via [sendText] are echoed back on [messages].
/// Messages sent via [sendBytes] are echoed back on both [messages] (as a
/// [List<int>]) and on [binaryMessages] (as a [Uint8List]), matching the
/// dual-stream contract of the Android `InMemoryWebSocketProvider`.
class InMemoryWebSocketProvider implements WebSocketProvider {
  final _controller = StreamController<dynamic>.broadcast();
  final _binaryController = StreamController<Uint8List>.broadcast();
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  bool _disposed = false;

  @override
  WebSocketConnectionState get connectionState => _state;

  @override
  Stream<dynamic> get messages => _controller.stream;

  /// Stream of binary frames echoed from [sendBytes] calls.
  ///
  /// Each [Uint8List] emitted here corresponds to a [sendBytes] call in the
  /// same order it was made.  Text messages from [sendText] are not emitted
  /// here.
  @override
  Stream<Uint8List> get binaryMessages => _binaryController.stream;

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
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    _controller.add(bytes);
    _binaryController.add(bytes);
  }

  @override
  Future<void> disconnect() async {
    _state = WebSocketConnectionState.disconnected;
    await _controller.close();
    await _binaryController.close();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _state = WebSocketConnectionState.disconnected;
    if (!_controller.isClosed) _controller.close();
    if (!_binaryController.isClosed) _binaryController.close();
  }
}
