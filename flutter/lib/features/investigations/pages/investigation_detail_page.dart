import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../data/investigation_repository.dart';
import '../widgets/contributing_factors_panel.dart';
import '../widgets/five_why_chain.dart';
import '../widgets/investigation_review_panel.dart';
import '../widgets/witness_statement_card.dart';

/// Detail page for a single investigation with tabbed interface.
///
/// Tabs: Overview, 5-Why Analysis, Contributing Factors, Witness Statements,
/// Review.
class InvestigationDetailPage extends StatefulWidget {
  final int investigationId;

  const InvestigationDetailPage({super.key, required this.investigationId});

  @override
  State<InvestigationDetailPage> createState() =>
      _InvestigationDetailPageState();
}

class _InvestigationDetailPageState extends State<InvestigationDetailPage>
    with SingleTickerProviderStateMixin {
  late final InvestigationRepository _repo;
  late final AuthService _auth;
  late final TabController _tabController;

  Investigation? _investigation;
  List<String> _factorTypes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _repo = InvestigationRepository(_auth);
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getInvestigation(widget.investigationId),
        _repo.getFactorTypes(),
      ]);
      if (mounted) {
        setState(() {
          _investigation = results[0] as Investigation;
          _factorTypes = results[1] as List<String>;
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

  bool get _editable {
    final status = _investigation?.status ?? '';
    final role = _auth.currentRole;
    // Executive, PM, and Division Manager are view-only — cannot edit investigation details.
    // The backend would also reject their writes (403), but hiding in UI is better UX.
    if (role == Role.executive ||
        role == Role.pm ||
        role == Role.divisionManager) {
      return false;
    }
    return status != 'Approved';
  }

  bool get _isSafetyManager {
    final role = _auth.currentRole;
    // Executive is read-only — cannot act as Safety Manager.
    if (role == Role.executive) return false;
    return role != null && (role == Role.safetyManager || role == Role.admin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('INVESTIGATION DETAIL'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/investigations'),
          tooltip: 'Back to investigations',
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'OVERVIEW'),
            Tab(text: '5-WHY'),
            Tab(text: 'FACTORS'),
            Tab(text: 'WITNESSES'),
            Tab(text: 'REVIEW'),
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
                _buildOverviewTab(),
                _buildFiveWhyTab(),
                _buildFactorsTab(),
                _buildWitnessesTab(),
                _buildReviewTab(),
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
            'Failed to load investigation',
            style: HerzogText.heading(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(color: HerzogColors.midGray),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // --- Overview Tab ---
  Widget _buildOverviewTab() {
    final inv = _investigation!;
    final targetDate = inv.targetCompletionDate != null
        ? DateFormat('MM/dd/yyyy').format(inv.targetCompletionDate!)
        : 'Not set';
    final actualDate = inv.actualCompletionDate != null
        ? DateFormat('MM/dd/yyyy').format(inv.actualCompletionDate!)
        : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            _buildStatusHeader(inv),
            const SizedBox(height: 20),

            // Overdue warning
            if (inv.isOverdue) _buildOverdueWarning(inv),

            // Investigation info
            _sectionTitle('INVESTIGATION INFO'),
            _detailRow('Investigation ID', '#${inv.id}'),
            _detailRow('Incident ID', '#${inv.incidentId}'),
            _detailRow('Status', inv.status),
            _detailRow('Lead Investigator', inv.leadInvestigatorId),
            if (inv.teamMembers.isNotEmpty)
              _detailRow('Team Members', inv.teamMembers),
            _detailRow('Assigned By', inv.assignedBy),
            const SizedBox(height: 16),

            _sectionTitle('TIMELINE'),
            _detailRow('Target Completion', targetDate),
            if (actualDate.isNotEmpty)
              _detailRow('Actual Completion', actualDate),
            if (inv.createdAt != null)
              _detailRow(
                'Created',
                DateFormat('MM/dd/yyyy hh:mm a').format(inv.createdAt!),
              ),
            const SizedBox(height: 16),

            // Quick stats
            _sectionTitle('PROGRESS'),
            _buildProgressCards(inv),
            const SizedBox(height: 16),

            // Link to incident
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Semantics(
                  label: 'View linked incident',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/incidents/${inv.incidentId}'),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text('View Incident #${inv.incidentId}'),
                  ),
                ),
                // Create CAPA button — visible after investigation is approved
                if (inv.status == 'Approved' && _isSafetyManager)
                  Semantics(
                    label: 'Create CAPA from this investigation',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.go('/capas/new?investigationId=${inv.id}'),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Create CAPA'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HerzogColors.successGreen,
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

  Widget _buildStatusHeader(Investigation inv) {
    final statusColor = _statusColor(inv.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Semantics(
              label: 'Status: ${inv.status}',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  inv.status.toUpperCase(),
                  style: HerzogText.label(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            if (inv.isOverdue) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: HerzogColors.errorLight,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'OVERDUE',
                  style: HerzogText.label(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: HerzogColors.errorRed,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueWarning(Investigation inv) {
    final level = inv.overdueEscalationLevel;
    final Color bgColor;
    final Color fgColor;
    final String message;

    if (level >= 3) {
      bgColor = HerzogColors.errorLight;
      fgColor = HerzogColors.errorRed;
      message =
          'CRITICAL: Investigation is 14+ days overdue (Escalation Level 3)';
    } else if (level >= 2) {
      bgColor = HerzogColors.errorLight;
      fgColor = HerzogColors.errorRed;
      message = 'Investigation is 7-13 days overdue (Escalation Level 2)';
    } else {
      bgColor = HerzogColors.warningLight;
      fgColor = HerzogColors.warningAmber;
      message = 'Investigation is overdue (Escalation Level 1)';
    }

    return Semantics(
      label: message,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: fgColor),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, size: 20, color: fgColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: HerzogText.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCards(Investigation inv) {
    return Row(
      children: [
        _progressCard(
          'Why Levels',
          '${inv.fiveWhys.length}',
          inv.fiveWhys.length >= 3
              ? HerzogColors.successGreen
              : HerzogColors.warningAmber,
          'Minimum 3 required',
        ),
        const SizedBox(width: 12),
        _progressCard(
          'Factors',
          '${inv.contributingFactors.length}',
          inv.contributingFactors.any((f) => f.isPrimary)
              ? HerzogColors.successGreen
              : HerzogColors.warningAmber,
          inv.contributingFactors.any((f) => f.isPrimary)
              ? 'Primary set'
              : 'No primary set',
        ),
        const SizedBox(width: 12),
        _progressCard(
          'Witnesses',
          '${inv.witnessStatements.length}',
          HerzogColors.infoTeal,
          'Statements collected',
        ),
      ],
    );
  }

  Widget _progressCard(
    String label,
    String count,
    Color color,
    String subtitle,
  ) {
    return Expanded(
      child: Semantics(
        label: '$label: $count. $subtitle',
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  count,
                  style: HerzogText.heading(fontSize: 24, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: HerzogText.label(
                    fontSize: 11,
                    color: HerzogColors.midGray,
                  ),
                ),
                Text(
                  subtitle,
                  style: HerzogText.body(
                    fontSize: 10,
                    color: HerzogColors.smoke,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Five-Why Tab ---
  Widget _buildFiveWhyTab() {
    final inv = _investigation!;
    return FiveWhyChain(
      fiveWhys: inv.fiveWhys,
      editable: _editable,
      onSave: (fiveWhy) async {
        await _repo.addFiveWhy(inv.id!, fiveWhy);
        await _loadData();
      },
      onDelete: (whyId) async {
        await _repo.deleteFiveWhy(inv.id!, whyId);
        await _loadData();
      },
    );
  }

  // --- Contributing Factors Tab ---
  Widget _buildFactorsTab() {
    final inv = _investigation!;
    return ContributingFactorsPanel(
      factors: inv.contributingFactors,
      factorTypes: _factorTypes,
      editable: _editable,
      onAdd: (factor) async {
        await _repo.addFactor(inv.id!, factor);
        await _loadData();
      },
      onDelete: (factorId) async {
        await _repo.deleteFactor(inv.id!, factorId);
        await _loadData();
      },
    );
  }

  // --- Witnesses Tab ---
  Widget _buildWitnessesTab() {
    final inv = _investigation!;
    return WitnessStatementCards(
      witnesses: inv.witnessStatements,
      editable: _editable,
      onAdd: (statement) async {
        await _repo.addWitness(inv.id!, statement);
        await _loadData();
      },
      onUpdate: (statement) async {
        await _repo.updateWitness(inv.id!, statement.id!, statement);
        await _loadData();
      },
    );
  }

  // --- Review Tab ---
  Widget _buildReviewTab() {
    final inv = _investigation!;
    return InvestigationReviewPanel(
      investigation: inv,
      isSafetyManager: _isSafetyManager,
      onSubmitForReview: () async {
        await _repo.submitForReview(inv.id!);
        await _loadData();
      },
      onReview: ({required String decision, required String comments}) async {
        await _repo.reviewInvestigation(
          inv.id!,
          decision: decision,
          comments: comments,
        );
        await _loadData();
      },
    );
  }

  // --- Helpers ---

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

  Color _statusColor(String status) {
    switch (status) {
      case 'Assigned':
        return HerzogColors.infoTeal;
      case 'In Progress':
        return HerzogColors.warningAmber;
      case 'Under Review':
        return HerzogColors.navyBlue;
      case 'Approved':
        return HerzogColors.successGreen;
      case 'Returned':
        return HerzogColors.errorRed;
      default:
        return HerzogColors.midGray;
    }
  }
}
