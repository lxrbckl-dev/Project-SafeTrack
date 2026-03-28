import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/herzog_theme.dart';
import '../data/incident_timeline_repository.dart';

/// A vertical timeline widget that displays the full lifecycle of an incident.
///
/// Each event is rendered as:
/// - A color-coded dot (green = created, blue = updated, amber = status_change,
///   red = escalation/reject)
/// - A connecting line between events
/// - The event timestamp, actor display name, and a human-readable description
///
/// ADA: every event tile carries a semantic label combining timestamp, user,
/// and description. The list is keyboard navigable via standard Focus traversal.
class IncidentTimeline extends StatelessWidget {
  /// The ordered list of events to display (oldest first).
  final List<TimelineEvent> events;

  const IncidentTimeline({super.key, required this.events});

  // ── Dot color per action ──────────────────────────────────────────────────

  static Color _dotColor(String action) {
    switch (action) {
      case 'create':
        return HerzogColors.successGreen;
      case 'update':
        return HerzogColors.navyBlue;
      case 'status_change':
        return HerzogColors.warningAmber;
      case 'escalation':
      case 'reject':
        return HerzogColors.errorRed;
      default:
        return HerzogColors.infoTeal;
    }
  }

  // ── Entity type label ─────────────────────────────────────────────────────

  static String _entityLabel(String entityType) {
    switch (entityType) {
      case 'incident':
        return 'Incident';
      case 'investigation':
        return 'Investigation';
      case 'capa':
        return 'CAPA';
      default:
        return entityType;
    }
  }

  // ── Role label ────────────────────────────────────────────────────────────

  static String _roleLabel(String role) {
    switch (role) {
      case 'field_reporter':
        return 'Field Reporter';
      case 'safety_coordinator':
        return 'Safety Coordinator';
      case 'safety_manager':
        return 'Safety Manager';
      case 'pm':
        return 'Project Manager';
      case 'division_manager':
        return 'Division Manager';
      case 'executive':
        return 'Executive';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: HerzogColors.smoke,
                semanticLabel: 'No timeline events',
              ),
              const SizedBox(height: 12),
              Text(
                'No timeline events yet',
                style: HerzogText.body(color: HerzogColors.midGray),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isLast = index == events.length - 1;
        return _TimelineEventTile(
          event: event,
          isLast: isLast,
          dotColor: _dotColor(event.action),
          entityLabel: _entityLabel(event.entityType),
          roleLabel: _roleLabel(event.userRole),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal tile — one row in the vertical timeline.
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineEventTile extends StatelessWidget {
  final TimelineEvent event;
  final bool isLast;
  final Color dotColor;
  final String entityLabel;
  final String roleLabel;

  const _TimelineEventTile({
    required this.event,
    required this.isLast,
    required this.dotColor,
    required this.entityLabel,
    required this.roleLabel,
  });

  static final _dateFormat = DateFormat('MM/dd/yyyy hh:mm a');

  @override
  Widget build(BuildContext context) {
    final timestampStr = _dateFormat.format(event.timestamp.toLocal());
    final semanticLabel =
        '$timestampStr — ${event.userDisplayName} ($roleLabel): '
        '${event.description}';

    return Semantics(
      label: semanticLabel,
      child: Focus(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: dot + connecting line
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    // Dot
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: HerzogColors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.35),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    // Connecting line (hidden for last item)
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: HerzogColors.borderGray,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Right column: content card
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 8 : 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HerzogColors.white,
                      border: Border.all(color: HerzogColors.borderGray),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Entity type chip + timestamp
                        Row(
                          children: [
                            _EntityChip(label: entityLabel, color: dotColor),
                            const Spacer(),
                            Text(
                              timestampStr,
                              style: HerzogText.label(
                                fontSize: 11,
                                color: HerzogColors.midGray,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Description
                        Text(
                          event.description,
                          style: HerzogText.body(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // User + role
                        Text(
                          '${event.userDisplayName} · $roleLabel',
                          style: HerzogText.body(
                            fontSize: 12,
                            color: HerzogColors.midGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small colored entity-type chip used in each event card.
// ─────────────────────────────────────────────────────────────────────────────

class _EntityChip extends StatelessWidget {
  final String label;
  final Color color;

  const _EntityChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: HerzogText.label(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
