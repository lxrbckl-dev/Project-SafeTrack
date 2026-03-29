import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/services/sync_service.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_loading_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/voice_input_button.dart';
import '../../auth/data/auth_service.dart';
import '../../chat/data/form_fill_service.dart';
import '../../../core/constants/divisions.dart';
import '../data/incident_repository.dart';
import '../widgets/completion_indicator.dart';
import '../widgets/gps_location_field.dart';
import '../widgets/injured_person_form.dart';
import '../widgets/railroad_notification_section.dart';

/// Multi-section incident form for creating and editing incidents.
///
/// Supports:
/// - Create mode (no ID) and edit mode (loads existing)
/// - Save Draft (isDraft=true) and Submit (isDraft=false, status=Reported)
/// - Completion percentage indicator that updates in real-time
/// - Conditional sections: Railroad, Injured Person
/// - Photo picker with thumbnail preview
/// - Form validation for submit (type, date, location, description required)
/// - Query-parameter pre-fill (create mode only) via [queryParams]
class IncidentFormPage extends StatefulWidget {
  /// Incident ID for edit mode. Null for create mode.
  final int? incidentId;

  /// Optional query parameters from the URL for create-mode pre-fill.
  ///
  /// Supported keys: `type`, `division`, `project`, `location`, `description`,
  /// `shift`, `weather`, `severity`.
  ///
  /// Only applied when [incidentId] is null (create mode). Ignored in edit
  /// mode to prevent a race condition with [_loadExisting].
  final Map<String, String> queryParams;

  const IncidentFormPage({
    super.key,
    this.incidentId,
    this.queryParams = const {},
  });

  @override
  State<IncidentFormPage> createState() => _IncidentFormPageState();
}

