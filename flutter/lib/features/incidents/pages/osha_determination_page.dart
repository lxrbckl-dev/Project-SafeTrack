import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../shared/widgets/app_loading_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../auth/data/auth_service.dart';
import '../data/incident_repository.dart';
import '../widgets/status_badge.dart';

/// OSHA recordability determination wizard following 29 CFR 1904.
///
/// Step-by-step decision tree:
/// 1. Was the injury/illness work-related?
/// 2. Did it result in death?
/// 3. Did it result in days away from work?
/// 4. Did it result in restricted work or job transfer?
/// 5. Did it require medical treatment beyond first aid?
/// 6. Did it result in loss of consciousness?
/// 7. Did it involve a significant injury or illness diagnosed by a physician?
///
/// Logic:
/// - "No" to Q1 = Not Recordable
/// - "Yes" to any Q2-Q7 = Recordable (+ DART if Q3 or Q4)
/// - "Yes" to Q1 but "No" to all Q2-Q7 = Not Recordable
///
/// Also supports override with required justification.
class OshaDeterminationPage extends StatefulWidget {
  final int incidentId;

  const OshaDeterminationPage({super.key, required this.incidentId});

  @override
  State<OshaDeterminationPage> createState() => _OshaDeterminationPageState();
}

class _OshaDeterminationPageState extends State<OshaDeterminationPage> {
  late final IncidentRepository _repo;
  late final AuthService _auth;

  Incident? _incident;
  bool _loading = true;
  bool _submitting = false;
  bool _overrideSubmitting = false;
  String? _error;

  // Wizard state
  int _currentStep = 0;
  final Map<int, bool> _answers = {};
  bool _determinationComplete = false;
  bool? _isRecordable;
  bool? _isDart;

  // Override state
  bool _showOverride = false;
  bool _overrideRecordable = false;
  final _justificationController = TextEditingController();

