import 'package:flutter/material.dart';
import '../../../app/herzog_theme.dart';

/// Placeholder for the Investigations feature (future task will replace this).
class InvestigationsPlaceholderPage extends StatelessWidget {
  const InvestigationsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('INVESTIGATIONS')),
      body: Center(
        child: Text('Investigations', style: HerzogText.heading(fontSize: 24)),
      ),
    );
  }
}
