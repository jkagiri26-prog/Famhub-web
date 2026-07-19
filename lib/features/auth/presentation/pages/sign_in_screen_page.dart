/// ============================================================
/// SIGN IN SCREEN — OTP-based authentication
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/presentation/pages/ = page layer
///
/// ✅ Responsibilities:
///   - Unified OTP authentication for sign-in and sign-up
///   - Support phone, WhatsApp, and email as contact methods
///   - Four-digit OTP verification
///   - Error display and loading state
///
/// ✅ FLOW:
///   1. User enters phone/email and selects contact method
///   2. OTP is sent to chosen contact method
///   3. User enters 4-digit OTP
///   4. onAuthComplete is called on success
///
/// ❌ Does NOT:
///   - Know about routing
///   - Contain business logic
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:famhub_app/core/services/auth_service.dart';

/// Simple provider accessor for AuthService.
/// Avoids requiring Riverpod in this pure widget.
class _AuthServiceProvider {
  static AuthService? _instance;
  static AuthService get() {
    _instance ??= AuthService();
    return _instance!;
  }
}

/// Contact method for OTP delivery
enum ContactMethod {
  phone('Phone', Icons.phone_android_outlined),
  whatsapp('WhatsApp', Icons.chat_outlined),
  email('Email', Icons.email_outlined);

  final String label;
  final IconData icon;
  const ContactMethod(this.label, this.icon);
}

class SignInScreenPage extends StatefulWidget {
  /// OTP flow: Called after OTP verification succeeds.
  /// Should return true on success, false on failure.
  final Future<bool> Function({
    required String contact,
    required ContactMethod method,
    required String otp,
  })? onAuthenticate;

  /// Email/password flow: sign in with credentials.
  /// Returns true on success.
  final Future<bool> Function(String email, String password)? onSignIn;
  final Future<bool> Function(String email, String password)? onSignUp;

  /// Called when the user wants to go back.
  final VoidCallback onBack;

  /// Optional: message shown at the top (e.g., "Welcome Back" or "Create Account")
  final String title;

  /// Optional: subtitle shown below title
  final String subtitle;

  const SignInScreenPage({
    super.key,
    this.onAuthenticate,
    this.onSignIn,
    this.onSignUp,
    required this.onBack,
    this.title = 'Welcome to FAMHUB',
    this.subtitle = 'Enter your phone or email to continue',
  });

  @override
  State<SignInScreenPage> createState() => _SignInScreenPageState();
}

class _SignInScreenPageState extends State<SignInScreenPage> {
  final _contactController = TextEditingController();
  final _otpControllers = List.generate(4, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(4, (_) => FocusNode());
  // Email/password controllers for the legacy flow
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  ContactMethod _selectedMethod = ContactMethod.phone;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _contactController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Send OTP via Supabase Auth.
  /// Uses [AuthService] which wraps Supabase's signInWithOtp.
  Future<void> _sendOtp() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      setState(() => _error = 'Please enter your phone number or email');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      // Use the reusable AuthService to send OTP via Supabase
      final authService = _AuthServiceProvider.get();
      late OtpSendResult result;

      if (_selectedMethod == ContactMethod.email) {
        result = await authService.sendOtp(email: contact);
      } else {
        result = await authService.sendOtp(phone: contact);
      }

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
          _successMessage = 'OTP sent via ${_selectedMethod.label}';
        });

        // Auto-focus first OTP digit field
        Future.delayed(const Duration(milliseconds: 100), () {
          _otpFocusNodes[0].requestFocus();
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = result.error ?? 'Failed to send OTP. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Network error. Please check your connection and try again.';
      });
    }
  }

  /// Verify the entered OTP
  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 4) {
      setState(() => _error = 'Please enter the complete 4-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await widget.onAuthenticate!(
        contact: _contactController.text.trim(),
        method: _selectedMethod,
        otp: otp,
      );

      if (!mounted) return;

      if (!success) {
        setState(() {
          _error = 'Invalid OTP. Please try again.';
          _isLoading = false;
        });
      }
      // On success, the parent handles navigation
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Verification failed. Please try again.';
      });
    }
  }

  /// Resend OTP
  Future<void> _resendOtp() async {
    setState(() {
      _error = null;
      _successMessage = null;
    });

    // Clear OTP fields
    for (final c in _otpControllers) {
      c.clear();
    }

    await _sendOtp();
  }

  /// Handle digit input for OTP fields
  void _onOtpDigitChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      _otpFocusNodes[index + 1].requestFocus();
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Title ──
              Text(
                widget.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // If an OTP authenticate callback is not provided, render
              // a simple email/password sign-in UI (legacy flow).
              if (widget.onAuthenticate == null) ...[
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'you@example.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            final email = _emailController.text.trim();
                            final pass = _passwordController.text;
                            bool success = false;
                            if (widget.onSignIn != null) {
                              success = await widget.onSignIn!(email, pass);
                            }
                            if (!mounted) return;
                            setState(() => _isLoading = false);
                            if (success) {
                              Navigator.of(context).pop();
                            } else {
                              setState(() => _error = 'Sign in failed.');
                            }
                          },
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            final email = _emailController.text.trim();
                            final pass = _passwordController.text;
                            bool success = false;
                            if (widget.onSignUp != null) {
                              success = await widget.onSignUp!(email, pass);
                            }
                            if (!mounted) return;
                            setState(() => _isLoading = false);
                            if (success) {
                              Navigator.of(context).pop();
                            } else {
                              setState(() => _error = 'Sign up failed.');
                            }
                          },
                    child: const Text('Create Account'),
                  ),
                ),
              ] else if (!_otpSent) ...[
                // ═══════════════════════════════════════════════
                // STEP 1: Contact & Method Selection
                // ═══════════════════════════════════════════════

                // ── Contact Method Chips ──
                Text(
                  'Choose verification method',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ContactMethod.values.map((method) {
                    final isSelected = _selectedMethod == method;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            method.icon,
                            size: 18,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(method.label),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedMethod = method);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Contact Input (Phone or Email) ──
                TextFormField(
                  controller: _contactController,
                  keyboardType: _selectedMethod == ContactMethod.email
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: _selectedMethod == ContactMethod.email
                        ? 'Email'
                        : 'Phone Number',
                    hintText: _selectedMethod == ContactMethod.email
                        ? 'you@example.com'
                        : '+254 7XX XXX XXX',
                    prefixIcon: Icon(
                      _selectedMethod.icon,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                // ═══════════════════════════════════════════════
                // STEP 2: OTP Verification
                // ═══════════════════════════════════════════════

                // ── Success Message ──
                if (_successMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // ── Contact Display ──
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_selectedMethod.icon,
                            size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          _contactController.text.trim(),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _otpSent = false;
                              _error = null;
                              _successMessage = null;
                            });
                          },
                          child: Icon(Icons.edit_outlined,
                              size: 16, color: colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'via ${_selectedMethod.label}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── OTP Input (4 digits) ──
                Center(
                  child: Text(
                    'Enter verification code',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      width: 64,
                      height: 72,
                      margin: EdgeInsets.only(
                        left: index > 0 ? 12 : 0,
                      ),
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) =>
                            _onOtpDigitChanged(index, value),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // ── Resend OTP ──
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _resendOtp,
                    child: Text.rich(
                      TextSpan(
                        text: "Didn't receive the code? ",
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        children: [
                          TextSpan(
                            text: 'Resend',
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

              // ── Action Button ──
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading
                      ? null
                      : _otpSent ? _verifyOtp : _sendOtp,
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
                          _otpSent ? 'Verify & Continue' : 'Send OTP',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
