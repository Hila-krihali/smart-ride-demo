import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/app_config.dart';
import '../../models/app_user.dart';
import '../../services/api_service.dart';
import '../../utils/app_colors.dart';
import '../driver/driver_dashboard_screen.dart';
import '../escort/escort_dashboard_screen.dart';
import '../management/management_dashboard_screen.dart';
import '../parent/parent_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  static const _demoEmails = [
    'yael@example.com',
    'sara@example.com',
    'david@example.com',
    'rachel@example.com',
  ];

  static const _demoRoleLabels = {
    'yael@example.com': 'מנהלת - יעל אברהם',
    'sara@example.com': 'מלווה - שרה כהן',
    'david@example.com': 'נהג - דוד מזרחי',
    'rachel@example.com': 'הורה - רחל לוי',
  };

  static List<String> get _exampleEmails =>
      AppConfig.isDemo ? _demoEmails : _devExampleEmails;

  static const _devExampleEmails = [
    'yael@example.com',
    'sara@example.com',
    'david@example.com',
    'rachel@example.com',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('LoginScreen email login submitted: email=$email');

    try {
      final user = await ApiService.login(email: email);

      if (!mounted) return;

      if (user.id <= 0 || user.role.isEmpty) {
        throw StateError('Login response did not include id and role.');
      }

      debugPrint(
        'LoginScreen navigating after backend login: user_id=${user.id}, role=${user.role}',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => _dashboardForUser(user)),
      );
    } catch (error) {
      debugPrint('LoginScreen backend login failed for $email: $error');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'No user was found for this email, or the backend is unavailable.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _dashboardForUser(AppUser user) {
    switch (user.role.toLowerCase()) {
      case 'parent':
        return ParentDashboardScreen(user: user);
      case 'driver':
        return DriverDashboardScreen(user: user);
      case 'escort':
        return EscortDashboardScreen(user: user);
      case 'manager':
      case 'admin':
      case 'management':
        return ManagementDashboardScreen(user: user);
      default:
        throw StateError('Unsupported user role: ${user.role}');
    }
  }

  void _fillExampleEmail(String email) {
    _emailController.text = email;
    setState(() => _errorMessage = null);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.outlineVariant),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.directions_bus,
                                  size: 56,
                                  color: AppColors.primary,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Smart Ride',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with an email from the users table.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.heebo(
                          fontSize: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Enter an email address.';
                          }
                          if (!email.contains('@') || !email.contains('.')) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _submitLogin();
                          }
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.heebo(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitLogin,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(_isLoading ? 'Signing in...' : 'Login'),
                      ),
                      const SizedBox(height: 20),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        initiallyExpanded: AppConfig.isDemo,
                        title: Text(
                          AppConfig.isDemo
                              ? 'Demo accounts - tap one, then Login'
                              : 'Development example emails',
                          style: GoogleFonts.heebo(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        children: _exampleEmails.map((email) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.alternate_email),
                            title: Text(email),
                            subtitle: _demoRoleLabels[email] == null
                                ? null
                                : Text(_demoRoleLabels[email]!),
                            onTap: _isLoading ? null : () => _fillExampleEmail(email),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
