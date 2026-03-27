import 'package:flutter/material.dart';
import '../../../app/herzog_theme.dart';

/// Placeholder for the Incidents feature (future task will replace this).
class IncidentsPlaceholderPage extends StatelessWidget {
  const IncidentsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('INCIDENTS')),
      body: Center(
        child: Text('Incidents', style: HerzogText.heading(fontSize: 24)),
      ),
    );
  }
}
