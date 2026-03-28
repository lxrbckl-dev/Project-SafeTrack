import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../../capas/data/capa_repository.dart';
import '../../investigations/data/investigation_repository.dart';
import '../data/incident_link_repository.dart';
import '../data/incident_repository.dart';
import '../widgets/link_incident_dialog.dart';
import '../widgets/status_badge.dart';

/// Read-only detail view of an incident with integrated tabs.
///
/// Features:
/// - Full incident field display
/// - Photos grid
/// - Status badge at top
/// - Medical fields gated by role (Safety Coordinator+)
/// - Tabs: Info, OSHA, Investigation, CAPAs, Recurrence
/// - Action buttons: Edit, Start Investigation, OSHA Determination, Close, Reopen
/// - Close validates all CAPAs verified effective (backend enforces)
/// - Reopen available from Closed status (Safety Manager+)
class IncidentDetailPage extends StatefulWidget {
  final int incidentId;

  const IncidentDetailPage({super.key, required this.incidentId});

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage>
    with SingleTickerProviderStateMixin {
  late final IncidentRepository _repo;
  late final InvestigationRepository _invRepo;
  late final IncidentLinkRepository _linkRepo;
  late final CAPARepository _capaRepo;
  late final AuthService _auth;
  late final TabController _tabController;

  Incident? _incident;
  Investigation? _linkedInvestigation;
  List<IncidentLink> _links = [];
  List<CAPA> _capas = [];
  List<RecurrenceMatch> _suggestions = [];
  bool _linksLoading = false;
  bool _capasLoading = false;
  bool _suggestionsLoading = false;
  bool _suggestionsChecked = false;
  bool _loading = true;
  bool _closing = false;
  bool _reopening = false;
  String? _error;
  String? _suggestionsError;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _repo = IncidentRepository(_auth);
    _invRepo = InvestigationRepository(_auth);
    _linkRepo = IncidentLinkRepository(_auth);
    _capaRepo = CAPARepository(_auth);
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
      // Try to load linked investigation
      Investigation? linkedInv;
      try {
        final invResult = await _invRepo.listInvestigations(
          incidentId: widget.incidentId,
        );
        if (invResult.data.isNotEmpty) {
          linkedInv = invResult.data.first;
        }
      } catch (_) {
        // Investigation may not exist yet, that's fine
      }
      if (mounted) {
        setState(() {
          _incident = incident;
          _linkedInvestigation = linkedInv;
          _loading = false;
        });
        // Load recurrence links and CAPAs in the background after main data is ready.
        _loadLinks();
        _loadCapas();
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

  Future<void> _loadLinks() async {
    setState(() => _linksLoading = true);
    try {
      final links = await _linkRepo.getLinksForIncident(widget.incidentId);
      if (mounted) setState(() => _links = links);
    } catch (_) {
      // Non-fatal — recurrence tab shows empty state.
    } finally {
      if (mounted) setState(() => _linksLoading = false);
    }
  }

  Future<void> _loadCapas() async {
    setState(() => _capasLoading = true);
    try {
      final result = await _capaRepo.listCAPAs(incidentId: widget.incidentId);
      if (mounted) setState(() => _capas = result.data);
    } catch (_) {
      // Non-fatal — CAPAs tab shows empty state.
    } finally {
      if (mounted) setState(() => _capasLoading = false);
    }
  }

  Future<void> _checkRecurrence() async {
    setState(() {
      _suggestionsLoading = true;
      _suggestionsError = null;
    });
    try {
      final suggestions = await _linkRepo.checkRecurrence(widget.incidentId);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _suggestionsChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestionsError = e.toString();
          _suggestionsChecked = true;
        });
      }
    } finally {
      if (mounted) setState(() => _suggestionsLoading = false);
    }
  }

  Future<void> _confirmSuggestion(RecurrenceMatch match) async {
    try {
      // Use the primary match criterion for the link's similarity type.
      final similarityType = match.matchCriteria.isNotEmpty
          ? match.matchCriteria.first
          : 'Same Type';
      await _linkRepo.createLink(
        incidentId1: widget.incidentId,
        incidentId2: match.incidentId,
        similarityType: similarityType,
        notes: 'Auto-detected: ${match.similarityType}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Linked to incident #${match.incidentId}'),
            backgroundColor: HerzogColors.successGreen,
          ),
        );
        // Remove from suggestions list and refresh links.
        setState(() {
          _suggestions.removeWhere((s) => s.incidentId == match.incidentId);
        });
        _loadLinks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to link incident: $e'),
            backgroundColor: HerzogColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _dismissSuggestion(RecurrenceMatch match) async {
    try {
      await _linkRepo.dismissSuggestion(
        incidentId: widget.incidentId,
        suggestedIncidentId: match.incidentId,
      );
      if (mounted) {
        setState(() {
          _suggestions.removeWhere((s) => s.incidentId == match.incidentId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss suggestion: $e'),
            backgroundColor: HerzogColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _closeIncident() async {
    setState(() => _closing = true);
    try {
      final updated = await _repo.closeIncident(widget.incidentId);
      if (mounted) {
        setState(() => _incident = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident closed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cannot close incident: $e')));
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _reopenIncident() async {
    setState(() => _reopening = true);
    try {
      final updated = await _repo.reopenIncident(widget.incidentId);
      if (mounted) {
        setState(() => _incident = updated);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incident reopened')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reopen incident: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _reopening = false);
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
                _buildInvestigationTab(),
                _buildCapasTab(),
                _buildRecurrenceTab(),
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
    // Executive is read-only: hide all action buttons.
    final isReadOnly = role == Role.executive;
    // Safety Manager (and Admin) can close/reopen incidents.
    final isSafetyManager =
        role != null &&
        (role == Role.safetyManager || role == Role.admin) &&
        role != Role.executive;
    // Safety Coordinator and above (not PM, not DivMgr, not Executive) can
    // run OSHA determination and start investigations.
    final isSafetyOps =
        role != null &&
        (role == Role.safetyCoordinator ||
            role == Role.safetyManager ||
            role == Role.admin);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(status: incident.status),
                const Spacer(),
                // Action buttons based on role + status (hidden for Executive)
                if (!isReadOnly)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Edit: reporter can edit if draft or Reported
                      if (isReporter &&
                          (incident.status == 'Draft' ||
                              incident.status == 'Reported'))
                        Semantics(
                          label: 'Edit incident',
                          button: true,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                context.go('/incidents/${incident.id}/edit'),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit'),
                          ),
                        ),

                      // Start Investigation: Safety Manager + Reported or Reopened status
                      // Reopened incidents can have a new investigation assigned.
                      if (isSafetyManager &&
                          (incident.status == 'Reported' ||
                              incident.status == 'Reopened') &&
                          _linkedInvestigation == null)
                        Semantics(
                          label: 'Start investigation for this incident',
                          button: true,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go(
                              '/investigations/new?incidentId=${incident.id}',
                            ),
                            icon: const Icon(Icons.search, size: 16),
                            label: const Text('Start Investigation'),
                          ),
                        ),

                      // Run OSHA Determination: Safety ops roles only, not yet determined
                      if (isSafetyOps && incident.isOshaRecordable == null)
                        Semantics(
                          label: 'Run OSHA recordability determination',
                          button: true,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                context.go('/incidents/${incident.id}/osha'),
                            icon: const Icon(Icons.checklist, size: 16),
                            label: const Text('OSHA Determination'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HerzogColors.gold,
                              foregroundColor: HerzogColors.richBlack,
                            ),
                          ),
                        ),

                      // Close Incident: Safety Manager, status is CAPA In Progress
                      // Backend validates all CAPAs are Verified Effective.
                      if (isSafetyManager &&
                          incident.status == 'CAPA In Progress')
                        Semantics(
                          label: 'Close this incident',
                          button: true,
                          child: ElevatedButton.icon(
                            onPressed: _closing ? null : _closeIncident,
                            icon: _closing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock, size: 16),
                            label: const Text('Close Incident'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HerzogColors.successGreen,
                              foregroundColor: HerzogColors.white,
                            ),
                          ),
                        ),

                      // Reopen: Safety Manager, status is Closed
                      if (isSafetyManager && incident.status == 'Closed')
                        Semantics(
                          label: 'Reopen this incident',
                          button: true,
                          child: ElevatedButton.icon(
                            onPressed: _reopening ? null : _reopenIncident,
                            icon: _reopening
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_open, size: 16),
                            label: const Text('Reopen'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HerzogColors.warningAmber,
                              foregroundColor: HerzogColors.white,
                            ),
                          ),
                        ),
                    ],
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
            if (_auth.isAtLeast(Role.safetyCoordinator) &&
                _auth.currentRole != Role.executive)
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

  Widget _buildInvestigationTab() {
    final role = _auth.currentRole;
    final isSafetyManager =
        role != null && (role == Role.safetyManager || role == Role.admin);

    if (_linkedInvestigation != null) {
      final inv = _linkedInvestigation!;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('LINKED INVESTIGATION'),
              _detailRow('Investigation ID', '#${inv.id}'),
              _detailRow('Status', inv.status),
              _detailRow('Lead Investigator', inv.leadInvestigatorId),
              if (inv.targetCompletionDate != null)
                _detailRow(
                  'Target Completion',
                  DateFormat('MM/dd/yyyy').format(inv.targetCompletionDate!),
                ),
              if (inv.isOverdue)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: inv.overdueEscalationLevel >= 2
                        ? HerzogColors.errorLight
                        : HerzogColors.warningLight,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'Investigation is OVERDUE (Escalation Level ${inv.overdueEscalationLevel})',
                    style: HerzogText.body(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: inv.overdueEscalationLevel >= 2
                          ? HerzogColors.errorRed
                          : HerzogColors.warningAmber,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.go('/investigations/${inv.id}'),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('View Full Investigation'),
              ),
            ],
          ),
        ),
      );
    }

    // No investigation exists yet
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: HerzogColors.smoke.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No investigation linked yet',
            style: HerzogText.heading(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'A Safety Manager can start an investigation for this incident.',
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
          if (isSafetyManager &&
              _auth.currentRole != Role.executive &&
              (_incident?.status == 'Reported' ||
                  _incident?.status == 'Reopened')) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.go(
                '/investigations/new?incidentId=${widget.incidentId}',
              ),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Start Investigation'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCapasTab() {
    final role = _auth.currentRole;
    final canCreateCapa =
        role != null &&
        (role == Role.safetyCoordinator ||
            role == Role.safetyManager ||
            role == Role.admin);

    if (_capasLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _sectionTitle('CORRECTIVE ACTIONS (CAPAs)')),
                // Create CAPA only available when there is a linked
                // approved investigation.
                if (canCreateCapa &&
                    _linkedInvestigation != null &&
                    _linkedInvestigation!.status == 'Approved')
                  Semantics(
                    label: 'Create a new CAPA for this incident',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go(
                        '/capas/new?investigationId=${_linkedInvestigation!.id}',
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create CAPA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HerzogColors.navyBlue,
                        foregroundColor: HerzogColors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_capas.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.assignment_turned_in_outlined,
                        size: 48,
                        color: HerzogColors.smoke.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No CAPAs yet',
                        style: HerzogText.heading(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CAPAs are created after an investigation is approved.',
                        style: HerzogText.body(color: HerzogColors.midGray),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _capas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildCapaCard(_capas[index]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapaCard(CAPA capa) {
    final Color statusColor;
    switch (capa.status) {
      case 'Verified Effective':
        statusColor = HerzogColors.successGreen;
      case 'Verified Ineffective':
        statusColor = HerzogColors.errorRed;
      case 'Verification Pending':
        statusColor = HerzogColors.warningAmber;
      case 'Completed':
        statusColor = HerzogColors.infoTeal;
      default:
        statusColor = HerzogColors.midGray;
    }

    return Semantics(
      label: 'CAPA ${capa.id}: ${capa.type}, ${capa.status}',
      button: true,
      child: Card(
        child: InkWell(
          onTap: () => context.go('/capas/${capa.id}'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        capa.status.toUpperCase(),
                        style: HerzogText.label(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Priority chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _priorityColor(
                          capa.priority,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        capa.priority.toUpperCase(),
                        style: HerzogText.label(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _priorityColor(capa.priority),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (capa.isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: HerzogColors.errorLight,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'OVERDUE',
                          style: HerzogText.label(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: HerzogColors.errorRed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${capa.type} — ${capa.category}',
                  style: HerzogText.body(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HerzogColors.richBlack,
                  ),
                ),
                if (capa.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    capa.description,
                    style: HerzogText.body(
                      fontSize: 12,
                      color: HerzogColors.midGray,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (capa.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Due: ${DateFormat('MM/dd/yyyy').format(capa.dueDate!)}',
                    style: HerzogText.body(
                      fontSize: 11,
                      color: capa.isOverdue
                          ? HerzogColors.errorRed
                          : HerzogColors.smoke,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View CAPA #${capa.id}',
                      style: HerzogText.body(
                        fontSize: 11,
                        color: HerzogColors.navyBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: HerzogColors.navyBlue,
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

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return HerzogColors.errorRed;
      case 'High':
        return HerzogColors.warningAmber;
      case 'Medium':
        return HerzogColors.infoTeal;
      default:
        return HerzogColors.midGray;
    }
  }

  Widget _buildRecurrenceTab() {
    // Safety Coordinator+ can link incidents, but Executive is read-only.
    final isSafetyCoordinator =
        _auth.isAtLeast(Role.safetyCoordinator) &&
        _auth.currentRole != Role.executive;

    if (_linksLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Suggested Matches section (Safety Coordinator+ only) --
            if (isSafetyCoordinator) ...[
              _buildSuggestedMatchesSection(),
              const Divider(height: 32),
            ],

            Row(
              children: [
                Expanded(child: _sectionTitle('LINKED INCIDENTS')),
                if (isSafetyCoordinator)
                  ElevatedButton.icon(
                    onPressed: () => _showLinkDialog(),
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Link Incident'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HerzogColors.navyBlue,
                      foregroundColor: HerzogColors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // View clusters button
            OutlinedButton.icon(
              onPressed: () => context.go('/incidents/clusters'),
              icon: const Icon(Icons.account_tree_outlined, size: 16),
              label: const Text('View All Clusters'),
            ),
            const SizedBox(height: 16),

            if (_links.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link_off,
                        size: 48,
                        color: HerzogColors.smoke.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No linked incidents',
                        style: HerzogText.heading(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSafetyCoordinator
                            ? 'Use "Link Incident" to connect related incidents.'
                            : 'A Safety Coordinator can link related incidents.',
                        style: HerzogText.body(color: HerzogColors.midGray),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _links.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final link = _links[index];
                  return _buildLinkCard(link, isSafetyCoordinator);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Builds the "Suggested Matches" section with check button and cards.
  Widget _buildSuggestedMatchesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('SUGGESTED MATCHES')),
            ElevatedButton.icon(
              onPressed: _suggestionsLoading ? null : _checkRecurrence,
              icon: _suggestionsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HerzogColors.white,
                      ),
                    )
                  : const Icon(Icons.search, size: 16),
              label: Text(
                _suggestionsLoading
                    ? 'Checking...'
                    : 'Check for Similar Incidents',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: HerzogColors.infoTeal,
                foregroundColor: HerzogColors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_suggestionsError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _suggestionsError!,
              style: HerzogText.body(color: HerzogColors.errorRed),
            ),
          ),

        if (!_suggestionsChecked && !_suggestionsLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.manage_search,
                    size: 48,
                    color: HerzogColors.smoke.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Click "Check for Similar Incidents" to scan for potential recurrences.',
                    style: HerzogText.body(color: HerzogColors.midGray),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (_suggestionsChecked && _suggestions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: HerzogColors.successGreen.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No similar incidents found',
                    style: HerzogText.heading(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No potential recurrences were detected in the lookback period.',
                    style: HerzogText.body(color: HerzogColors.midGray),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (_suggestions.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildSuggestionCard(_suggestions[index]);
            },
          ),
      ],
    );
  }

  /// Builds a single suggestion card with match info, confirm, and dismiss.
  Widget _buildSuggestionCard(RecurrenceMatch match) {
    final dateStr = DateFormat.yMMMd().format(match.date);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _scoreColor(match.score).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: score badge + incident ID
            Row(
              children: [
                // Score badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _scoreColor(match.score),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Score: ${match.score}/4',
                    style: HerzogText.label(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: HerzogColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${match.incidentId}',
                  style: HerzogText.heading(
                    fontSize: 16,
                    color: HerzogColors.navyBlue,
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: HerzogText.body(
                    fontSize: 12,
                    color: HerzogColors.midGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Match criteria badges
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: match.matchCriteria.map((criterion) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HerzogColors.navyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HerzogColors.navyBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    criterion,
                    style: HerzogText.label(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: HerzogColors.navyBlue,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),

            // Details
            _detailRow('Type', match.type),
            _detailRow('Location', match.location),
            if (match.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  match.description,
                  style: HerzogText.body(
                    fontSize: 12,
                    color: HerzogColors.darkGray,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Semantics(
                  label: 'Dismiss suggestion for incident ${match.incidentId}',
                  child: OutlinedButton.icon(
                    onPressed: () => _dismissSuggestion(match),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Dismiss'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HerzogColors.midGray,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Confirm link to incident ${match.incidentId}',
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmSuggestion(match),
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HerzogColors.successGreen,
                      foregroundColor: HerzogColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a color for the recurrence score indicator.
  Color _scoreColor(int score) {
    if (score >= 4) return HerzogColors.errorRed;
    if (score >= 3) return HerzogColors.warningAmber;
    if (score >= 2) return HerzogColors.infoTeal;
    return HerzogColors.midGray;
  }

  Widget _buildLinkCard(IncidentLink link, bool canDelete) {
    final other = link.linkedIncident;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Similarity type chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HerzogColors.navyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HerzogColors.navyBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    link.similarityType,
                    style: HerzogText.label(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HerzogColors.navyBlue,
                    ),
                  ),
                ),
                const Spacer(),
                // Navigate to linked incident
                TextButton.icon(
                  onPressed: () => context.go('/incidents/${other.id}'),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(
                    '#${other.id}',
                    style: HerzogText.body(
                      fontSize: 13,
                      color: HerzogColors.navyBlue,
                    ),
                  ),
                ),
                // Delete button (Safety Coordinator+ only)
                if (canDelete)
                  Semantics(
                    label: 'Remove link to incident ${other.id}',
                    child: IconButton(
                      icon: const Icon(
                        Icons.link_off,
                        size: 18,
                        color: HerzogColors.errorRed,
                      ),
                      tooltip: 'Remove link',
                      onPressed: () => _confirmDeleteLink(link),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _detailRow('Type', other.type),
            _detailRow('Location', other.location),
            _detailRow('Division', other.division),
            _detailRow('Status', other.status),
            _detailRow('Severity', other.severity),
            if (link.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              _detailRow('Notes', link.notes),
            ],
          ],
        ),
      ),
    );
  }

  void _showLinkDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => LinkIncidentDialog(
        sourceIncidentId: widget.incidentId,
        onLinked: _loadLinks,
      ),
    );
  }

  Future<void> _confirmDeleteLink(IncidentLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Link'),
        content: Text(
          'Remove the link to incident #${link.linkedIncident.id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: HerzogColors.errorRed,
              foregroundColor: HerzogColors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _linkRepo.deleteLink(link.id);
        _loadLinks();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to remove link: $e')));
        }
      }
    }
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
