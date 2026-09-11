import 'dart:io';

/// Errors thrown by [DartWebSocketProvider].
class WebSocketError implements Exception {
  /// The error message.
  final String message;

  /// Creates a [WebSocketError] with the given [message].
  const WebSocketError(this.message);

  @override
  String toString() => 'WebSocketError: $message';
}

/// Defines the contract for WebSocket connectivity.
abstract class WebSocketProvider {
  /// Opens a WebSocket connection to the given [url].
  Future<void> connect(String url);

  /// Sends a text [message] over the connection.
  Future<void> send(String message);

  /// Returns a Stream of incoming messages.
  Stream<String> get messages;

  /// Closes the WebSocket connection.
  Future<void> disconnect();
}

/// A [WebSocketProvider] backed by [dart:io] [WebSocket].
class DartWebSocketProvider implements WebSocketProvider {
  WebSocket? _socket;

  @override
  Future<void> connect(String url) async {
    _socket = await WebSocket.connect(url);
  }

  @override
  Future<void> send(String message) async {
    if (_socket == null) throw const WebSocketError('Not connected');
    _socket!.add(message);
  }

  @override
  Stream<String> get messages {
    if (_socket == null) throw const WebSocketError('Not connected');
    return _socket!.map((event) => event.toString());
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}