  static const _questions = [
    'Was the injury or illness work-related?',
    'Did it result in death?',
    'Did it result in days away from work?',
    'Did it result in restricted work or job transfer?',
    'Did it require medical treatment beyond first aid?',
    'Did it result in loss of consciousness?',
    'Did it involve a significant injury or illness diagnosed by a physician?',
  ];

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _repo = IncidentRepository(_auth);
    _loadIncident();
  }

  @override
  void dispose() {
    _justificationController.dispose();
    super.dispose();
  }

  Future<void> _loadIncident() async {
    setState(() => _loading = true);
    try {
      final incident = await _repo.getIncident(widget.incidentId);
      if (mounted) {
        setState(() {
          _incident = incident;
          _loading = false;
          // If already determined, show the result
          if (incident.isOshaRecordable != null) {
            _determinationComplete = true;
            _isRecordable = incident.isOshaRecordable;
            _isDart = incident.isDart;
          }
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

  void _answerQuestion(bool answer) {
    setState(() {
      _answers[_currentStep] = answer;

      // Special logic for Q1 (work-related)
      if (_currentStep == 0 && !answer) {
        // Not work-related = Not Recordable immediately
        _determinationComplete = true;
        _isRecordable = false;
        _isDart = false;
        return;
      }

      // If we've answered all questions, compute result
      if (_currentStep >= _questions.length - 1) {
        _computeResult();
        return;
      }

      _currentStep++;
    });
  }

  void _computeResult() {
    final workRelated = _answers[0] ?? false;
    if (!workRelated) {
      _isRecordable = false;
      _isDart = false;
    } else {
      final death = _answers[1] ?? false;
      final daysAway = _answers[2] ?? false;
      final restricted = _answers[3] ?? false;
      final medical = _answers[4] ?? false;
      final consciousness = _answers[5] ?? false;
      final significant = _answers[6] ?? false;

      _isRecordable =
          death ||
          daysAway ||
          restricted ||
          medical ||
          consciousness ||
          significant;
      _isDart = daysAway || restricted;
    }
    _determinationComplete = true;
  }

  Future<void> _submitDetermination() async {
    setState(() => _submitting = true);
    try {
      final request = OshaDecisionRequest(
        workRelated: _answers[0] ?? false,
        death: _answers[1] ?? false,
        daysAway: _answers[2] ?? false,
        restrictedTransfer: _answers[3] ?? false,
        medicalTreatment: _answers[4] ?? false,
        lossOfConsciousness: _answers[5] ?? false,
        significantDiagnosis: _answers[6] ?? false,
      );
      final updated = await _repo.oshaDecision(widget.incidentId, request);
      if (mounted) {
        setState(() {
          _incident = updated;
          _isRecordable = updated.isOshaRecordable;
          _isDart = updated.isDart;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OSHA determination submitted successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit determination: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitOverride() async {
    if (_justificationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Justification is required for OSHA override'),
        ),
      );
      return;
    }

    setState(() => _overrideSubmitting = true);
    try {
      final updated = await _repo.oshaOverride(
        widget.incidentId,
        _overrideRecordable,
        _justificationController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _incident = updated;
          _isRecordable = updated.isOshaRecordable;
          _showOverride = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OSHA override applied successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to apply override: $e')));
      }
    } finally {
      if (mounted) setState(() => _overrideSubmitting = false);
    }
  }

  void _resetWizard() {
    setState(() {
      _currentStep = 0;
      _answers.clear();
      _determinationComplete = false;
      _isRecordable = null;
      _isDart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OSHA DETERMINATION'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/incidents/${widget.incidentId}'),
          tooltip: 'Back to incident',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Current status
                    if (_incident != null) _buildCurrentStatus(),
                    const SizedBox(height: 24),

                    // Wizard or result
                    if (_determinationComplete)
                      _buildResult()
                    else
                      _buildWizardStep(),

                    const SizedBox(height: 24),

                    // Override section
                    if (_incident?.isOshaRecordable != null) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildOverrideSection(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildError() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            style: HerzogText.heading(
              fontSize: 18,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: HerzogText.body(
              color: isDark ? Colors.white : HerzogColors.midGray,
            ),
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

  Widget _buildCurrentStatus() {
    final incident = _incident!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StatusBadge(status: incident.status),
            const SizedBox(width: 12),
            Expanded(
              child: Builder(builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  '${incident.type} - ${incident.location}',
                  style: HerzogText.body(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : HerzogColors.richBlack,
                  ),
                  overflow: TextOverflow.ellipsis,
                );
              }),
            ),
            if (incident.isOshaRecordable != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: incident.isOshaRecordable!
                      ? HerzogColors.errorLight
                      : HerzogColors.successLight,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  incident.isOshaRecordable! ? 'RECORDABLE' : 'NOT RECORDABLE',
                  style: HerzogText.label(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: incident.isOshaRecordable!
                        ? HerzogColors.errorRed
                        : HerzogColors.successGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardStep() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = _questions[_currentStep];
    final progress = (_currentStep + 1) / _questions.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress
            Row(
              children: [
                Text(
                  'Question ${_currentStep + 1} of ${_questions.length}',
                  style: HerzogText.label(
                    fontSize: 12,
                    color: isDark ? Colors.white : HerzogColors.midGray,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: HerzogText.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? HerzogColors.gold : HerzogColors.navyBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: HerzogColors.borderGray,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  HerzogColors.navyBlue,
                ),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 24),

            // Question
            Text(
              question,
              style: HerzogText.heading(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),

            const SizedBox(height: 24),

            // Answer buttons
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Answer yes to: $question',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () => _answerQuestion(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HerzogColors.successGreen,
                        foregroundColor: HerzogColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'YES',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Semantics(
                    label: 'Answer no to: $question',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () => _answerQuestion(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HerzogColors.errorRed,
                        foregroundColor: HerzogColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'NO',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Back button (if not on first question)
            if (_currentStep > 0) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _currentStep--),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Previous question'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final recordable = _isRecordable ?? false;
    final dart = _isDart ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              recordable ? Icons.warning_amber : Icons.check_circle,
              size: 64,
              color: recordable
                  ? HerzogColors.warningAmber
                  : HerzogColors.successGreen,
            ),
            const SizedBox(height: 16),
            Text(
              recordable ? 'OSHA RECORDABLE' : 'NOT RECORDABLE',
              style: HerzogText.heading(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: recordable
                    ? HerzogColors.warningAmber
                    : HerzogColors.successGreen,
              ),
            ),
            if (dart) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: HerzogColors.errorLight,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'DART CASE',
                  style: HerzogText.label(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: HerzogColors.errorRed,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Summary of answers
            _buildAnswerSummary(),

            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_incident?.isOshaRecordable == null) ...[
                  AppLoadingButton(
                    label: 'Submit Determination',
                    isLoading: _submitting,
                    icon: Icons.check,
                    onPressed: _submitting ? null : _submitDetermination,
                  ),
                  const SizedBox(width: 12),
                ],
                AppLoadingButton.secondary(
                  label: 'Restart Wizard',
                  isLoading: false,
                  icon: Icons.refresh,
                  onPressed: _resetWizard,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSummary() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _answers.entries.map((entry) {
        final idx = entry.key;
        final answer = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                answer ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: answer
                    ? HerzogColors.successGreen
                    : HerzogColors.errorRed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _questions[idx],
                  style: HerzogText.body(
                    fontSize: 13,
                    color: isDark ? Colors.white : HerzogColors.darkGray,
                  ),
                ),
              ),
              Text(
                answer ? 'Yes' : 'No',
                style: HerzogText.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: answer
                      ? HerzogColors.successGreen
                      : HerzogColors.errorRed,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOverrideSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Override OSHA determination',
          toggled: _showOverride,
          child: Builder(builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return CheckboxListTile(
              title: Text(
                'Override Determination',
                style: HerzogText.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : HerzogColors.darkGray,
                ),
              ),
              value: _showOverride,
              onChanged: (v) => setState(() => _showOverride = v ?? false),
              activeColor: HerzogColors.navyBlue,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        ),
        if (_showOverride) ...[
          const SizedBox(height: 12),
          Semantics(
            label: 'Set override to recordable',
            toggled: _overrideRecordable,
            child: SwitchListTile(
              title: Text(
                'Mark as Recordable',
                style: HerzogText.body(fontSize: 14),
              ),
              value: _overrideRecordable,
              onChanged: (v) => setState(() => _overrideRecordable = v),
              activeThumbColor: HerzogColors.navyBlue,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Justification',
            controller: _justificationController,
            hint: 'Provide justification for the override (required)',
            maxLines: 3,
            required: true,
          ),
          const SizedBox(height: 16),
          AppLoadingButton(
            label: 'Submit Override',
            isLoading: _overrideSubmitting,
            icon: Icons.gavel,
            onPressed: _overrideSubmitting ? null : _submitOverride,
          ),
        ],
      ],
    );
  }
}
