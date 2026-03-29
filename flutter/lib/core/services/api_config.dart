import 'package:flutter/foundation.dart';

/// Central API configuration.
/// All API calls should reference this class for the base URL.
///
/// Configurable via `--dart-define` at build time:
///   --dart-define=API_PORT=8001       (dev port override)
///   --dart-define=API_BASE_URL=https://example.com  (production URL)
class ApiConfig {
  /// Go backend URL — auto-detects dev vs production.
  static String get baseUrl {
    if (kDebugMode) {
      const port = String.fromEnvironment('API_PORT', defaultValue: '8000');
      return 'http://localhost:$port';
    }
    const prodUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://highlander.lxrbckl.com',
    );
    return prodUrl;
  }

  /// Ollama calls should go through the Go backend, not directly from Flutter.
  /// Go endpoint: POST /api/chat (proxies to Ollama internally)
  /// Direct Ollama URL (dev/testing only): http://localhost:11434
}
