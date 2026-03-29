import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';
import 'action_dispatcher.dart';

/// The exact text the backend returns when Ollama is unavailable.
///
/// Kept in sync with the Go constant `ollamaOfflineMessage` in
/// `backend/internal/handlers/chat.go`.  The chat widget uses this to detect
/// offline/system messages and render them with distinct offline styling.
const String kOllamaOfflineMessage =
    'The AI assistant is currently offline. Please try again later.';

/// Result of a chat API call.
///
/// Holds the AI [response] text, any parsed [actions], or an [error] message.
class ChatResult {
  final String? response;
  final List<ChatAction> actions;
  final String? error;

  const ChatResult.success(String this.response, {this.actions = const []})
    : error = null;
  const ChatResult.failure(String this.error)
    : response = null,
      actions = const [];

  bool get isSuccess => response != null;
  bool get hasActions => actions.isNotEmpty;
}

/// Sends user messages to [POST /api/chat] and returns AI responses with
/// optional structured actions.
///
/// The backend parses Ollama's response for JSON action blocks and returns
/// a structured response:
/// ```json
/// {"response": "...", "actions": [{"action": "navigate", "route": "/incidents/new"}]}
/// ```
///
/// Follows SOLID/D — callers depend on this abstraction, not on `http` directly.
/// Degrades gracefully when Ollama is unavailable.
class ChatRepository {
  final http.Client _client;

  /// Cached wiki content loaded from the bundled asset. Loaded once on first
  /// message and reused for every subsequent request.
  String? _wikiCache;

  /// Inject [http.Client] for testability; defaults to a new instance.
  ChatRepository({http.Client? client}) : _client = client ?? http.Client();

  /// Loads `assets/wiki.md` and caches it in memory. Returns the cached value
  /// on subsequent calls.
  Future<String> _loadWiki() async {
    if (_wikiCache != null) return _wikiCache!;
    try {
      _wikiCache = await rootBundle.loadString('assets/wiki.md');
    } on Exception {
      // Asset missing or unreadable — degrade gracefully without wiki context.
      _wikiCache = '';
    }
    return _wikiCache!;
  }

  /// Sends [message] to the backend chat endpoint using [token] for auth.
  ///
  /// Returns a [ChatResult] — never throws. Callers should check
  /// [ChatResult.isSuccess] and [ChatResult.hasActions].
  Future<ChatResult> sendMessage(String message, {String? token}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/chat');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final wiki = await _loadWiki();
      final requestBody = <String, dynamic>{
        'prompt': message,
        if (wiki.isNotEmpty) 'system': wiki,
      };

      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(requestBody))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        // The enhanced backend returns {"response": "...", "actions": [...]}
        final text = body['response'] as String? ?? '';
        final actionsJson = body['actions'] as List<dynamic>?;
        final actions = parseActionsFromJson(actionsJson);

        return ChatResult.success(text.trim(), actions: actions);
      } else if (response.statusCode == 502) {
        return const ChatResult.failure(
          'AI assistant is offline. Make sure Ollama is running.',
        );
      } else {
        return ChatResult.failure(
          'Server error ${response.statusCode}. Please try again.',
        );
      }
    } on TimeoutException {
      return const ChatResult.failure(
        'The AI assistant is taking too long to respond. Please try again.',
      );
    } on Exception catch (e) {
      return ChatResult.failure('Could not reach the server: $e');
    }
  }
}
