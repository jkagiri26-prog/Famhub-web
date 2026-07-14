/// ============================================================
/// SIGN IN SCREEN — Email/password sign-in and sign-up
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/presentation/pages/ = page layer
///
/// ✅ Responsibilities:
///   - Email/password sign-in form
///   - Email/password sign-up form (toggle)
///   - Error display
///   - Uses SupabaseService through session provider
///
/// ❌ Does NOT:
///   - Know about routing
///   - Contain business logic
/// ============================================================

import 'package:flutter/material.dart';

class SignInScreenPage extends StatefulWidget {
  final Future<bool> Function(String email, String password) onSignIn;
  final Future<bool> Function(String email, String password) onSignUp;
  final VoidCallback onBack;

  const SignInScreenPage({
    super.key,
    required this.onSignIn,
    required this.onSignUp,
    required this.onBack,
  });

  @override
  State<SignInScreenPage> createState() => _SignInScreenPageState();
}

class _SignInScreenPageState extends State<SignInScreenPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = _isSignUp
          ? await widget.onSignUp(
              _emailController.text.trim(),
              _passwordController.text,
            )
          : await widget.onSignIn(
              _emailController.text.trim(),
              _passwordController.text,
            );

      if (!mounted) return;

      if (!success) {
        setState(() {
          _error = _isSignUp
              ? 'Sign up failed. Please try again.'
              : 'Invalid email or password.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: colorScheme.onSurface),
          onPressed: widget.onBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                Text(
                  _isSignUp ? 'Create Account' : 'Welcome Back',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp
                      ? 'Sign up to start managing your farm'
                      : 'Sign in to continue to your farm',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 40),

                // ── Email ──
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ── Password ──
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: [
                    _isSignUp
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: _isSignUp
                        ? 'At least 6 characters'
                        : 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (_isSignUp && value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                // ── Error ──
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Submit Button ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Toggle Sign Up / Sign In ──
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                      });
                    },
                    child: Text.rich(
                      TextSpan(
                        text: _isSignUp
                            ? 'Already have an account? '
                            : "Don't have an account? ",
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        children: [
                          TextSpan(
                            text: _isSignUp ? 'Sign In' : 'Create One',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
