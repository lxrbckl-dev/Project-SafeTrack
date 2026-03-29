import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/herzog_theme.dart';

/// Help / User Guide page that renders the wiki.md asset with Herzog branding.
///
/// ADA/WCAG compliance:
/// - Semantic heading structure preserved from Markdown (WCAG 1.3.1).
/// - Text scales with user font-size preferences (WCAG 1.4.4).
/// - Dark-mode aware — all colours meet WCAG AA contrast ratios.
class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  late Future<String> _wikiFuture;

  @override
  void initState() {
    super.initState();
    _wikiFuture = rootBundle.loadString('assets/wiki.md');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor =
        isDark ? Colors.white : HerzogColors.richBlack;
    final bodyColor =
        isDark ? Colors.white : HerzogColors.richBlack;
    final linkColor =
        isDark ? HerzogColors.gold : HerzogColors.navyBlue;
    final codeBlockBg =
        isDark ? HerzogDarkColors.surfaceVariant : HerzogColors.offWhite;
    final tableHeadColor =
        isDark ? HerzogDarkColors.textPrimary : HerzogColors.richBlack;
    final tableBodyColor =
        isDark ? HerzogDarkColors.textSecondary : HerzogColors.darkGray;

    final baseSheet = MarkdownStyleSheet.fromTheme(Theme.of(context));

    final styleSheet = baseSheet.copyWith(
      h1: GoogleFonts.oswald(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      h2: GoogleFonts.oswald(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: headingColor,
      ),
      h3: GoogleFonts.oswald(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: headingColor,
      ),
      h4: GoogleFonts.oswald(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: headingColor,
      ),
      h5: GoogleFonts.oswald(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: headingColor,
      ),
      h6: GoogleFonts.oswald(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: headingColor,
      ),
      p: GoogleFonts.roboto(
        fontSize: 14,
        color: bodyColor,
      ),
      listBullet: GoogleFonts.roboto(
        fontSize: 14,
        color: bodyColor,
      ),
      a: GoogleFonts.roboto(
        fontSize: 14,
        color: linkColor,
        decoration: TextDecoration.underline,
      ),
      code: GoogleFonts.robotoMono(
        fontSize: 13,
        color: bodyColor,
        backgroundColor: codeBlockBg,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBlockBg,
        borderRadius: BorderRadius.circular(4),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      tableHead: GoogleFonts.roboto(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: tableHeadColor,
      ),
      tableBody: GoogleFonts.roboto(
        fontSize: 13,
        color: tableBodyColor,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('HELP GUIDE'),
      ),
      body: FutureBuilder<String>(
        future: _wikiFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load the help guide. Please try again later.',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: isDark
                        ? HerzogDarkColors.textSecondary
                        : HerzogColors.darkGray,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Markdown(
            data: snapshot.data ?? '',
            styleSheet: styleSheet,
            selectable: true,
            padding: const EdgeInsets.all(24),
          );
        },
      ),
    );
  }
}
