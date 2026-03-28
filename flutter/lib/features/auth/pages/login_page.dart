import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/herzog_theme.dart';
import '../data/auth_service.dart';

/// Email/password login page with a test accounts reference card.
///
/// Replaces the old DevLoginPage (role picker). Users enter email + password,
/// or tap a test account row to auto-fill the email field for convenience.
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

  static const _testAccounts = [
    _TestAccount('reporter@safetrack.demo', 'Field Reporter'),
    _TestAccount('coordinator@safetrack.demo', 'Safety Coordinator'),
    _TestAccount('manager@safetrack.demo', 'Safety Manager'),
    _TestAccount('pm@safetrack.demo', 'Project Manager'),
    _TestAccount('director@safetrack.demo', 'Division Manager'),
    _TestAccount('executive@safetrack.demo', 'Executive'),
    _TestAccount('admin@safetrack.demo', 'Admin'),
  ];

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

  void _autofillEmail(String email) {
    _emailController.text = email;
    _passwordController.text = 'demo1234';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HerzogColors.offWhite,
      appBar: AppBar(
        title: const Text('SAFETRACK'),
        backgroundColor: HerzogColors.richBlack,
        foregroundColor: HerzogColors.gold,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Image.asset('assets/logo.png', height: 80),
                  const SizedBox(height: 32),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Test Accounts card
                  _TestAccountsCard(
                    accounts: _testAccounts,
                    onTap: _autofillEmail,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Test Account data class
// ---------------------------------------------------------------------------

class _TestAccount {
  const _TestAccount(this.email, this.roleName);
  final String email;
  final String roleName;
}

// ---------------------------------------------------------------------------
// Test Accounts card widget
// ---------------------------------------------------------------------------

class _TestAccountsCard extends StatelessWidget {
  const _TestAccountsCard({required this.accounts, required this.onTap});

  final List<_TestAccount> accounts;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Test accounts reference card. Password for all accounts: demo1234',
      child: Container(
        decoration: BoxDecoration(
          color: HerzogColors.richBlack,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: HerzogColors.gold, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: HerzogColors.gold, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TEST ACCOUNTS',
                    style: HerzogText.heading(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: HerzogColors.gold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'password: demo1234',
                    style: HerzogText.body(
                      fontSize: 12,
                      color: HerzogColors.smoke,
                    ),
                  ),
                ],
              ),
            ),

            // Account rows
            ...accounts.map(
              (account) => _TestAccountRow(
                account: account,
                onTap: () => onTap(account.email),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual test account row
// ---------------------------------------------------------------------------

class _TestAccountRow extends StatelessWidget {
  const _TestAccountRow({required this.account, required this.onTap});

  final _TestAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${account.roleName}: ${account.email}. Tap to auto-fill.',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: HerzogColors.gold.withValues(alpha: 0.08),
          focusColor: HerzogColors.gold.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    account.email,
                    style: HerzogText.body(
                      fontSize: 13,
                      color: HerzogColors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    account.roleName,
                    textAlign: TextAlign.end,
                    style: HerzogText.body(
                      fontSize: 12,
                      color: HerzogColors.smoke,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
