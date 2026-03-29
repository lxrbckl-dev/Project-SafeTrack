import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/api_config.dart';
import '../../../shared/widgets/voice_input_button.dart';
import '../../auth/data/auth_service.dart';
import '../../chat/data/form_fill_service.dart';
import '../../incidents/data/incident_repository.dart';
import '../data/investigation_repository.dart';

/// Lightweight user model for dropdown display.
class _UserOption {
  final int id;
  final String displayName;
  final String role;
  final String division;

  const _UserOption({
    required this.id,
    required this.displayName,
    required this.role,
    required this.division,
  });

  factory _UserOption.fromJson(Map<String, dynamic> json) {
    return _UserOption(
      id: json['id'] as int? ?? 0,
      displayName: json['displayName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      division: json['division'] as String? ?? '',
    );
  }

  /// Human-readable label for dropdown display.
  String get label {
    final rolePretty = _prettyRole(role);
    return '$displayName — $rolePretty';
  }

  static String _prettyRole(String role) {
    switch (role) {
      case 'safety_coordinator':
        return 'Safety Coordinator';
      case 'safety_manager':
        return 'Safety Manager';
      case 'admin':
        return 'Admin';
      case 'field_reporter':
        return 'Field Reporter';
      default:
        return role;
    }
  }
}

/// Form page for Safety Manager to create a new investigation from an incident.
///
/// Features:
/// - Searchable incident dropdown (fetched from GET /api/incidents)
/// - Lead investigator dropdown (fetched from GET /api/users, filtered to
///   Safety Coordinator, Safety Manager, Admin roles)
/// - Team members free-text field
/// - Target completion date auto-set by severity (shown, read-only)
/// - Route: /investigations/new?incidentId={id}
/// - Query-parameter pre-fill (TASK-044): `leadInvestigator`
class InvestigationFormPage extends StatefulWidget {
  /// Optional incident ID passed as a query parameter.
  final int? incidentId;

  /// Optional lead investigator pre-fill from URL query parameter.
  ///
  /// Non-empty values are applied directly to the lead investigator text
  /// field. Empty strings are treated as missing (not applied).
  final String? leadInvestigator;

  const InvestigationFormPage({
    super.key,
    this.incidentId,
    this.leadInvestigator,
  });

  @override
  State<InvestigationFormPage> createState() => _InvestigationFormPageState();
}

class _InvestigationFormPageState extends State<InvestigationFormPage> {
  late final InvestigationRepository _invRepo;
  late final IncidentRepository _incRepo;
  late final AuthService _auth;
  late final ApiClient _apiClient;

  final _teamCtrl = TextEditingController();

  // Incident dropdown state
  List<Incident> _incidents = [];
  bool _loadingIncidents = false;
  int? _selectedIncidentId;
  Incident? _selectedIncident;

  // Lead investigator dropdown state
  List<_UserOption> _investigators = [];
  bool _loadingUsers = false;
  String? _selectedLeadId;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _invRepo = InvestigationRepository(_auth);
    _incRepo = IncidentRepository(_auth);
    _apiClient = ApiClient(_auth);

    _selectedIncidentId = widget.incidentId;

    // Fetch dropdown data
    _fetchIncidents();
    _fetchUsers();

    // TASK-044: Apply URL query-parameter pre-fill before FormFillService
    // so query params take precedence (edge case #5).
    _applyQueryParams();
    // TASK-019: Check for AI-dispatched form fill data and listen for future
    // dispatches (handles the case where the form is already mounted).
    final formFillService = context.read<FormFillService>();
    formFillService.addListener(_applyPendingFields);
    _applyPendingFields();
  }

  /// Applies URL query-parameter pre-fill values.
  ///
  /// Only sets fields when the value is non-empty (edge case #7).
  /// Clears any pending FormFillService data when params are present so
  /// query params take precedence (edge case #5).
  void _applyQueryParams() {
    final leadVal = widget.leadInvestigator;
    if (leadVal == null || leadVal.isEmpty) return;

    // Query param present — clear pending FormFillService data.
    context.read<FormFillService>().clear();

    // Try to use as a pre-selected lead investigator ID
    _selectedLeadId = leadVal;
  }

