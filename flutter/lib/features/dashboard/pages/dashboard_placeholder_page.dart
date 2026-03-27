import 'package:flutter/material.dart';
import '../../../app/herzog_theme.dart';

/// Placeholder for the Safety Dashboard (TASK-005 will replace this).
class DashboardPlaceholderPage extends StatelessWidget {
  const DashboardPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DASHBOARD')),
      body: Center(
        child: Text('Dashboard', style: HerzogText.heading(fontSize: 24)),
      ),
    );
  }
}
