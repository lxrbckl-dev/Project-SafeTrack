import 'package:flutter/material.dart';
import '../../../app/herzog_theme.dart';

/// Placeholder for the Audit Log viewer (future task will replace this).
class AuditLogPlaceholderPage extends StatelessWidget {
  const AuditLogPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AUDIT LOG')),
      body: Center(
        child: Text('Audit Log', style: HerzogText.heading(fontSize: 24)),
      ),
    );
  }
}