  /// Applies any pending form fill data from [FormFillService] (AI agent
  /// dispatch). Called on init and reactively whenever the service notifies.
  void _applyPendingFields() {
    final formFillService = context.read<FormFillService>();
    final fields = formFillService.consumePendingFields();
    if (fields == null || fields.isEmpty) return;

    setState(() {
      for (final entry in fields.entries) {
        switch (entry.key) {
          case 'leadInvestigator':
            _selectedLeadId = entry.value;
          case 'teamMembers':
            _teamCtrl.text = entry.value;
          // Silently skip unknown fields per spec.
        }
      }
    });
  }

  @override
  void dispose() {
    final formFillService = context.read<FormFillService>();
    formFillService.removeListener(_applyPendingFields);
    formFillService.clear();
    _teamCtrl.dispose();
    super.dispose();
  }

  /// Fetch all incidents for the searchable dropdown.
  Future<void> _fetchIncidents() async {
    setState(() => _loadingIncidents = true);
    try {
      final response = await _incRepo.listIncidents(perPage: 200);
      if (mounted) {
        setState(() {
          _incidents = response.data;
          _loadingIncidents = false;
          // If we have a pre-selected incident ID, load its details
          if (_selectedIncidentId != null) {
            _selectedIncident = _incidents
                .where((i) => i.id == _selectedIncidentId)
                .firstOrNull;
            // If not in the list, fetch individually
            if (_selectedIncident == null) {
              _loadIncidentById(_selectedIncidentId!);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingIncidents = false;
          _error = 'Failed to load incidents: $e';
        });
      }
    }
  }

  /// Fetch a single incident by ID (fallback when not in the list).
  Future<void> _loadIncidentById(int id) async {
    try {
      final incident = await _incRepo.getIncident(id);
      if (mounted) {
        setState(() {
          _selectedIncident = incident;
          // Add to list if not already there
          if (!_incidents.any((i) => i.id == id)) {
            _incidents = [incident, ..._incidents];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load incident #$id: $e';
        });
      }
    }
  }

  /// Fetch users for the lead investigator dropdown.
  Future<void> _fetchUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/users');
      final response = await _apiClient.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load users: ${response.body}');
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final allUsers = data
          .map((e) => _UserOption.fromJson(e as Map<String, dynamic>))
          .toList();

      // Filter to only investigator-eligible roles
      final eligible = allUsers.where((u) =>
          u.role == 'safety_coordinator' ||
          u.role == 'safety_manager' ||
          u.role == 'admin').toList();

      if (mounted) {
        setState(() {
          _investigators = eligible;
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingUsers = false;
          // Non-fatal: user can still type manually if dropdown fails
        });
      }
    }
  }

  String _targetDateLabel() {
    if (_selectedIncident == null) return 'Select an incident first';
    final severity = _selectedIncident!.severity;
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
    if (_selectedIncidentId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incident is required')));
      return;
    }
    if (_selectedLeadId == null || _selectedLeadId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead investigator is required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final investigation = await _invRepo.createInvestigation(
        incidentId: _selectedIncidentId!,
        leadInvestigatorId: _selectedLeadId!.trim(),
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

  /// Builds the incident label for a dropdown option.
  String _incidentLabel(Incident inc) {
    final id = '#${inc.id}';
    final type = inc.type.isNotEmpty ? inc.type : 'Unknown';
    var location = inc.location;
    if (location.length > 30) {
      location = '${location.substring(0, 27)}...';
    }
    return '$id — $type — $location';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  style: HerzogText.heading(
                    fontSize: 20,
                    color: isDark ? Colors.white : HerzogColors.richBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assign a lead investigator and team to investigate this '
                  'incident.',
                  style: HerzogText.body(
                    fontSize: 13,
                    color: isDark ? Colors.white : HerzogColors.midGray,
                  ),
                ),
                const SizedBox(height: 24),

                // Incident info card (shown when an incident is selected)
                if (_selectedIncident != null) ...[
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
                              color: isDark
                                  ? HerzogColors.gold
                                  : HerzogColors.navyBlue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _infoRow('Incident ID', '#${_selectedIncident!.id}'),
                          _infoRow('Type', _selectedIncident!.type),
                          _infoRow('Severity', _selectedIncident!.severity),
                          _infoRow('Location', _selectedIncident!.location),
                          _infoRow('Status', _selectedIncident!.status),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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

                // Incident searchable dropdown
                Semantics(
                  label: 'Select incident',
                  child: _buildIncidentAutocomplete(isDark),
                ),
                const SizedBox(height: 16),

                // Lead investigator dropdown
                Semantics(
                  label: 'Lead investigator',
                  child: _buildLeadInvestigatorDropdown(isDark),
                ),
                const SizedBox(height: 16),

                // Team members (free-text)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Semantics(
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
                    ),
                    VoiceInputButton(controller: _teamCtrl),
                  ],
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
                                  color: isDark
                                      ? Colors.white
                                      : HerzogColors.midGray,
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
                    color: isDark ? Colors.white : HerzogColors.smoke,
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

  /// Builds a searchable incident dropdown using [Autocomplete].
  Widget _buildIncidentAutocomplete(bool isDark) {
    if (_loadingIncidents) {
      return const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Incident *',
          hintText: 'Loading incidents...',
        ),
      );
    }

    return Autocomplete<Incident>(
      displayStringForOption: _incidentLabel,
      initialValue: _selectedIncident != null
          ? TextEditingValue(text: _incidentLabel(_selectedIncident!))
          : null,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _incidents;
        }
        final query = textEditingValue.text.toLowerCase();
        return _incidents.where((inc) {
          final label = _incidentLabel(inc).toLowerCase();
          return label.contains(query);
        });
      },
      onSelected: (Incident incident) {
        setState(() {
          _selectedIncidentId = incident.id;
          _selectedIncident = incident;
        });
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: isDark
                ? HerzogDarkColors.surfaceVariant
                : HerzogColors.white,
            borderRadius: BorderRadius.circular(5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 250,
                maxWidth: 568,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final incident = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      _incidentLabel(incident),
                      style: TextStyle(
                        color: isDark ? Colors.white : HerzogColors.richBlack,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => onSelected(incident),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Incident *',
            hintText: 'Search by ID, type, or location...',
            prefixIcon: Icon(Icons.search, size: 20),
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
    );
  }

  /// Builds the lead investigator dropdown filtered to eligible roles.
  Widget _buildLeadInvestigatorDropdown(bool isDark) {
    if (_loadingUsers) {
      return const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Lead Investigator *',
          hintText: 'Loading users...',
        ),
      );
    }

    if (_investigators.isEmpty) {
      // Fallback: if users endpoint failed or returned nothing, show text field
      return TextField(
        decoration: const InputDecoration(
          labelText: 'Lead Investigator *',
          hintText: 'Enter investigator ID...',
        ),
        onChanged: (value) {
          _selectedLeadId = value;
        },
      );
    }

    // Use Autocomplete for lead investigator to avoid deprecated
    // DropdownButtonFormField.value and provide search/filter support.
    final preselected = _investigators
        .where((u) => u.id.toString() == _selectedLeadId)
        .firstOrNull;

    return Autocomplete<_UserOption>(
      displayStringForOption: (u) => u.label,
      initialValue: preselected != null
          ? TextEditingValue(text: preselected.label)
          : null,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _investigators;
        }
        final query = textEditingValue.text.toLowerCase();
        return _investigators.where((u) {
          return u.label.toLowerCase().contains(query);
        });
      },
      onSelected: (_UserOption user) {
        setState(() {
          _selectedLeadId = user.id.toString();
        });
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: isDark
                ? HerzogDarkColors.surfaceVariant
                : HerzogColors.white,
            borderRadius: BorderRadius.circular(5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 250,
                maxWidth: 568,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final user = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      user.label,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : HerzogColors.richBlack,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => onSelected(user),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Lead Investigator *',
            hintText: 'Search by name or role...',
            prefixIcon: Icon(Icons.person_search, size: 20),
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: HerzogText.body(
                fontSize: 13,
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
