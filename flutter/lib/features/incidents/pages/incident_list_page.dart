import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/sync_status.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../../dashboard/widgets/welcome_header.dart';
import '../data/incident_repository.dart';
import '../widgets/status_badge.dart';

/// Displays a filterable, pull-to-refresh list of incidents.
///
/// Features:
/// - Status, type, and division filter dropdowns
/// - Color-coded status badges
/// - Type icons per incident type
/// - Severity indicator
/// - "New Incident" FAB visible to Field Reporter and above
/// - Tap row navigates to detail page
/// - Empty state with illustration
class IncidentListPage extends StatefulWidget {
  const IncidentListPage({super.key});

  @override
  State<IncidentListPage> createState() => _IncidentListPageState();
}

class _IncidentListPageState extends State<IncidentListPage> {
  late final IncidentRepository _repo;
  List<Incident> _incidents = [];
  List<OfflineIncident> _offlineIncidents = [];
  bool _loading = true;
  String? _error;

  // Filters
  String? _statusFilter;
  String? _typeFilter;
  String? _divisionFilter;

  static const _incidentTypes = [
    'Injury',
    'Near Miss',
    'Property Damage',
    'Environmental',
    'Vehicle',
    'Fire',
    'Utility Strike',
  ];

  static const _statuses = [
    'Draft',
    'Reported',
    'Under Investigation',
    'Investigation Complete',
    'CAPA Assigned',
    'CAPA In Progress',
    'Closed',
    'Reopened',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _repo = IncidentRepository(auth);
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Load offline incidents from Drift (always available)
      final db = context.read<AppDatabase>();
      final offline = await db.getUnsyncedIncidents();
      if (mounted) {
        setState(() {
          _offlineIncidents = offline;
        });
      }

      // Try to load remote incidents from API
      final response = await _repo.listIncidents(
        status: _statusFilter,
        type: _typeFilter,
        division: _divisionFilter,
      );
      if (mounted) {
        setState(() {
          _incidents = response.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'Injury':
        return Icons.personal_injury;
      case 'Near Miss':
        return Icons.warning_amber;
      case 'Property Damage':
        return Icons.domain_disabled;
      case 'Environmental':
        return Icons.eco;
      case 'Vehicle':
        return Icons.directions_car;
      case 'Fire':
        return Icons.local_fire_department;
      case 'Utility Strike':
        return Icons.flash_on;
      default:
        return Icons.report_problem;
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'fatality':
        return HerzogColors.errorRed;
      case 'lost time':
        return HerzogColors.errorRed;
      case 'medical treatment':
        return HerzogColors.warningAmber;
      case 'first aid':
        return HerzogColors.infoTeal;
      case 'near miss':
        return HerzogColors.successGreen;
      default:
        return HerzogColors.midGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    // All roles can create incidents EXCEPT Executive (read-only).
    final canCreate =
        auth.isAtLeast(Role.fieldReporter) &&
        auth.currentRole != Role.executive;

    return Scaffold(
      appBar: AppBar(title: const Text('INCIDENTS')),
      body: Column(
        children: [
          // Welcome header shown to Field Reporter (their primary landing page).
          if (auth.currentRole == Role.fieldReporter) const WelcomeHeader(),
          // Filters
          _buildFilters(),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _offlineIncidents.isEmpty
                ? _buildError()
                : _incidents.isEmpty && _offlineIncidents.isEmpty
                ? _buildEmpty()
                : _buildList(),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? Semantics(
              label: 'Create new incident report',
              button: true,
              child: FloatingActionButton.extended(
                onPressed: () => context.go('/incidents/new'),
                backgroundColor: HerzogColors.navyBlue,
                foregroundColor: HerzogColors.white,
                icon: const Icon(Icons.add),
                label: const Text('NEW INCIDENT'),
              ),
            )
          : null,
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: HerzogColors.white,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          // Status filter
          _FilterDropdown(
            label: 'Status',
            value: _statusFilter,
            items: _statuses,
            onChanged: (v) {
              setState(() => _statusFilter = v);
              _loadIncidents();
            },
          ),
          // Type filter
          _FilterDropdown(
            label: 'Type',
            value: _typeFilter,
            items: _incidentTypes,
            onChanged: (v) {
              setState(() => _typeFilter = v);
              _loadIncidents();
            },
          ),
          // Division filter
          SizedBox(
            width: 180,
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Division',
                labelStyle: HerzogText.label(fontSize: 11),
                isDense: true,
                suffixIcon:
                    _divisionFilter != null && _divisionFilter!.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          setState(() => _divisionFilter = null);
                          _loadIncidents();
                        },
                      )
                    : null,
              ),
              style: HerzogText.body(fontSize: 13),
              onSubmitted: (v) {
                setState(() => _divisionFilter = v.isEmpty ? null : v);
                _loadIncidents();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: HerzogColors.errorRed,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load incidents',
            style: HerzogText.heading(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(color: HerzogColors.midGray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadIncidents,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment,
            size: 64,
            color: HerzogColors.smoke.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No incidents found',
            style: HerzogText.heading(
              fontSize: 18,
              color: HerzogColors.midGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust your filters or create a new incident report.',
            style: HerzogText.body(color: HerzogColors.smoke),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadIncidents,
      color: HerzogColors.navyBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Offline incidents (pending sync) shown first
          if (_offlineIncidents.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'PENDING SYNC',
                style: HerzogText.heading(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: HerzogColors.warningAmber,
                ),
              ),
            ),
            ..._offlineIncidents.map(
              (offline) => _OfflineIncidentCard(
                incident: offline,
                icon: _iconForType(offline.type),
              ),
            ),
            const Divider(height: 24),
          ],
          // Regular incidents from API
          ..._incidents.map(
            (incident) => _IncidentCard(
              incident: incident,
              icon: _iconForType(incident.type),
              severityColor: _severityColor(incident.severity),
              onTap: () {
                if (incident.id != null) {
                  context.go('/incidents/${incident.id}');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A single incident card in the list.
class _IncidentCard extends StatelessWidget {
  final Incident incident;
  final IconData icon;
  final Color severityColor;
  final VoidCallback onTap;

  const _IncidentCard({
    required this.incident,
    required this.icon,
    required this.severityColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = incident.date != null
        ? DateFormat('MM/dd/yyyy').format(incident.date!)
        : 'No date';

    return Semantics(
      label: '${incident.type} incident, ${incident.status}, $dateStr',
      button: true,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: HerzogColors.navyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: HerzogColors.navyBlue, size: 22),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              incident.type.isNotEmpty
                                  ? incident.type
                                  : 'Untitled',
                              style: HerzogText.body(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: HerzogColors.richBlack,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusBadge(status: incident.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateStr  |  ${incident.location.isNotEmpty ? incident.location : "No location"}',
                        style: HerzogText.body(
                          fontSize: 12,
                          color: HerzogColors.midGray,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (incident.division.isNotEmpty ||
                          incident.severity.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              if (incident.division.isNotEmpty)
                                Text(
                                  incident.division,
                                  style: HerzogText.body(
                                    fontSize: 12,
                                    color: HerzogColors.smoke,
                                  ),
                                ),
                              if (incident.division.isNotEmpty &&
                                  incident.severity.isNotEmpty)
                                const Text('  |  '),
                              if (incident.severity.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: severityColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      incident.severity,
                                      style: HerzogText.body(
                                        fontSize: 12,
                                        color: severityColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: HerzogColors.smoke,
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

/// Card for an offline-saved incident with a "pending sync" badge.
///
/// Provides action buttons so users can act on the record:
/// - error status: "Retry" (triggers sync) and "Discard" (with confirmation).
/// - pending status: "Discard" (with confirmation).
///
/// Wrapped in [InkWell] and annotated with [Semantics] for ADA compliance.
class _OfflineIncidentCard extends StatelessWidget {
  final OfflineIncident incident;
  final IconData icon;

  const _OfflineIncidentCard({required this.incident, required this.icon});

  Future<void> _handleRetry(BuildContext context) async {
    final syncService = context.read<SyncService>();
    await syncService.syncIncidents();
  }

  Future<void> _handleDiscard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Offline Incident?'),
        content: const Text(
          'This will permanently delete the locally saved incident. '
          'It has not been uploaded to the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: HerzogColors.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final db = context.read<AppDatabase>();
      await db.deleteOfflineIncident(incident.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = incident.date != null
        ? DateFormat('MM/dd/yyyy').format(incident.date!)
        : 'No date';

    final isError = incident.syncStatus == SyncStatus.error;
    final statusLabel = isError ? 'Sync Error' : 'Pending Sync';
    final statusColor = isError
        ? HerzogColors.errorRed
        : HerzogColors.warningAmber;

    return Semantics(
      label: '${incident.type} incident, $statusLabel, $dateStr, saved offline',
      button: true,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isError ? () => _handleRetry(context) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Type icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  incident.type.isNotEmpty
                                      ? incident.type
                                      : 'Untitled',
                                  style: HerzogText.body(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: HerzogColors.richBlack,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Sync status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isError
                                          ? Icons.error_outline
                                          : Icons.cloud_upload_outlined,
                                      size: 12,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusLabel,
                                      style: HerzogText.label(
                                        fontSize: 10,
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$dateStr  |  ${incident.location.isNotEmpty ? incident.location : "No location"}',
                            style: HerzogText.body(
                              fontSize: 12,
                              color: HerzogColors.midGray,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isError && incident.syncError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                incident.syncError,
                                style: HerzogText.body(
                                  fontSize: 11,
                                  color: HerzogColors.errorRed,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Action buttons row
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isError)
                      Semantics(
                        button: true,
                        label: 'Retry syncing this incident',
                        child: TextButton.icon(
                          onPressed: () => _handleRetry(context),
                          icon: const Icon(Icons.replay, size: 16),
                          label: const Text('Retry'),
                          style: TextButton.styleFrom(
                            foregroundColor: HerzogColors.navyBlue,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Discard this offline incident',
                      child: TextButton.icon(
                        onPressed: () => _handleDiscard(context),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Discard'),
                        style: TextButton.styleFrom(
                          foregroundColor: HerzogColors.errorRed,
                        ),
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

/// Compact filter dropdown for the filter bar.
class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: HerzogText.label(fontSize: 11),
          isDense: true,
        ),
        style: HerzogText.body(fontSize: 13, color: HerzogColors.darkGray),
        dropdownColor: HerzogColors.white,
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('All', style: HerzogText.body(fontSize: 13)),
          ),
          ...items.map(
            (item) => DropdownMenuItem<String>(value: item, child: Text(item)),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
