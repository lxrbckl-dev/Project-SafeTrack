import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';

/// Result of a chat API call.
///
/// Either holds the AI [response] text, or an [error] message.
class ChatResult {
  final String? response;
  final String? error;

  const ChatResult.success(String this.response) : error = null;
  const ChatResult.failure(String this.error) : response = null;

  bool get isSuccess => response != null;
}

/// Sends user messages to [POST /api/chat] and returns AI responses.
///
/// Follows SOLID/D — callers depend on this abstraction, not on `http` directly.
/// Degrades gracefully when Ollama is unavailable.
class ChatRepository {
  final http.Client _client;

  /// Inject [http.Client] for testability; defaults to a new instance.
  ChatRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Sends [message] to the backend chat endpoint using [token] for auth.
  ///
  /// Returns a [ChatResult] — never throws. Callers should check [ChatResult.isSuccess].
  Future<ChatResult> sendMessage(String message, {String? token}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/chat');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode({'prompt': message}))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Ollama /api/generate returns {"response": "..."} when stream=false
        final text = body['response'] as String? ?? '';
        return ChatResult.success(text.trim());
      } else if (response.statusCode == 502) {
        return const ChatResult.failure(
          'AI assistant is offline. Make sure Ollama is running.',
        );
      } else {
        return ChatResult.failure(
          'Server error ${response.statusCode}. Please try again.',
        );
      }
    } on Exception catch (e) {
      return ChatResult.failure('Could not reach the server: $e');
    }
  }
}
