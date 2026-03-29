import 'package:flutter/material.dart';

import '../../../app/herzog_theme.dart';

/// A labelled section divider used to group related settings visually.
class SettingSectionHeader extends StatelessWidget {
  const SettingSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: HerzogText.heading(
              fontSize: 14,
              color: isDark ? Colors.white : HerzogColors.richBlack,
            ),
          ),
          Divider(
            height: 8,
            thickness: 1,
            color: isDark ? HerzogDarkColors.border : null,
          ),
        ],
      ),
    );
  }
}
