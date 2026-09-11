import 'dart:convert';
import 'dart:io';

/// Defines the contract for performing HTTP network requests.
abstract class NetworkClient {
  /// Performs a GET request to [url] and returns the response body.
  Future<String> get(String url);

  /// Performs a POST request to [url] with [body] and returns the response body.
  Future<String> post(String url, String body);
}

/// A [NetworkClient] backed by [HttpClient].
class HttpNetworkClient implements NetworkClient {
  final HttpClient _client;

  /// Initialises the client with an optional [HttpClient].
  HttpNetworkClient({HttpClient? client}) : _client = client ?? HttpClient();

  @override
  Future<String> get(String url) async {
    final request = await _client.getUrl(Uri.parse(url));
    final response = await request.close();
    return utf8.decoder.bind(response).join();
  }

  @override
  Future<String> post(String url, String body) async {
    final request = await _client.postUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    return utf8.decoder.bind(response).join();
  }
}
