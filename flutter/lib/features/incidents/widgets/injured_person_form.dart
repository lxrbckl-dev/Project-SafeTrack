import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';
import '../../../core/constants/divisions.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/role.dart';
import '../data/incident_repository.dart';

/// Sub-form for entering injured person details.
///
/// Medical fields (injury type, body part, treatment type, return-to-work
/// status) are only shown if the current user [isAtLeast] Safety Coordinator.
/// For lower roles, a [RESTRICTED] notice is displayed.
class InjuredPersonForm extends StatelessWidget {
  /// The current injured person data.
  final InjuredPerson person;

  /// Auth service for role checking.
  final AuthService auth;

  /// Called when any field changes, providing updated person data.
  final ValueChanged<InjuredPerson> onChanged;

  /// Whether the form is enabled for editing.
  final bool enabled;

  static const _injuryTypes = [
    AppDropdownOption(value: 'Laceration', label: 'Laceration'),
    AppDropdownOption(value: 'Fracture', label: 'Fracture'),
    AppDropdownOption(value: 'Sprain/Strain', label: 'Sprain/Strain'),
    AppDropdownOption(value: 'Contusion', label: 'Contusion'),
    AppDropdownOption(value: 'Burn', label: 'Burn'),
    AppDropdownOption(value: 'Puncture', label: 'Puncture'),
    AppDropdownOption(value: 'Amputation', label: 'Amputation'),
    AppDropdownOption(value: 'Crush Injury', label: 'Crush Injury'),
    AppDropdownOption(value: 'Eye Injury', label: 'Eye Injury'),
    AppDropdownOption(value: 'Hearing Loss', label: 'Hearing Loss'),
    AppDropdownOption(value: 'Respiratory', label: 'Respiratory'),
    AppDropdownOption(value: 'Chemical Exposure', label: 'Chemical Exposure'),
    AppDropdownOption(value: 'Other', label: 'Other'),
  ];

  static const _bodyParts = [
    AppDropdownOption(value: 'Head', label: 'Head'),
    AppDropdownOption(value: 'Neck', label: 'Neck'),
    AppDropdownOption(value: 'Shoulder', label: 'Shoulder'),
    AppDropdownOption(value: 'Upper Arm', label: 'Upper Arm'),
    AppDropdownOption(value: 'Elbow', label: 'Elbow'),
    AppDropdownOption(value: 'Forearm', label: 'Forearm'),
    AppDropdownOption(value: 'Wrist', label: 'Wrist'),
    AppDropdownOption(value: 'Hand', label: 'Hand'),
    AppDropdownOption(value: 'Finger', label: 'Finger'),
    AppDropdownOption(value: 'Chest', label: 'Chest'),
    AppDropdownOption(value: 'Back', label: 'Back'),
    AppDropdownOption(value: 'Hip', label: 'Hip'),
    AppDropdownOption(value: 'Upper Leg', label: 'Upper Leg'),
    AppDropdownOption(value: 'Knee', label: 'Knee'),
    AppDropdownOption(value: 'Lower Leg', label: 'Lower Leg'),
    AppDropdownOption(value: 'Ankle', label: 'Ankle'),
    AppDropdownOption(value: 'Foot', label: 'Foot'),
    AppDropdownOption(value: 'Toe', label: 'Toe'),
    AppDropdownOption(value: 'Eye', label: 'Eye'),
    AppDropdownOption(value: 'Multiple', label: 'Multiple'),
  ];

  static const _sides = [
    AppDropdownOption(value: 'Left', label: 'Left'),
    AppDropdownOption(value: 'Right', label: 'Right'),
    AppDropdownOption(value: 'Both', label: 'Both'),
    AppDropdownOption(value: 'N/A', label: 'N/A'),
  ];

  static const _treatmentTypes = [
    AppDropdownOption(value: 'First Aid', label: 'First Aid'),
    AppDropdownOption(value: 'Medical Treatment', label: 'Medical Treatment'),
    AppDropdownOption(value: 'Hospitalization', label: 'Hospitalization'),
    AppDropdownOption(value: 'None', label: 'None'),
  ];

  static const _returnToWorkStatuses = [
    AppDropdownOption(value: 'Full Duty', label: 'Full Duty'),
    AppDropdownOption(value: 'Restricted Duty', label: 'Restricted Duty'),
    AppDropdownOption(value: 'Lost Time', label: 'Lost Time'),
    AppDropdownOption(value: 'Pending', label: 'Pending'),
  ];

