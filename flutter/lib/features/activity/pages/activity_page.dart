import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';
import '../widgets/activity_feed.dart';

/// Full-page view of the live activity feed.
///
/// Route: /activity
///
/// Shows up to 50 recent activity items with auto-refresh.
/// Accessible from the dashboard "View all activity" link.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? HerzogDarkColors.border
                  : HerzogColors.borderGray,
            ),
          ),
          child: const ActivityFeed(compact: false),
        ),
      ),
    );
  }
}
