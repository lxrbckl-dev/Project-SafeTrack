import 'package:flutter/material.dart';
import '../../../app/herzog_theme.dart';

/// Placeholder for the Admin Settings feature (TASK-003 will replace this).
class AdminPlaceholderPage extends StatelessWidget {
  const AdminPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ADMIN SETTINGS')),
      body: Center(
        child: Text('Admin Settings', style: HerzogText.heading(fontSize: 24)),
      ),
    );
  }
}
