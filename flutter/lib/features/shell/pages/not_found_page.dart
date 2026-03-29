import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/herzog_theme.dart';

/// Configurable via `--dart-define` at build time or docker-compose build args.
const String _notFoundGifUrl = String.fromEnvironment(
  'NOT_FOUND_GIF_URL',
  defaultValue: '',
);

/// 404 Not Found page shown when a route cannot be matched.
///
/// Displays a centered layout with:
/// - An animated GIF illustration (404.gif) inside a constrained box
/// - "PAGE NOT FOUND" heading in Oswald
/// - A subtitle in Roboto
/// - A "BACK TO DASHBOARD" button that navigates to /dashboard
///
/// The Image.asset call uses an errorBuilder so the page renders gracefully
/// even if the GIF asset is not yet present.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? null : HerzogColors.offWhite,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration — constrained to 400×400; graceful fallback if
            // the GIF is missing.
            Semantics(
              label: 'Page not found illustration',
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  maxHeight: 400,
                ),
                child: _notFoundGifUrl.isNotEmpty
                    ? Image.network(
                        _notFoundGifUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback icon when the network GIF is not available.
                          return const Icon(
                            Icons.error_outline,
                            size: 120,
                            color: HerzogColors.midGray,
                          );
                        },
                      )
                    : Image.asset(
                        'assets/404.gif',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback icon when the GIF asset is not available.
                          return const Icon(
                            Icons.error_outline,
                            size: 120,
                            color: HerzogColors.midGray,
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // "PAGE NOT FOUND" heading — Oswald, uppercase, richBlack
            Text(
              'PAGE NOT FOUND',
              style: HerzogText.heading(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : HerzogColors.richBlack,
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle — Roboto, midGray
            Text(
              "The page you're looking for doesn't exist.",
              style: HerzogText.body(
                fontSize: 16,
                color: isDark ? Colors.white : HerzogColors.midGray,
              ),
            ),

            const SizedBox(height: 32),

            // "BACK TO DASHBOARD" button — navyBlue bg, white text
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: HerzogColors.navyBlue,
                foregroundColor: HerzogColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              onPressed: () => context.go('/dashboard'),
              child: Text(
                'BACK TO DASHBOARD',
                style: HerzogText.label(
                  fontSize: 13,
                  color: HerzogColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