class _IncidentFormPageState extends State<IncidentFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final IncidentRepository _repo;
  late final AuthService _auth;

  bool _isEditMode = false;
  bool _loading = false;
  bool _saving = false;
  bool _submitting = false;
  bool _isDirty = false;

  // Basic Info
  String? _type;
  DateTime? _date;
  final _locationController = TextEditingController();
  double _latitude = 0.0;
  double _longitude = 0.0;
  final _divisionController = TextEditingController();
  final _projectController = TextEditingController();

  // Description
  final _descriptionController = TextEditingController();
  final _immediateActionsController = TextEditingController();

  // Classification
  String? _severity;
  String? _potentialSeverity;
  String? _shift;
  String? _weather;

  // Railroad
  bool _isRailroadProperty = false;
  String? _railroadClient;
  bool _railroadNotified = false;
  final _notificationMethodController = TextEditingController();

  // Injured Person
  InjuredPerson _injuredPerson = const InjuredPerson();
  bool _hasInjuredPerson = false;

  // Photos
  final List<XFile> _selectedPhotos = [];
  final _imagePicker = ImagePicker();

  static const _incidentTypes = [
    AppDropdownOption(value: 'Injury', label: 'Injury'),
    AppDropdownOption(value: 'Near Miss', label: 'Near Miss'),
    AppDropdownOption(value: 'Property Damage', label: 'Property Damage'),
    AppDropdownOption(value: 'Environmental', label: 'Environmental'),
    AppDropdownOption(value: 'Vehicle', label: 'Vehicle'),
    AppDropdownOption(value: 'Fire', label: 'Fire'),
    AppDropdownOption(value: 'Utility Strike', label: 'Utility Strike'),
  ];

  static const _severities = [
    AppDropdownOption(value: 'Fatality', label: 'Fatality'),
    AppDropdownOption(value: 'Lost Time', label: 'Lost Time'),
    AppDropdownOption(value: 'Medical Treatment', label: 'Medical Treatment'),
    AppDropdownOption(value: 'First Aid', label: 'First Aid'),
    AppDropdownOption(value: 'Near Miss', label: 'Near Miss'),
  ];

  static const _shifts = [
    AppDropdownOption(value: 'Day', label: 'Day'),
    AppDropdownOption(value: 'Night', label: 'Night'),
    AppDropdownOption(value: 'Swing', label: 'Swing'),
  ];

  static const _weatherOptions = [
    AppDropdownOption(value: 'Clear', label: 'Clear'),
    AppDropdownOption(value: 'Cloudy', label: 'Cloudy'),
    AppDropdownOption(value: 'Rain', label: 'Rain'),
    AppDropdownOption(value: 'Snow', label: 'Snow'),
    AppDropdownOption(value: 'Ice', label: 'Ice'),
    AppDropdownOption(value: 'Fog', label: 'Fog'),
    AppDropdownOption(value: 'Wind', label: 'Wind'),
    AppDropdownOption(value: 'Extreme Heat', label: 'Extreme Heat'),
    AppDropdownOption(value: 'Extreme Cold', label: 'Extreme Cold'),
  ];

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _repo = IncidentRepository(_auth);
    _isEditMode = widget.incidentId != null;
    if (_isEditMode) {
      _loadExisting();
    } else {
      // TASK-044: Apply URL query-parameter pre-fill in create mode only.
      // Must run before _applyPendingFields so that query params take
      // precedence over any queued FormFillService data.
      _applyQueryParams();
    }
    // TASK-019: Check for AI-dispatched form fill data and listen for future
    // dispatches (handles the case where the form is already mounted).
    // In create mode with query params present, pending fields are cleared
    // inside _applyQueryParams so query params win.
    final formFillService = context.read<FormFillService>();
    formFillService.addListener(_applyPendingFields);
    _applyPendingFields();
  }

  /// Applies URL query parameters as pre-filled form values (create mode only).
  ///
  /// Edge cases handled:
  /// - Edit mode guard: method is never called when [_isEditMode] is true.
  /// - URL-encoded values: GoRouter decodes both `+` (as space) and `%20`
  ///   automatically via [Uri.queryParameters], so values arrive decoded.
  /// - Invalid enum values: silently ignored, not applied.
  /// - Empty string params (`?type=`): treated as missing, not applied.
  /// - FormFillService conflict: clears pending fields when any query param
  ///   is present so query params take precedence.
  void _applyQueryParams() {
    final params = widget.queryParams;
    if (params.isEmpty) return;

    // Query params are present — clear any pending FormFillService data so
    // query params win (TASK-044 edge case #5).
    final formFillService = context.read<FormFillService>();
    formFillService.clear();

    setState(() {
      // type — validate against known incident types (edge case #3, #6).
      final typeVal = params['type'];
      if (typeVal != null && typeVal.isNotEmpty) {
        final validTypes = _incidentTypes.map((o) => o.value).toList();
        if (validTypes.contains(typeVal)) {
          _type = typeVal;
          if (typeVal == 'Injury') _hasInjuredPerson = true;
        }
      }

      // division — direct string fill (edge case #2 handled by GoRouter).
      final divisionVal = params['division'];
      if (divisionVal != null && divisionVal.isNotEmpty) {
        _divisionController.text = divisionVal;
      }

      // project — direct string fill.
      final projectVal = params['project'];
      if (projectVal != null && projectVal.isNotEmpty) {
        _projectController.text = projectVal;
      }

      // location — direct string fill.
      final locationVal = params['location'];
      if (locationVal != null && locationVal.isNotEmpty) {
        _locationController.text = locationVal;
      }

      // description — direct string fill.
      final descVal = params['description'];
      if (descVal != null && descVal.isNotEmpty) {
        _descriptionController.text = descVal;
      }

      // severity — validate against enum values (edge case #6: High is invalid).
      final severityVal = params['severity'];
      if (severityVal != null && severityVal.isNotEmpty) {
        final validSeverities = _severities.map((o) => o.value).toList();
        if (validSeverities.contains(severityVal)) {
          _severity = severityVal;
        }
      }

      // shift — validate against enum values.
      final shiftVal = params['shift'];
      if (shiftVal != null && shiftVal.isNotEmpty) {
        final validShifts = _shifts.map((o) => o.value).toList();
        if (validShifts.contains(shiftVal)) {
          _shift = shiftVal;
        }
      }

      // weather — validate against enum values.
      final weatherVal = params['weather'];
      if (weatherVal != null && weatherVal.isNotEmpty) {
        final validWeather = _weatherOptions.map((o) => o.value).toList();
        if (validWeather.contains(weatherVal)) {
          _weather = weatherVal;
        }
      }
    });

    // Mark form dirty only if any param actually set a field.
    _markDirty();
  }

  /// Applies any pending form fill data from [FormFillService] (AI agent
  /// dispatch). Called on init and reactively whenever the service notifies.
  ///
  /// Maps field names from the AI action schema to form controllers/state.
  /// Silently skips unknown fields per spec.
  void _applyPendingFields() {
    final formFillService = context.read<FormFillService>();
    final fields = formFillService.consumePendingFields();
    if (fields == null || fields.isEmpty) return;

    _markDirty();
    setState(() {
      for (final entry in fields.entries) {
        switch (entry.key) {
          case 'type':
            // Validate the value is a known incident type.
            final validTypes = _incidentTypes.map((o) => o.value).toList();
            if (validTypes.contains(entry.value)) {
              _type = entry.value;
              if (entry.value == 'Injury') _hasInjuredPerson = true;
            }
          case 'location':
            _locationController.text = entry.value;
          case 'division':
            _divisionController.text = entry.value;
          case 'project':
            _projectController.text = entry.value;
          case 'description':
            _descriptionController.text = entry.value;
          case 'immediateActions':
            _immediateActionsController.text = entry.value;
          case 'severity':
            final validSeverities = _severities.map((o) => o.value).toList();
            if (validSeverities.contains(entry.value)) {
              _severity = entry.value;
            }
          case 'potentialSeverity':
            final validSeverities = _severities.map((o) => o.value).toList();
            if (validSeverities.contains(entry.value)) {
              _potentialSeverity = entry.value;
            }
          case 'shift':
            final validShifts = _shifts.map((o) => o.value).toList();
            if (validShifts.contains(entry.value)) {
              _shift = entry.value;
            }
          case 'weather':
            final validWeather = _weatherOptions.map((o) => o.value).toList();
            if (validWeather.contains(entry.value)) {
              _weather = entry.value;
            }
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
    _locationController.dispose();
    _divisionController.dispose();
    _projectController.dispose();
    _descriptionController.dispose();
    _immediateActionsController.dispose();
    _notificationMethodController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final incident = await _repo.getIncident(widget.incidentId!);
      if (mounted) {
        setState(() {
          _type = incident.type.isNotEmpty ? incident.type : null;
          _date = incident.date;
          _locationController.text = incident.location;
          _latitude = incident.latitude;
          _longitude = incident.longitude;
          _divisionController.text = incident.division;
          _projectController.text = incident.projectJobSite;
          _descriptionController.text = incident.description;
          _immediateActionsController.text = incident.immediateActions;
          _severity = incident.severity.isNotEmpty ? incident.severity : null;
          _potentialSeverity = incident.potentialSeverity.isNotEmpty
              ? incident.potentialSeverity
              : null;
          _shift = incident.shift.isNotEmpty ? incident.shift : null;
          _weather = incident.weather.isNotEmpty ? incident.weather : null;
          _isRailroadProperty = incident.isRailroadProperty;
          _railroadClient = incident.railroadClient.isNotEmpty
              ? incident.railroadClient
              : null;
          _railroadNotified = incident.railroadNotified;
          _notificationMethodController.text =
              incident.railroadNotificationMethod;
          if (incident.injuredPersons.isNotEmpty) {
            _hasInjuredPerson = true;
            _injuredPerson = incident.injuredPersons.first;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load incident: $e')));
      }
    }
  }

  /// Calculates completion percentage based on all user-editable fields.
  /// All fields weighted equally per rubric.
  int _calculateCompletion() {
    final fields = <bool>[
      _type != null && _type!.isNotEmpty,
      _date != null,
      _locationController.text.isNotEmpty,
      _divisionController.text.isNotEmpty,
      _projectController.text.isNotEmpty,
      _descriptionController.text.isNotEmpty,
      _immediateActionsController.text.isNotEmpty,
      _severity != null && _severity!.isNotEmpty,
      _potentialSeverity != null && _potentialSeverity!.isNotEmpty,
      _shift != null && _shift!.isNotEmpty,
      _weather != null && _weather!.isNotEmpty,
    ];
    final filled = fields.where((f) => f).length;
    return (filled * 100) ~/ fields.length;
  }

  /// Marks the form as dirty (has unsaved user changes).
  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Incident _buildIncident({required bool isDraft}) {
    return Incident(
      type: _type ?? '',
      date: _date,
      location: _locationController.text,
      latitude: _latitude,
      longitude: _longitude,
      division: _divisionController.text,
      projectJobSite: _projectController.text,
      description: _descriptionController.text,
      immediateActions: _immediateActionsController.text,
      severity: _severity ?? '',
      potentialSeverity: _potentialSeverity ?? '',
      shift: _shift ?? '',
      weather: _weather ?? '',
      isDraft: isDraft,
      isRailroadProperty: _isRailroadProperty,
      railroadClient: _railroadClient ?? '',
      railroadNotified: _railroadNotified,
      railroadNotificationMethod: _notificationMethodController.text,
      injuredPersons: _hasInjuredPerson && _injuredPerson.name.isNotEmpty
          ? [_injuredPerson]
          : [],
    );
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final syncService = context.read<SyncService>();

      // If offline, save to local Drift database
      if (!syncService.isOnline) {
        await _saveOffline(isDraft: true);
        return;
      }

      final data = _buildIncident(isDraft: true);
      Incident result;
      if (_isEditMode) {
        result = await _repo.updateIncident(widget.incidentId!, data);
      } else {
        result = await _repo.createIncident(data);
      }

      // Upload photos
      for (final photo in _selectedPhotos) {
        if (result.id != null) {
          await _repo.uploadPhoto(result.id!, photo);
        }
      }

      if (mounted) {
        setState(() => _isDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved successfully')),
        );
        context.go('/incidents');
      }
    } catch (e) {
      // If API call fails (e.g., network error), fall back to offline save
      if (mounted) {
        try {
          await _saveOffline(isDraft: true);
        } catch (offlineError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save draft: $offlineError')),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final syncService = context.read<SyncService>();

      // If offline, save to local Drift database
      if (!syncService.isOnline) {
        await _saveOffline(isDraft: false);
        return;
      }

      final data = _buildIncident(isDraft: false);
      Incident result;
      if (_isEditMode) {
        result = await _repo.updateIncident(widget.incidentId!, data);
      } else {
        result = await _repo.createIncident(data);
      }

      // Upload photos
      for (final photo in _selectedPhotos) {
        if (result.id != null) {
          await _repo.uploadPhoto(result.id!, photo);
        }
      }

      if (mounted) {
        setState(() => _isDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident submitted successfully')),
        );
        context.go('/incidents');
      }
    } catch (e) {
      // If API call fails, fall back to offline save
      if (mounted) {
        try {
          await _saveOffline(isDraft: false);
        } catch (offlineError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to submit incident: $offlineError'),
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Save the incident to the local Drift database for offline storage.
  /// Called when the device is offline or when the API call fails.
  Future<void> _saveOffline({required bool isDraft}) async {
    final syncService = context.read<SyncService>();
    final data = _buildIncident(isDraft: isDraft);

    // Collect photo file paths for deferred upload
    final photoPaths = _selectedPhotos.map((p) => p.path).toList();

    await syncService.saveIncidentOffline(
      incidentJson: data.toJson(),
      photoPaths: photoPaths,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDraft
                ? 'Draft saved offline -- will sync when connected'
                : 'Incident saved offline -- will sync when connected',
          ),
          backgroundColor: HerzogColors.warningAmber,
        ),
      );
      context.go('/incidents');
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (photo != null && mounted) {
        setState(() => _selectedPhotos.add(photo));
        _markDirty();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick photo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'EDIT INCIDENT' : 'NEW INCIDENT'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Discard changes?'),
              content: const Text(
                'You have unsaved changes. Are you sure you want to leave?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? 'EDIT INCIDENT' : 'NEW INCIDENT'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_isDirty) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Discard changes?'),
                    content: const Text(
                      'You have unsaved changes. Are you sure you want to leave?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/incidents');
                        },
                        child: const Text('Discard'),
                      ),
                    ],
                  ),
                );
              } else {
                context.go('/incidents');
              }
            },
            tooltip: 'Back to incidents',
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Completion indicator
                  CompletionIndicator(percent: _calculateCompletion()),
                  const SizedBox(height: 20),

                  // Basic Info Section
                  _sectionHeader('BASIC INFORMATION'),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    label: 'Incident Type',
                    options: _incidentTypes,
                    value: _type,
                    onChanged: (v) {
                      setState(() {
                        _type = v;
                        // Auto-show injured person section for Injury type
                        if (v == 'Injury') {
                          _hasInjuredPerson = true;
                        }
                      });
                      _markDirty();
                    },
                    required: true,
                    hint: 'Select type',
                    validator: (v) => v == null ? 'Type is required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppDatePicker(
                    label: 'Incident Date',
                    selectedDate: _date,
                    onDateSelected: (d) {
                      setState(() => _date = d);
                      _markDirty();
                    },
                    required: true,
                    validator: (d) => d == null ? 'Date is required' : null,
                  ),
                  const SizedBox(height: 12),
                  GpsLocationField(
                    label: 'Location',
                    controller: _locationController,
                    required: true,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Location is required' : null,
                    onLocationObtained: (lat, lon) {
                      setState(() {
                        _latitude = lat;
                        _longitude = lon;
                      });
                      _markDirty();
                    },
                    onChanged: (_) {
                      setState(() {});
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    label: 'Division',
                    options: kDivisions
                        .map((d) => AppDropdownOption(value: d, label: d))
                        .toList(),
                    value: _divisionController.text.isEmpty
                        ? null
                        : _divisionController.text,
                    onChanged: (v) {
                      setState(() => _divisionController.text = v ?? '');
                      _markDirty();
                    },
                    hint: 'Select division',
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Project / Job Site',
                    controller: _projectController,
                    hint: 'Enter project or job site name',
                    onChanged: (_) {
                      setState(() {});
                      _markDirty();
                    },
                  ),

                  const SizedBox(height: 24),

                  // Description Section
                  _sectionHeader('DESCRIPTION'),
                  const SizedBox(height: 12),
                  _fieldWithVoice(
                    AppTextField(
                      label: 'Description',
                      controller: _descriptionController,
                      hint: 'Describe the incident...',
                      maxLines: 4,
                      required: true,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Description is required'
                          : null,
                      onChanged: (_) {
                        setState(() {});
                        _markDirty();
                      },
                    ),
                    _descriptionController,
                  ),
                  const SizedBox(height: 12),
                  _fieldWithVoice(
                    AppTextField(
                      label: 'Immediate Actions Taken',
                      controller: _immediateActionsController,
                      hint: 'Describe any immediate actions...',
                      maxLines: 3,
                      onChanged: (_) {
                        setState(() {});
                        _markDirty();
                      },
                    ),
                    _immediateActionsController,
                  ),

                  const SizedBox(height: 24),

                  // Classification Section
                  _sectionHeader('CLASSIFICATION'),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    label: 'Severity',
                    options: _severities,
                    value: _severity,
                    onChanged: (v) {
                      setState(() => _severity = v);
                      _markDirty();
                    },
                    hint: 'Select severity',
                  ),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    label: 'Potential Severity',
                    options: _severities,
                    value: _potentialSeverity,
                    onChanged: (v) {
                      setState(() => _potentialSeverity = v);
                      _markDirty();
                    },
                    hint: 'Select potential severity',
                  ),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    label: 'Shift',
                    options: _shifts,
                    value: _shift,
                    onChanged: (v) {
                      setState(() => _shift = v);
                      _markDirty();
                    },
                    hint: 'Select shift',
                  ),
                  const SizedBox(height: 12),
                  AppDropdown<String>(
                    label: 'Weather Conditions',
                    options: _weatherOptions,
                    value: _weather,
                    onChanged: (v) {
                      setState(() => _weather = v);
                      _markDirty();
                    },
                    hint: 'Select weather',
                  ),

                  const SizedBox(height: 24),

                  // Railroad Section (conditional)
                  _sectionHeader('RAILROAD'),
                  const SizedBox(height: 12),
                  RailroadNotificationSection(
                    isRailroadProperty: _isRailroadProperty,
                    onRailroadPropertyChanged: (v) {
                      setState(() => _isRailroadProperty = v);
                      _markDirty();
                    },
                    railroadClient: _railroadClient,
                    onClientChanged: (v) {
                      setState(() => _railroadClient = v);
                      _markDirty();
                    },
                    railroadNotified: _railroadNotified,
                    onNotifiedChanged: (v) {
                      setState(() => _railroadNotified = v);
                      _markDirty();
                    },
                    methodController: _notificationMethodController,
                    onAnyFieldChanged: () {
                      setState(() {});
                      _markDirty();
                    },
                  ),

                  const SizedBox(height: 24),

                  // Injured Person Section (conditional for Injury type)
                  if (_type == 'Injury' || _hasInjuredPerson) ...[
                    _sectionHeader('INJURED PERSON'),
                    const SizedBox(height: 12),
                    InjuredPersonForm(
                      person: _injuredPerson,
                      auth: _auth,
                      enabled: true,
                      onChanged: (p) {
                        setState(() => _injuredPerson = p);
                        _markDirty();
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Photos Section
                  _sectionHeader('PHOTOS'),
                  const SizedBox(height: 12),
                  _buildPhotoSection(),

                  const SizedBox(height: 32),

                  // Action Buttons
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// right, allowing voice dictation into the associated [controller].
  Widget _fieldWithVoice(Widget field, TextEditingController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        VoiceInputButton(controller: controller),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: HerzogText.heading(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : HerzogColors.richBlack,
          ),
        ),
        const SizedBox(height: 4),
        Container(height: 2, width: 40, color: HerzogColors.gold),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing selected photos
        if (_selectedPhotos.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedPhotos.asMap().entries.map((entry) {
              return Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? HerzogDarkColors.surfaceVariant : HerzogColors.lightGray,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? HerzogDarkColors.inputBorder : HerzogColors.borderGray),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.image,
                          color: HerzogColors.navyBlue,
                          size: 28,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value.name.length > 10
                              ? '${entry.value.name.substring(0, 10)}...'
                              : entry.value.name,
                          style: HerzogText.body(
                            fontSize: 9,
                            color: isDark ? Colors.white : HerzogColors.midGray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedPhotos.removeAt(entry.key));
                        _markDirty();
                      },
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: HerzogColors.errorRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: HerzogColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        // Add photo button
        Semantics(
          label: 'Add photo',
          button: true,
          child: OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.add_a_photo, size: 18),
            label: const Text('Add Photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: HerzogColors.navyBlue,
              side: const BorderSide(color: HerzogColors.navyBlue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: AppLoadingButton.secondary(
            label: 'Save Draft',
            isLoading: _saving,
            icon: Icons.save_outlined,
            onPressed: _saving || _submitting ? null : _saveDraft,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppLoadingButton(
            label: 'Submit',
            isLoading: _submitting,
            icon: Icons.send,
            onPressed: _saving || _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
