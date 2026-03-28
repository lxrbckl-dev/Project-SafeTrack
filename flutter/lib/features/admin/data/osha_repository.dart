import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';

/// Repository for OSHA CSV log export endpoints.
///
/// Each method fetches the CSV bytes from the Go backend.
/// Callers handle platform-specific file saving or sharing.
class OshaRepository {
  final http.Client _client;

  OshaRepository({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
  };

  /// Fetches the OSHA Form 300 CSV for [year].
  /// Returns raw UTF-8 CSV bytes on success; throws on error.
  Future<Uint8List> fetchForm300(String token, int year) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/osha/300?year=$year');
    final response = await _client.get(uri, headers: _headers(token));
    if (response.statusCode == 403) {
      throw Exception('Forbidden: Safety Manager or Admin role required');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to download OSHA 300: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  /// Fetches the OSHA Form 300A CSV for [year].
  Future<Uint8List> fetchForm300A(String token, int year) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/osha/300a?year=$year');
    final response = await _client.get(uri, headers: _headers(token));
    if (response.statusCode == 403) {
      throw Exception('Forbidden: Safety Manager or Admin role required');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to download OSHA 300A: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  /// Fetches the OSHA Form 301 CSV for a specific incident.
  Future<Uint8List> fetchForm301(String token, int incidentId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/osha/301/$incidentId');
    final response = await _client.get(uri, headers: _headers(token));
    if (response.statusCode == 403) {
      throw Exception('Forbidden: Safety Manager or Admin role required');
    }
    if (response.statusCode == 400) {
      throw Exception('Incident is not OSHA recordable');
    }
    if (response.statusCode == 404) {
      throw Exception('Incident not found');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to download OSHA 301: ${response.statusCode}');
    }
    return response.bodyBytes;
  }
}
