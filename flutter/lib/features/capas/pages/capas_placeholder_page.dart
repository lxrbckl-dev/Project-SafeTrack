import 'package:flutter/material.dart';
import '../../../app/herzog_theme.dart';

/// Placeholder for the CAPAs feature (future task will replace this).
class CapasPlaceholderPage extends StatelessWidget {
  const CapasPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CAPAS')),
      body: Center(
        child: Text('CAPAs', style: HerzogText.heading(fontSize: 24)),
      ),
    );
  }
}
