import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/herzog_theme.dart';
import '../data/auth_service.dart';

/// Configurable via `--dart-define` at build time or docker-compose build args.
const String _supportEmail = String.fromEnvironment(
  'SUPPORT_EMAIL',
  defaultValue: 'aarbuckle@herzog.com',
);
const String _supportPhone = String.fromEnvironment(
  'SUPPORT_PHONE',
  defaultValue: '1-816-273-2285',
);
const String _supportPhoneTel = String.fromEnvironment(
  'SUPPORT_PHONE_TEL',
  defaultValue: '18162732285',
);

/// Email/password login page with forgot password and support contact links.
///
/// Users enter email + password for seeded test accounts (all password: demo1234).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: HerzogColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAFETRACK'),
        backgroundColor: HerzogColors.richBlack,
        foregroundColor: HerzogColors.gold,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative background image — excluded from accessibility tree.
          Semantics(
            excludeSemantics: true,
            child: Image.asset(
              'assets/herzog-bg.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Semi-transparent overlay to ensure WCAG contrast for content above.
          Container(color: Colors.black.withValues(alpha: 0.6)),

          // Login form — solid-background card guarantees text contrast
          // independent of the image/overlay behind it.
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                  child: Container(
                    decoration: BoxDecoration(
                      color: HerzogColors.offWhite,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page heading
                  Semantics(
                    header: true,
                    child: Text(
                      'SIGN IN',
                      style: HerzogText.heading(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your credentials to access the SafeTrack platform.',
                    style: HerzogText.body(fontSize: 15),
                  ),
                  const SizedBox(height: 32),

                  // Login form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email
                        Semantics(
                          label: 'Email address',
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@safetrack.demo',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required';
                              }
                              if (!value.contains('@')) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        Semantics(
                          label: 'Password',
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        SizedBox(
                          height: 48,
                          child: Semantics(
                            button: true,
                            label: 'Sign in',
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: HerzogColors.navyBlue,
                                foregroundColor: HerzogColors.white,
                                disabledBackgroundColor: HerzogColors.navyBlue
                                    .withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: HerzogColors.white,
                                      ),
                                    )
                                  : Text(
                                      'SIGN IN',
                                      style: HerzogText.heading(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: HerzogColors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        // Forgot Password link
                        const SizedBox(height: 16),
                        Divider(color: HerzogColors.borderGray),
                        const SizedBox(height: 12),
                        Center(
                          child: Semantics(
                            button: true,
                            label: 'Forgot password, opens email',
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => launchUrl(
                                  Uri.parse(
                                    'mailto:$_supportEmail'
                                    '?subject=SafeTrack%20Forgot%20My%20Password'
                                    '&body=Hello%2C%20I%20need%20help%20resetting'
                                    '%20my%20SafeTrack%20password.%0A%0AName%3A%20'
                                    '%0AEmail%3A%20%0ARole%3A%20%0A%0AThank%20you.',
                                  ),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style:
                                      HerzogText.body(
                                        fontSize: 14,
                                        color: HerzogColors.gold,
                                      ).copyWith(
                                        decoration: TextDecoration.underline,
                                        decorationColor: HerzogColors.gold,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Support contact line
                        const SizedBox(height: 12),
                        Center(
                          child: Text.rich(
                            TextSpan(
                              style: HerzogText.body(
                                fontSize: 13,
                                color: HerzogColors.midGray,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Need help? Contact support at ',
                                ),
                                TextSpan(
                                  text: _supportPhone,
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => launchUrl(
                                      Uri.parse('tel:$_supportPhoneTel'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  style:
                                      HerzogText.body(
                                        fontSize: 13,
                                        color: HerzogColors.midGray,
                                      ).copyWith(
                                        decoration: TextDecoration.underline,
                                        decorationColor: HerzogColors.midGray,
                                      ),
                                  semanticsLabel: 'Call support',
                                ),
                                const TextSpan(text: ' or '),
                                TextSpan(
                                  text: _supportEmail,
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => launchUrl(
                                      Uri.parse('mailto:$_supportEmail'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  style:
                                      HerzogText.body(
                                        fontSize: 13,
                                        color: HerzogColors.midGray,
                                      ).copyWith(
                                        decoration: TextDecoration.underline,
                                        decorationColor: HerzogColors.midGray,
                                      ),
                                  semanticsLabel: 'Email support',
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