  const InjuredPersonForm({
    super.key,
    required this.person,
    required this.auth,
    required this.onChanged,
    this.enabled = true,
  });

  InjuredPerson _update({
    String? name,
    String? jobTitle,
    String? division,
    String? injuryType,
    String? bodyPart,
    String? bodyPartSide,
    String? treatmentType,
    String? returnToWorkStatus,
  }) {
    return InjuredPerson(
      id: person.id,
      incidentId: person.incidentId,
      name: name ?? person.name,
      jobTitle: jobTitle ?? person.jobTitle,
      division: division ?? person.division,
      injuryType: injuryType ?? person.injuryType,
      bodyPart: bodyPart ?? person.bodyPart,
      bodyPartSide: bodyPartSide ?? person.bodyPartSide,
      treatmentType: treatmentType ?? person.treatmentType,
      returnToWorkStatus: returnToWorkStatus ?? person.returnToWorkStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSeeMedical = auth.isAtLeast(Role.safetyCoordinator);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INJURED PERSON',
              style: HerzogText.heading(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HerzogColors.richBlack,
              ),
            ),
            const SizedBox(height: 16),

            // Name
            AppTextField(
              label: 'Name',
              initialValue: person.name,
              enabled: enabled,
              required: true,
              onChanged: (v) => onChanged(_update(name: v)),
            ),
            const SizedBox(height: 12),

            // Job Title
            AppTextField(
              label: 'Job Title',
              initialValue: person.jobTitle,
              enabled: enabled,
              onChanged: (v) => onChanged(_update(jobTitle: v)),
            ),
            const SizedBox(height: 12),

            // Division
            AppDropdown<String>(
              label: 'Division',
              options: kDivisions
                  .map((d) => AppDropdownOption(value: d, label: d))
                  .toList(),
              value: person.division.isEmpty ? null : person.division,
              enabled: enabled,
              onChanged: (v) => onChanged(_update(division: v ?? '')),
              hint: 'Select division',
            ),
            const SizedBox(height: 12),

            // Medical fields — restricted to Safety Coordinator+
            if (canSeeMedical) ...[
              // Injury Type
              AppDropdown<String>(
                label: 'Injury Type',
                options: _injuryTypes,
                value: person.injuryType.isEmpty ? null : person.injuryType,
                onChanged: (v) => onChanged(_update(injuryType: v ?? '')),
                hint: 'Select injury type',
                enabled: enabled,
              ),
              const SizedBox(height: 12),

              // Body Part
              AppDropdown<String>(
                label: 'Body Part',
                options: _bodyParts,
                value: person.bodyPart.isEmpty ? null : person.bodyPart,
                onChanged: (v) => onChanged(_update(bodyPart: v ?? '')),
                hint: 'Select body part',
                enabled: enabled,
              ),
              const SizedBox(height: 12),

              // Side
              AppDropdown<String>(
                label: 'Side',
                options: _sides,
                value: person.bodyPartSide.isEmpty ? null : person.bodyPartSide,
                onChanged: (v) => onChanged(_update(bodyPartSide: v ?? '')),
                hint: 'Select side',
                enabled: enabled,
              ),
              const SizedBox(height: 12),

              // Treatment Type
              AppDropdown<String>(
                label: 'Treatment Type',
                options: _treatmentTypes,
                value: person.treatmentType.isEmpty
                    ? null
                    : person.treatmentType,
                onChanged: (v) => onChanged(_update(treatmentType: v ?? '')),
                hint: 'Select treatment type',
                enabled: enabled,
              ),
              const SizedBox(height: 12),

              // Return to Work Status
              AppDropdown<String>(
                label: 'Return to Work Status',
                options: _returnToWorkStatuses,
                value: person.returnToWorkStatus.isEmpty
                    ? null
                    : person.returnToWorkStatus,
                onChanged: (v) =>
                    onChanged(_update(returnToWorkStatus: v ?? '')),
                hint: 'Select status',
                enabled: enabled,
              ),
            ] else ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HerzogColors.warningLight,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock,
                      size: 16,
                      color: HerzogColors.warningAmber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Medical fields restricted to Safety Coordinator and above',
                        style: HerzogText.body(
                          fontSize: 13,
                          color: HerzogColors.warningAmber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
