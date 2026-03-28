import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';
import '../../../shared/widgets/app_dropdown.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Conditional form section for railroad property incidents.
///
/// Shown only when the "Railroad Property" toggle is enabled.
/// Contains railroad client dropdown and notification tracking fields.
class RailroadNotificationSection extends StatelessWidget {
  /// Whether this is a railroad property incident.
  final bool isRailroadProperty;

  /// Callback when the railroad property toggle changes.
  final ValueChanged<bool> onRailroadPropertyChanged;

  /// Selected railroad client (BNSF, UP, CSX, NS).
  final String? railroadClient;

  /// Callback when railroad client changes.
  final ValueChanged<String?> onClientChanged;

  /// Whether the railroad has been notified.
  final bool railroadNotified;

  /// Callback when notified checkbox changes.
  final ValueChanged<bool> onNotifiedChanged;

  /// Notification method controller.
  final TextEditingController methodController;

  /// Whether the form is enabled.
  final bool enabled;

  /// Called when any field changes (for completion tracking).
  final VoidCallback? onAnyFieldChanged;

  static const _railroadClients = [
    AppDropdownOption(value: 'BNSF', label: 'BNSF'),
    AppDropdownOption(value: 'UP', label: 'Union Pacific'),
    AppDropdownOption(value: 'CSX', label: 'CSX'),
    AppDropdownOption(value: 'NS', label: 'Norfolk Southern'),
  ];

  const RailroadNotificationSection({
    super.key,
    required this.isRailroadProperty,
    required this.onRailroadPropertyChanged,
    this.railroadClient,
    required this.onClientChanged,
    required this.railroadNotified,
    required this.onNotifiedChanged,
    required this.methodController,
    this.enabled = true,
    this.onAnyFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle
        Semantics(
          label: 'Railroad property toggle',
          toggled: isRailroadProperty,
          child: SwitchListTile(
            title: Text(
              'Railroad Property Incident',
              style: HerzogText.body(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HerzogColors.darkGray,
              ),
            ),
            value: isRailroadProperty,
            onChanged: enabled
                ? (v) {
                    onRailroadPropertyChanged(v);
                    onAnyFieldChanged?.call();
                  }
                : null,
            activeThumbColor: HerzogColors.navyBlue,
            contentPadding: EdgeInsets.zero,
          ),
        ),

        // Conditional fields
        if (isRailroadProperty) ...[
          const SizedBox(height: 12),
          AppDropdown<String>(
            label: 'Railroad Client',
            options: _railroadClients,
            value: railroadClient,
            onChanged: (v) {
              onClientChanged(v);
              onAnyFieldChanged?.call();
            },
            hint: 'Select railroad',
            enabled: enabled,
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Client notified checkbox',
            toggled: railroadNotified,
            child: CheckboxListTile(
              title: Text(
                'Client Notified',
                style: HerzogText.body(
                  fontSize: 14,
                  color: HerzogColors.darkGray,
                ),
              ),
              value: railroadNotified,
              onChanged: enabled
                  ? (v) {
                      onNotifiedChanged(v ?? false);
                      onAnyFieldChanged?.call();
                    }
                  : null,
              activeColor: HerzogColors.navyBlue,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ),
          if (railroadNotified) ...[
            const SizedBox(height: 12),
            AppTextField(
              label: 'Notification Method',
              controller: methodController,
              hint: 'e.g., Phone call, Email',
              enabled: enabled,
              onChanged: (_) => onAnyFieldChanged?.call(),
            ),
          ],
        ],
      ],
    );
  }
}
