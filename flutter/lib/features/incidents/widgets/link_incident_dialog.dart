import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/incident_link_repository.dart';
import '../data/incident_repository.dart';

/// Dialog that lets a Safety Coordinator search for and link another incident
/// to the current one.
///
/// Displays a search field, a scrollable list of incidents, a similarity type
/// picker, and a notes field before submitting to POST /api/incident-links.
class LinkIncidentDialog extends StatefulWidget {
  /// The incident being linked FROM (the "source" incident).
  final int sourceIncidentId;

  /// Called with the newly created [IncidentLink] on success.
  final VoidCallback onLinked;

  const LinkIncidentDialog({
    super.key,
    required this.sourceIncidentId,
    required this.onLinked,
  });

  @override
  State<LinkIncidentDialog> createState() => _LinkIncidentDialogState();
}

class _LinkIncidentDialogState extends State<LinkIncidentDialog> {
  late final IncidentRepository _incidentRepo;
  late final IncidentLinkRepository _linkRepo;

  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Incident> _searchResults = [];
  Incident? _selectedIncident;
  String _similarityType = kSimilarityTypes.first;
  bool _loadingSearch = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _incidentRepo = IncidentRepository(auth);
    _linkRepo = IncidentLinkRepository(auth);
    _loadAllIncidents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadAllIncidents({String query = ''}) async {
    setState(() {
      _loadingSearch = true;
      _error = null;
    });
    try {
      final result = await _incidentRepo.listIncidents(perPage: 100);
      final filtered = result.data
          .where(
            (inc) =>
                inc.id != widget.sourceIncidentId &&
                (query.isEmpty ||
                    inc.location.toLowerCase().contains(query.toLowerCase()) ||
                    inc.type.toLowerCase().contains(query.toLowerCase()) ||
                    inc.division.toLowerCase().contains(query.toLowerCase()) ||
                    (inc.id?.toString() ?? '').contains(query)),
          )
          .toList();
      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _loadingSearch = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingSearch = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedIncident == null) {
      setState(() => _error = 'Please select an incident to link.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _linkRepo.createLink(
        incidentId1: widget.sourceIncidentId,
        incidentId2: _selectedIncident!.id!,
        similarityType: _similarityType,
        notes: _notesController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onLinked();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'LINK INCIDENT',
                        style: HerzogText.heading(fontSize: 18),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(height: 2, width: 32, color: HerzogColors.gold),
                const SizedBox(height: 20),

                // Search field
                Semantics(
                  label: 'Search incidents by ID, type, location, or division',
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Incidents',
                      hintText: 'ID, type, location, or division',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (val) => _loadAllIncidents(query: val),
                  ),
                ),
                const SizedBox(height: 12),

                // Results list
                Expanded(
                  child: _loadingSearch
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty
                      ? Center(
                          child: Text(
                            'No incidents found.',
                            style: HerzogText.body(color: HerzogColors.midGray),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final inc = _searchResults[index];
                            final selected = _selectedIncident?.id == inc.id;
                            return Semantics(
                              selected: selected,
                              child: ListTile(
                                dense: true,
                                selected: selected,
                                selectedTileColor: HerzogColors.navyBlue
                                    .withValues(alpha: 0.08),
                                leading: selected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: HerzogColors.navyBlue,
                                      )
                                    : const Icon(Icons.circle_outlined),
                                title: Text(
                                  '#${inc.id} — ${inc.type}',
                                  style: HerzogText.body(
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                subtitle: Text(
                                  '${inc.location}  •  ${inc.division}  •  ${inc.status}',
                                  style: HerzogText.body(
                                    fontSize: 12,
                                    color: HerzogColors.midGray,
                                  ),
                                ),
                                onTap: () =>
                                    setState(() => _selectedIncident = inc),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),

                // Similarity type dropdown
                Semantics(
                  label: 'Similarity type',
                  child: DropdownButtonFormField<String>(
                    initialValue: _similarityType,
                    decoration: const InputDecoration(
                      labelText: 'Similarity Type',
                    ),
                    items: kSimilarityTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _similarityType = val);
                    },
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Notes field
                Semantics(
                  label: 'Notes (optional)',
                  child: TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Describe how these incidents are related...',
                    ),
                  ),
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: HerzogText.body(
                      fontSize: 13,
                      color: HerzogColors.errorRed,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Action row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link, size: 16),
                      label: const Text('Link Incident'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HerzogColors.navyBlue,
                        foregroundColor: HerzogColors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
