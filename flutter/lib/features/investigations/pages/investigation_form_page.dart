import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../incidents/data/incident_repository.dart';
import '../data/investigation_repository.dart';

/// Form page for Safety Manager to create a new investigation from an incident.
///
/// Features:
/// - Fields: lead investigator (text), team members
/// - Target completion date auto-set by severity (shown, read-only)
/// - Route: /investigations/new?incidentId={id}
class InvestigationFormPage extends StatefulWidget {
  /// Optional incident ID passed as a query parameter.
  final int? incidentId;

  const InvestigationFormPage({super.key, this.incidentId});

  @override
  State<InvestigationFormPage> createState() => _InvestigationFormPageState();
}

class _InvestigationFormPageState extends State<InvestigationFormPage> {
  late final InvestigationRepository _invRepo;
  late final IncidentRepository _incRepo;
  late final AuthService _auth;

  final _leadCtrl = TextEditingController();
  final _teamCtrl = TextEditingController();
  int? _incidentId;
  Incident? _incident;
  bool _loadingIncident = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _invRepo = InvestigationRepository(_auth);
    _incRepo = IncidentRepository(_auth);
    _incidentId = widget.incidentId;
    if (_incidentId != null) {
      _loadIncident();
    }
  }

  @override
  void dispose() {
    _leadCtrl.dispose();
    _teamCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIncident() async {
    if (_incidentId == null) return;
    setState(() => _loadingIncident = true);
    try {
      final incident = await _incRepo.getIncident(_incidentId!);
      if (mounted) {
        setState(() {
          _incident = incident;
          _loadingIncident = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load incident: $e';
          _loadingIncident = false;
        });
      }
    }
  }

  String _targetDateLabel() {
    if (_incident == null) return 'Select an incident first';
    final severity = _incident!.severity;
    final now = DateTime.now();

    DateTime target;
    String rule;
    switch (severity) {
      case 'Fatality':
        target = now.add(const Duration(hours: 48));
        rule = '48 hours (Fatality)';
      case 'Lost Time':
        target = now.add(const Duration(days: 5));
        rule = '5 business days (Lost Time)';
      case 'Medical Treatment':
        target = now.add(const Duration(days: 10));
        rule = '10 calendar days (Medical Treatment)';
      case 'First Aid':
      case 'Near Miss':
        target = now.add(const Duration(days: 14));
        rule = '14 calendar days ($severity)';
      default:
        target = now.add(const Duration(days: 14));
        rule = '14 calendar days (default)';
    }

    return '${DateFormat('MM/dd/yyyy').format(target)} ($rule)';
  }

  Future<void> _submit() async {
    if (_incidentId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incident ID is required')));
      return;
    }
    if (_leadCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead investigator is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final investigation = await _invRepo.createInvestigation(
        incidentId: _incidentId!,
        leadInvestigatorId: _leadCtrl.text.trim(),
        teamMembers: _teamCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Investigation created successfully'),
            backgroundColor: HerzogColors.successGreen,
          ),
        );
        context.go('/investigations/${investigation.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create investigation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEW INVESTIGATION'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/investigations'),
          tooltip: 'Back to investigations',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ASSIGN INVESTIGATION',
                  style: HerzogText.heading(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assign a lead investigator and team to investigate this '
                  'incident.',
                  style: HerzogText.body(
                    fontSize: 13,
                    color: HerzogColors.midGray,
                  ),
                ),
                const SizedBox(height: 24),

                // Incident info
                if (_incident != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LINKED INCIDENT',
                            style: HerzogText.heading(
                              fontSize: 14,
                              color: HerzogColors.navyBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _infoRow('Incident ID', '#${_incident!.id}'),
                          _infoRow('Type', _incident!.type),
                          _infoRow('Severity', _incident!.severity),
                          _infoRow('Location', _incident!.location),
                          _infoRow('Status', _incident!.status),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_loadingIncident)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HerzogColors.errorLight,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _error!,
                      style: HerzogText.body(
                        fontSize: 13,
                        color: HerzogColors.errorRed,
                      ),
                    ),
                  ),

                // Incident ID input (if not pre-filled)
                if (_incidentId == null) ...[
                  Semantics(
                    label: 'Incident ID',
                    textField: true,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Incident ID',
                        hintText: 'Enter the incident ID...',
                      ),
                      keyboardType: TextInputType.number,
                      onSubmitted: (value) {
                        final id = int.tryParse(value);
                        if (id != null) {
                          setState(() => _incidentId = id);
                          _loadIncident();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Lead investigator
                Semantics(
                  label: 'Lead investigator',
                  textField: true,
                  child: TextField(
                    controller: _leadCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lead Investigator *',
                      hintText: 'Enter investigator ID or name...',
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Team members
                Semantics(
                  label: 'Team members',
                  textField: true,
                  child: TextField(
                    controller: _teamCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Team Members',
                      hintText:
                          'Enter team member IDs or names, comma separated...',
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Target completion date (read-only)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 20,
                          color: HerzogColors.navyBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TARGET COMPLETION DATE',
                                style: HerzogText.label(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: HerzogColors.midGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Semantics(
                                label:
                                    'Target completion date: ${_targetDateLabel()}',
                                child: Text(
                                  _targetDateLabel(),
                                  style: HerzogText.body(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Auto-calculated based on incident severity. Not editable.',
                  style: HerzogText.body(
                    fontSize: 11,
                    color: HerzogColors.smoke,
                  ),
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: HerzogColors.white,
                            ),
                          )
                        : const Icon(Icons.assignment, size: 16),
                    label: const Text('Assign Investigation'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: HerzogText.label(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: HerzogColors.midGray,
              ),
            ),
          ),
          Expanded(child: Text(value, style: HerzogText.body(fontSize: 13))),
        ],
      ),
    );
  }
}
