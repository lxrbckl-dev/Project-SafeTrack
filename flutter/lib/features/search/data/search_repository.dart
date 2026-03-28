import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/api_config.dart';
import '../../auth/data/auth_service.dart';

/// A single search result from the global search API.
class SearchResultItem {
  final String entityType;
  final int entityId;
  final String title;
  final String snippet;
  final int relevance;

  const SearchResultItem({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.snippet,
    required this.relevance,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    return SearchResultItem(
      entityType: json['entityType'] as String? ?? '',
      entityId: (json['entityId'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      relevance: (json['relevance'] as num?)?.toInt() ?? 0,
    );
  }

  /// Returns a human-readable label for the entity type.
  String get entityTypeLabel {
    switch (entityType) {
      case 'incident':
        return 'Incident';
      case 'investigation':
        return 'Investigation';
      case 'capa':
        return 'CAPA';
      default:
        return entityType;
    }
  }
}

/// API client for the global search endpoint.
class SearchRepository {
  final AuthService _auth;

  SearchRepository(this._auth);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  String get _base => ApiConfig.baseUrl;

  /// Searches across incidents, investigations, and CAPAs.
  /// Returns an empty list when [query] is blank.
  Future<List<SearchResultItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    final uri = Uri.parse(
      '$_base/api/search',
    ).replace(queryParameters: {'q': trimmed});
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Search failed: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => SearchResultItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
