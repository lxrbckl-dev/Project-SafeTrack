import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../data/incident_repository.dart';
import '../widgets/status_badge.dart';

/// Read-only detail view of an incident with tabs for future integration.
///
/// Features:
/// - Full incident field display
/// - Photos grid
/// - Status badge at top
/// - Medical fields gated by role (Safety Coordinator+)
/// - Tabs: Info, OSHA, Investigation (placeholder), CAPAs (placeholder),
///   Recurrence (placeholder)
/// - Action buttons based on role and status
class IncidentDetailPage extends StatefulWidget {
  final int incidentId;

  const IncidentDetailPage({super.key, required this.incidentId});

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage>
    with SingleTickerProviderStateMixin {
  late final IncidentRepository _repo;
  late final AuthService _auth;
  late final TabController _tabController;

  Incident? _incident;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _repo = IncidentRepository(_auth);
    _tabController = TabController(length: 5, vsync: this);
    _loadIncident();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadIncident() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final incident = await _repo.getIncident(widget.incidentId);
      if (mounted) {
        setState(() {
          _incident = incident;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('INCIDENT DETAIL'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/incidents'),
          tooltip: 'Back to incidents',
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'INFO'),
            Tab(text: 'OSHA'),
            Tab(text: 'INVESTIGATION'),
            Tab(text: 'CAPAs'),
            Tab(text: 'RECURRENCE'),
          ],
          isScrollable: true,
          tabAlignment: TabAlignment.start,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildOshaTab(),
                _buildPlaceholderTab(
                  'Investigation',
                  'Investigation details (TASK-007)',
                ),
                _buildPlaceholderTab('CAPAs', 'CAPA management (TASK-009)'),
                _buildPlaceholderTab(
                  'Recurrence',
                  'Recurrence linking (TASK-011)',
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
            'Failed to load incident',
            style: HerzogText.heading(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadIncident,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    final incident = _incident!;
    final canSeeMedical = _auth.isAtLeast(Role.safetyCoordinator);
    final dateStr = incident.date != null
        ? DateFormat('MM/dd/yyyy hh:mm a').format(incident.date!)
        : 'Not set';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and actions header
            _buildHeader(incident),
            const SizedBox(height: 20),

            // Basic Info
            _sectionTitle('BASIC INFORMATION'),
            _detailRow('Type', incident.type),
            _detailRow('Date', dateStr),
            _detailRow('Location', incident.location),
            if (incident.latitude != 0 || incident.longitude != 0)
              _detailRow(
                'Coordinates',
                '${incident.latitude.toStringAsFixed(6)}, ${incident.longitude.toStringAsFixed(6)}',
              ),
            _detailRow('Division', incident.division),
            _detailRow('Project / Job Site', incident.projectJobSite),
            const SizedBox(height: 16),

            // Description
            _sectionTitle('DESCRIPTION'),
            _detailRow('Description', incident.description),
            _detailRow('Immediate Actions', incident.immediateActions),
            const SizedBox(height: 16),

            // Classification
            _sectionTitle('CLASSIFICATION'),
            _detailRow('Severity', incident.severity),
            _detailRow('Potential Severity', incident.potentialSeverity),
            _detailRow('Shift', incident.shift),
            _detailRow('Weather', incident.weather),
            _detailRow('Completion', '${incident.completionPercent}%'),
            const SizedBox(height: 16),

            // Railroad
            if (incident.isRailroadProperty) ...[
              _sectionTitle('RAILROAD'),
              _detailRow('Railroad Client', incident.railroadClient),
              _detailRow(
                'Client Notified',
                incident.railroadNotified ? 'Yes' : 'No',
              ),
              if (incident.railroadNotified) ...[
                _detailRow(
                  'Notification Method',
                  incident.railroadNotificationMethod,
                ),
                if (incident.railroadNotificationDate != null)
                  _detailRow(
                    'Notification Date',
                    DateFormat(
                      'MM/dd/yyyy hh:mm a',
                    ).format(incident.railroadNotificationDate!),
                  ),
              ],
              if (incident.railroadNotificationOverdue)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HerzogColors.errorLight,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning,
                        size: 16,
                        color: HerzogColors.errorRed,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Railroad notification is OVERDUE',
                        style: HerzogText.body(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HerzogColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],

            // Injured Persons
            if (incident.injuredPersons.isNotEmpty) ...[
              _sectionTitle('INJURED PERSONS'),
              ...incident.injuredPersons.map(
                (p) => _buildInjuredPerson(p, canSeeMedical),
              ),
              const SizedBox(height: 16),
            ],

            // Photos
            if (incident.photos.isNotEmpty) ...[
              _sectionTitle('PHOTOS'),
              _buildPhotoGrid(incident.photos),
              const SizedBox(height: 16),
            ],

            // OSHA Status
            _sectionTitle('OSHA STATUS'),
            _detailRow(
              'Recordable',
              incident.isOshaRecordable == null
                  ? 'Not determined'
                  : incident.isOshaRecordable!
                  ? 'Yes'
                  : 'No',
            ),
            _detailRow(
              'DART',
              incident.isDart == null
                  ? 'Not determined'
                  : incident.isDart!
                  ? 'Yes'
                  : 'No',
            ),
            if (incident.oshaOverrideJustification.isNotEmpty)
              _detailRow(
                'Override Justification',
                incident.oshaOverrideJustification,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Incident incident) {
    final role = _auth.currentRole;
    final isReporter = incident.reporterId == _auth.userId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StatusBadge(status: incident.status),
            const Spacer(),
            // Action buttons based on role + status
            Wrap(
              spacing: 8,
              children: [
                // Edit: reporter can edit if draft or Reported
                if (isReporter &&
                    (incident.status == 'Draft' ||
                        incident.status == 'Reported'))
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.go('/incidents/${incident.id}/edit'),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),

                // Start Investigation: Safety Manager + Reported status
                if (role != null &&
                    role.isAtLeast(Role.safetyManager) &&
                    incident.status == 'Reported')
                  ElevatedButton.icon(
                    onPressed: () {
                      // Placeholder: navigate to investigation form when built
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Investigation form not yet available (TASK-007)',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Start Investigation'),
                  ),

                // Run OSHA Determination: Safety Coordinator+, not yet determined
                if (role != null &&
                    role.isAtLeast(Role.safetyCoordinator) &&
                    incident.isOshaRecordable == null)
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.go('/incidents/${incident.id}/osha'),
                    icon: const Icon(Icons.checklist, size: 16),
                    label: const Text('OSHA Determination'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HerzogColors.gold,
                      foregroundColor: HerzogColors.richBlack,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInjuredPerson(InjuredPerson person, bool canSeeMedical) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Name', person.name),
            _detailRow('Job Title', person.jobTitle),
            _detailRow('Division', person.division),
            if (canSeeMedical) ...[
              _detailRow('Injury Type', person.injuryType),
              _detailRow('Body Part', person.bodyPart),
              _detailRow('Side', person.bodyPartSide),
              _detailRow('Treatment Type', person.treatmentType),
              _detailRow('Return to Work', person.returnToWorkStatus),
            ] else ...[
              _detailRow('Injury Type', '[RESTRICTED]'),
              _detailRow('Body Part', '[RESTRICTED]'),
              _detailRow('Treatment Type', '[RESTRICTED]'),
              _detailRow('Return to Work', '[RESTRICTED]'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<IncidentPhoto> photos) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: photos.map((photo) {
        return Semantics(
          label: 'Photo: ${photo.fileName}',
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: HerzogColors.lightGray,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HerzogColors.borderGray),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image, color: HerzogColors.navyBlue, size: 32),
                const SizedBox(height: 4),
                Text(
                  photo.fileName.length > 12
                      ? '${photo.fileName.substring(0, 12)}...'
                      : photo.fileName,
                  style: HerzogText.body(
                    fontSize: 10,
                    color: HerzogColors.midGray,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOshaTab() {
    final incident = _incident!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('OSHA RECORDABILITY'),
            const SizedBox(height: 12),
            _detailRow(
              'Status',
              incident.isOshaRecordable == null
                  ? 'Not yet determined'
                  : incident.isOshaRecordable!
                  ? 'RECORDABLE'
                  : 'Not Recordable',
            ),
            _detailRow(
              'DART',
              incident.isDart == null
                  ? 'Not yet determined'
                  : incident.isDart!
                  ? 'DART Case'
                  : 'Not a DART case',
            ),
            if (incident.oshaOverrideJustification.isNotEmpty)
              _detailRow(
                'Override Justification',
                incident.oshaOverrideJustification,
              ),
            const SizedBox(height: 20),
            if (_auth.isAtLeast(Role.safetyCoordinator))
              ElevatedButton.icon(
                onPressed: () => context.go('/incidents/${incident.id}/osha'),
                icon: const Icon(Icons.checklist, size: 16),
                label: Text(
                  incident.isOshaRecordable == null
                      ? 'Run OSHA Determination'
                      : 'View / Override OSHA Determination',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, String description) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.construction,
            size: 48,
            color: HerzogColors.smoke.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(title, style: HerzogText.heading(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            description,
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: HerzogText.heading(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 2),
          Container(height: 2, width: 30, color: HerzogColors.gold),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: HerzogText.label(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: HerzogColors.midGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: HerzogText.body(
                fontSize: 14,
                color: HerzogColors.darkGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
