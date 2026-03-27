import 'package:flutter/foundation.dart';

/// Central API configuration.
/// All API calls should reference this class for the base URL.
class ApiConfig {
  /// Go backend URL — auto-detects dev vs production.
  /// Override with --dart-define=API_PORT=8001 for QA testing.
  static String get baseUrl {
    if (kDebugMode) {
      const port = String.fromEnvironment('API_PORT', defaultValue: '8000');
      return 'http://localhost:$port';
    }
    // In production, Caddy proxies /api/* to the Go backend.
    return 'https://themarchproject.lxrbckl.com';
  }

  /// Ollama calls should go through the Go backend, not directly from Flutter.
  /// Go endpoint: POST /api/chat (proxies to Ollama internally)
  /// Direct Ollama URL (dev/testing only): http://localhost:11434
}
