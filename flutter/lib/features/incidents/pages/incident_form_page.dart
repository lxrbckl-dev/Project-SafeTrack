import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../../shared/widgets/app_date_picker.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_loading_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../auth/data/auth_service.dart';
import '../../chat/data/form_fill_service.dart';
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
class IncidentFormPage extends StatefulWidget {
  /// Incident ID for edit mode. Null for create mode.
  final int? incidentId;

  const IncidentFormPage({super.key, this.incidentId});

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
    }
    // TASK-019: Check for AI-dispatched form fill data.
    _consumeFormFillData();
  }

  /// Consumes pending form fill data from [FormFillService] (AI agent dispatch).
  ///
  /// Maps field names from the AI action schema to form controllers/state.
  /// Silently skips unknown fields per spec.
  void _consumeFormFillData() {
    final formFillService = context.read<FormFillService>();
    final fields = formFillService.consumePendingFields();
    if (fields == null || fields.isEmpty) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved successfully')),
        );
        context.go('/incidents');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save draft: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incident submitted successfully')),
        );
        context.go('/incidents');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit incident: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (photo != null && mounted) {
        setState(() => _selectedPhotos.add(photo));
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'EDIT INCIDENT' : 'NEW INCIDENT'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/incidents'),
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
                  onChanged: (v) => setState(() {
                    _type = v;
                    // Auto-show injured person section for Injury type
                    if (v == 'Injury') {
                      _hasInjuredPerson = true;
                    }
                  }),
                  required: true,
                  hint: 'Select type',
                  validator: (v) => v == null ? 'Type is required' : null,
                ),
                const SizedBox(height: 12),
                AppDatePicker(
                  label: 'Incident Date',
                  selectedDate: _date,
                  onDateSelected: (d) => setState(() => _date = d),
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
                    _latitude = lat;
                    _longitude = lon;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Division',
                  controller: _divisionController,
                  hint: 'e.g., HCC, HRSI, HSI',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Project / Job Site',
                  controller: _projectController,
                  hint: 'Enter project or job site name',
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 24),

                // Description Section
                _sectionHeader('DESCRIPTION'),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Description',
                  controller: _descriptionController,
                  hint: 'Describe the incident...',
                  maxLines: 4,
                  required: true,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Description is required' : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Immediate Actions Taken',
                  controller: _immediateActionsController,
                  hint: 'Describe any immediate actions...',
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 24),

                // Classification Section
                _sectionHeader('CLASSIFICATION'),
                const SizedBox(height: 12),
                AppDropdown<String>(
                  label: 'Severity',
                  options: _severities,
                  value: _severity,
                  onChanged: (v) => setState(() => _severity = v),
                  hint: 'Select severity',
                ),
                const SizedBox(height: 12),
                AppDropdown<String>(
                  label: 'Potential Severity',
                  options: _severities,
                  value: _potentialSeverity,
                  onChanged: (v) => setState(() => _potentialSeverity = v),
                  hint: 'Select potential severity',
                ),
                const SizedBox(height: 12),
                AppDropdown<String>(
                  label: 'Shift',
                  options: _shifts,
                  value: _shift,
                  onChanged: (v) => setState(() => _shift = v),
                  hint: 'Select shift',
                ),
                const SizedBox(height: 12),
                AppDropdown<String>(
                  label: 'Weather Conditions',
                  options: _weatherOptions,
                  value: _weather,
                  onChanged: (v) => setState(() => _weather = v),
                  hint: 'Select weather',
                ),

                const SizedBox(height: 24),

                // Railroad Section (conditional)
                _sectionHeader('RAILROAD'),
                const SizedBox(height: 12),
                RailroadNotificationSection(
                  isRailroadProperty: _isRailroadProperty,
                  onRailroadPropertyChanged: (v) =>
                      setState(() => _isRailroadProperty = v),
                  railroadClient: _railroadClient,
                  onClientChanged: (v) => setState(() => _railroadClient = v),
                  railroadNotified: _railroadNotified,
                  onNotifiedChanged: (v) =>
                      setState(() => _railroadNotified = v),
                  methodController: _notificationMethodController,
                  onAnyFieldChanged: () => setState(() {}),
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
                    onChanged: (p) => setState(() => _injuredPerson = p),
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
    );
  }

  Widget _sectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: HerzogText.heading(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: HerzogColors.richBlack,
          ),
        ),
        const SizedBox(height: 4),
        Container(height: 2, width: 40, color: HerzogColors.gold),
      ],
    );
  }

  Widget _buildPhotoSection() {
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
                      color: HerzogColors.lightGray,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HerzogColors.borderGray),
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
                            color: HerzogColors.midGray,
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
                      onTap: () =>
                          setState(() => _selectedPhotos.removeAt(entry.key)),
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
