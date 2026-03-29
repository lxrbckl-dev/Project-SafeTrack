import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../../auth/data/auth_service.dart';
import '../data/notification_preferences_repository.dart';

/// Notification preferences page allowing users to choose how they receive
/// notifications: In-App Only, Email Only, or Both.
///
/// ADA/WCAG:
/// - Radio buttons have descriptive labels (WCAG 1.3.1)
/// - Sufficient contrast on all text (WCAG 1.4.3)
/// - Form group has accessible label via Semantics (WCAG 1.3.1)
/// - Status feedback via SnackBar (WCAG 4.1.3)
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  final NotificationPreferencesRepository _repo =
      NotificationPreferencesRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _selectedPreference = 'both';

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final auth = context.read<AuthService>();
    if (auth.token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final pref = await _repo.getPreference(auth.token!);
      if (mounted) {
        setState(() {
          _selectedPreference = pref.preference;
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

  Future<void> _savePreference(String preference) async {
    final auth = context.read<AuthService>();
    if (auth.token == null || auth.userId == null) return;

    setState(() {
      _saving = true;
      _selectedPreference = preference;
    });

    try {
      await _repo.updatePreference(auth.token!, auth.userId!, preference);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification preferences updated'),
            backgroundColor: HerzogColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update preferences: $e'),
            backgroundColor: HerzogColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'NOTIFICATION PREFERENCES',
          style: HerzogText.heading(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HerzogColors.gold,
          ),
        ),
        backgroundColor: HerzogColors.richBlack,
        iconTheme: const IconThemeData(color: HerzogColors.smoke),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
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
              'Failed to load preferences',
              style: HerzogText.body(
                fontSize: 16,
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: HerzogText.body(
                fontSize: 12,
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPreference,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Text(
            'How would you like to receive notifications?',
            style: HerzogText.heading(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how SafeTrack delivers escalation alerts, overdue reminders, and review requests.',
            style: HerzogText.body(
              fontSize: 14,
              color: isDark ? Colors.white : HerzogColors.darkGray,
            ),
          ),
          const SizedBox(height: 24),

          // Preference options
          Semantics(
            label: 'Notification delivery method',
            child: Column(
              children: [
                _PreferenceOption(
                  value: 'both',
                  groupValue: _selectedPreference,
                  title: 'Both (In-App + Email)',
                  description:
                      'Receive notifications in the app and via email. Recommended for timely action on safety items.',
                  icon: Icons.notifications_active,
                  onChanged: _saving ? null : _savePreference,
                ),
                const SizedBox(height: 12),
                _PreferenceOption(
                  value: 'in_app_only',
                  groupValue: _selectedPreference,
                  title: 'In-App Only',
                  description:
                      'Notifications appear only in the app bell icon. No emails will be sent.',
                  icon: Icons.notifications,
                  onChanged: _saving ? null : _savePreference,
                ),
                const SizedBox(height: 12),
                _PreferenceOption(
                  value: 'email',
                  groupValue: _selectedPreference,
                  title: 'Email Only',
                  description:
                      'Notifications are sent via email. In-app notifications are still stored for history.',
                  icon: Icons.email,
                  onChanged: _saving ? null : _savePreference,
                ),
              ],
            ),
          ),

          if (_saving) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HerzogColors.infoLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: HerzogColors.infoTeal.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: HerzogColors.infoTeal,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Email notifications include direct links to overdue investigations, CAPAs, and railroad deadline items. '
                    'Make sure your email address is up to date in your profile.',
                    style: HerzogText.body(
                      fontSize: 13,
                      color: HerzogColors.infoTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A styled radio option card for notification preference selection.
class _PreferenceOption extends StatelessWidget {
  final String value;
  final String groupValue;
  final String title;
  final String description;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  const _PreferenceOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.description,
    required this.icon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = value == groupValue;

    return Semantics(
      label: '$title. $description',
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onChanged != null ? () => onChanged!(value) : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? HerzogColors.navyBlue.withValues(alpha: 0.06)
                : (isDark ? HerzogDarkColors.surfaceVariant : HerzogColors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? HerzogColors.navyBlue
                  : (isDark ? HerzogDarkColors.inputBorder : HerzogColors.borderGray),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? HerzogColors.navyBlue : HerzogColors.smoke,
                semanticLabel: title,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: HerzogText.body(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? (isDark ? HerzogColors.gold : HerzogColors.navyBlue)
                            : (isDark ? Colors.white : HerzogColors.richBlack),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: HerzogText.body(
                        fontSize: 12,
                        color: isDark ? Colors.white : HerzogColors.darkGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? HerzogColors.navyBlue
                        : HerzogColors.smoke,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: HerzogColors.navyBlue,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
