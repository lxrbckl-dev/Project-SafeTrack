import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/search_repository.dart';

/// Global search results page.
///
/// Reads the initial query from the `q` query parameter, provides a text field
/// for editing the query, and shows grouped results (Incidents, Investigations,
/// CAPAs) with debounced API calls (300 ms).
///
/// ADA/WCAG:
/// - Search field has a semantic label (WCAG 1.3.1)
/// - Results are grouped with section headers for screen readers
/// - Sufficient contrast on all text elements
/// - Keyboard navigable result rows
class SearchResultsPage extends StatefulWidget {
  final String initialQuery;

  const SearchResultsPage({super.key, this.initialQuery = ''});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late final TextEditingController _controller;
  late final SearchRepository _repo;
  Timer? _debounce;

  List<SearchResultItem> _results = [];
  bool _loading = false;
  String? _error;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    final auth = context.read<AuthService>();
    _repo = SearchRepository(auth);

    // Fire initial search if query provided via URL.
    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _repo.search(trimmed);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _hasSearched = true;
      });
    }
  }

  void _navigateToResult(SearchResultItem result) {
    switch (result.entityType) {
      case 'incident':
        context.go('/incidents/${result.entityId}');
        break;
      case 'investigation':
        context.go('/investigations/${result.entityId}');
        break;
      case 'capa':
        context.go('/capas/${result.entityId}');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Text(
            'Search',
            style: HerzogText.heading(
              fontSize: 24,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 16),

          // Search input
          Semantics(
            label: 'Search across incidents, investigations, and CAPAs',
            textField: true,
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search incidents, investigations, CAPAs...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: HerzogColors.midGray,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: HerzogColors.midGray,
                        ),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _controller.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? HerzogDarkColors.inputBorder : HerzogColors.inputBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: HerzogColors.navyBlue,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: isDark ? HerzogDarkColors.surfaceVariant : HerzogColors.white,
              ),
              style: HerzogText.body(
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Results area
          Expanded(child: _buildResultsArea()),
        ],
      ),
    );
  }

  Widget _buildResultsArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: HerzogColors.navyBlue),
            SizedBox(height: 12),
            Text('Searching...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: HerzogColors.errorRed,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Search failed',
              style: HerzogText.heading(
                fontSize: 16,
                color: HerzogColors.errorRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: HerzogText.body(
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _performSearch(_controller.text),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: HerzogColors.navyBlue,
                foregroundColor: HerzogColors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, color: HerzogColors.smoke, size: 64),
            const SizedBox(height: 12),
            Text(
              'Search across all records',
              style: HerzogText.body(
                fontSize: 16,
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Type a query above to search incidents, investigations, and CAPAs',
              style: HerzogText.body(
                fontSize: 13,
                color: isDark ? Colors.white : HerzogColors.smoke,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: HerzogColors.smoke, size: 64),
            const SizedBox(height: 12),
            Text(
              'No results found',
              style: HerzogText.heading(
                fontSize: 16,
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try different keywords or check your spelling',
              style: HerzogText.body(
                fontSize: 13,
                color: isDark ? Colors.white : HerzogColors.smoke,
              ),
            ),
          ],
        ),
      );
    }

    // Group results by entity type.
    final incidents = _results
        .where((r) => r.entityType == 'incident')
        .toList();
    final investigations = _results
        .where((r) => r.entityType == 'investigation')
        .toList();
    final capas = _results.where((r) => r.entityType == 'capa').toList();

    return ListView(
      children: [
        // Result count summary
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${_results.length} result${_results.length == 1 ? '' : 's'} found',
            style: HerzogText.body(
              fontSize: 13,
              color: isDark ? Colors.white : HerzogColors.midGray,
            ),
          ),
        ),
        if (incidents.isNotEmpty)
          _ResultSection(
            title: 'Incidents',
            icon: Icons.report_problem,
            color: HerzogColors.errorRed,
            results: incidents,
            onTap: _navigateToResult,
          ),
        if (investigations.isNotEmpty)
          _ResultSection(
            title: 'Investigations',
            icon: Icons.search,
            color: HerzogColors.navyBlue,
            results: investigations,
            onTap: _navigateToResult,
          ),
        if (capas.isNotEmpty)
          _ResultSection(
            title: 'CAPAs',
            icon: Icons.assignment_turned_in,
            color: HerzogColors.successGreen,
            results: capas,
            onTap: _navigateToResult,
          ),
      ],
    );
  }
}

/// A grouped section of search results with a header.
class _ResultSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<SearchResultItem> results;
  final void Function(SearchResultItem) onTap;

  const _ResultSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.results,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title section, ${results.length} results',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  '$title (${results.length})',
                  style: HerzogText.heading(fontSize: 15, color: color),
                ),
              ],
            ),
          ),
          // Result rows
          ...results.map(
            (result) => _ResultRow(result: result, onTap: () => onTap(result)),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// A single clickable search result row.
class _ResultRow extends StatelessWidget {
  final SearchResultItem result;
  final VoidCallback onTap;

  const _ResultRow({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: '${result.title}: ${result.snippet}',
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isDark ? HerzogDarkColors.inputBorder : HerzogColors.borderGray,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: HerzogText.body(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : HerzogColors.richBlack,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (result.snippet.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          result.snippet,
                          style: HerzogText.body(
                            color: isDark ? Colors.white : HerzogColors.darkGray,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: HerzogColors.midGray,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
