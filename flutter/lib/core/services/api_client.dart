import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/auth/data/auth_service.dart';
import 'api_config.dart';

/// Exception thrown when the server returns a 401 Unauthorized response.
///
/// This triggers an automatic logout via [ApiClient], redirecting the user
/// back to the login screen through GoRouter's redirect guard.
class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Session expired']);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Shared HTTP client that wraps [http.get], [http.post], [http.put], and
/// [http.delete] with automatic 401 handling.
///
/// When any API response returns HTTP 401, the client calls
/// [AuthService.handleUnauthorized] which clears credentials and notifies
/// listeners. Because GoRouter watches [AuthService] via `refreshListenable`,
/// this automatically redirects the user to `/login`.
///
/// Usage: repositories that previously called `http.get(...)` directly should
/// instead inject an [ApiClient] and call `apiClient.get(...)`.
class ApiClient {
  final AuthService _auth;

  ApiClient(this._auth);

  /// Standard JSON + Bearer headers.
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  /// The base URL for all API calls.
  String get baseUrl => ApiConfig.baseUrl;

  /// Checks the response for a 401 status code.
  /// If 401, calls [AuthService.handleUnauthorized] and throws
  /// [UnauthorizedException] so callers can short-circuit.
  http.Response _checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      _auth.handleUnauthorized();
      throw const UnauthorizedException();
    }
    return response;
  }

  /// Sends a GET request and checks for 401.
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final response = await http.get(url, headers: headers ?? _headers);
    return _checkResponse(response);
  }

  /// Sends a POST request and checks for 401.
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await http.post(
      url,
      headers: headers ?? _headers,
      body: body,
      encoding: encoding,
    );
    return _checkResponse(response);
  }

  /// Sends a PUT request and checks for 401.
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await http.put(
      url,
      headers: headers ?? _headers,
      body: body,
      encoding: encoding,
    );
    return _checkResponse(response);
  }

  /// Sends a DELETE request and checks for 401.
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await http.delete(
      url,
      headers: headers ?? _headers,
      body: body,
      encoding: encoding,
    );
    return _checkResponse(response);
  }

  /// Sends a multipart request and checks for 401 on the streamed response.
  /// Returns the full [http.Response] after reading the stream.
  Future<http.Response> sendMultipart(http.MultipartRequest request) async {
    if (_auth.token != null) {
      request.headers['Authorization'] = 'Bearer ${_auth.token}';
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _checkResponse(response);
  }
}
