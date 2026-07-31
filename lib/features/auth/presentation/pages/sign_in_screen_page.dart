/// ============================================================
/// SIGN IN SCREEN — Phone OTP-only authentication
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/presentation/pages/ = page layer
///
/// ✅ Responsibilities:
///   - Phone-only OTP authentication for sign-in and sign-up
///   - No email, no WhatsApp — phone SMS OTP only
///   - Six-digit OTP verification
///   - Error display and loading state
///   - Confirms OTP was sent successfully
///
/// ✅ FLOW:
///   1. User enters phone number
///   2. OTP is sent via SMS (confirmed)
///   3. User enters 6-digit OTP
///   4. onAuthComplete is called on success
///
/// ❌ Does NOT:
///   - Know about routing
///   - Contain business logic
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:famhub_app/core/services/auth_service.dart';
import 'package:famhub_app/core/services/supabase_service.dart';

/// Country code data model from core.countries table
class _CountryCode {
  final String id;
  final String name;
  final String dialingCode;
  final String isoAlpha2;

  const _CountryCode({
    required this.id,
    required this.name,
    required this.dialingCode,
    required this.isoAlpha2,
  });

  /// Get the dialing code with + prefix
  String get dialingCodeWithPlus => '+$dialingCode';
}

/// Simple provider accessor for AuthService.
/// Avoids requiring Riverpod in this pure widget.
class _AuthServiceProvider {
  static AuthService? _instance;
  static AuthService get() {
    _instance ??= AuthService();
    return _instance!;
  }
}

class SignInScreenPage extends StatefulWidget {
  /// OTP flow: Called after OTP verification succeeds.
  /// Should return true on success, false on failure.
  final Future<bool> Function({
    required String contact,
    required String otp,
  })? onAuthenticate;

  /// Called when the user wants to go back.
  final VoidCallback onBack;

  /// Optional: message shown at the top (e.g., "Welcome Back" or "Create Account")
  final String title;

  /// Optional: subtitle shown below title
  final String subtitle;

  const SignInScreenPage({
    super.key,
    this.onAuthenticate,
    required this.onBack,
    this.title = 'Welcome to FAMHUB',
    this.subtitle = 'Enter your phone number to continue',
  });

  @override
  State<SignInScreenPage> createState() => _SignInScreenPageState();
}

class _SignInScreenPageState extends State<SignInScreenPage> {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _otpSent = false;
  bool _isLoading = false;
  bool _countriesLoading = true;
  String? _error;
  String? _successMessage;

  // Country code data
  List<_CountryCode> _countries = [];
  _CountryCode? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Load active countries from backend core.countries table.
  /// Auto-selects Kenya (KE) as default, falls back to first country.
  Future<void> _loadCountries() async {
    try {
      final supabase = SupabaseService.instance;
      final response = await supabase
          .from('countries')
          .select('id, name, dialing_code, iso_alpha2')
          .eq('is_active', true)
          .order('name');

      final countries = (response as List)
          .map((c) => _CountryCode(
                id: c['id'] as String,
                name: c['name'] as String,
                dialingCode: c['dialing_code'] as String,
                isoAlpha2: (c['iso_alpha2'] as String).trim(),
              ))
          .toList();

      if (!mounted) return;

      setState(() {
        _countries = countries;
        _countriesLoading = false;
        // Auto-select Kenya (+254) as default
        _selectedCountry = countries.cast<_CountryCode?>().firstWhere(
              (c) => c!.isoAlpha2 == 'KE',
              orElse: () => countries.isNotEmpty ? countries.first : null,
            );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _countriesLoading = false;
      });
      // Provide fallback countries if backend fetch fails
      _setFallbackCountries();
    }
  }

  /// Fallback country list when backend is unreachable
  void _setFallbackCountries() {
    _countries = [
      const _CountryCode(
        id: 'ke-fallback',
        name: 'Kenya',
        dialingCode: '254',
        isoAlpha2: 'KE',
      ),
      const _CountryCode(
        id: 'ug-fallback',
        name: 'Uganda',
        dialingCode: '256',
        isoAlpha2: 'UG',
      ),
      const _CountryCode(
        id: 'tz-fallback',
        name: 'Tanzania',
        dialingCode: '255',
        isoAlpha2: 'TZ',
      ),
      const _CountryCode(
        id: 'rw-fallback',
        name: 'Rwanda',
        dialingCode: '250',
        isoAlpha2: 'RW',
      ),
      const _CountryCode(
        id: 'et-fallback',
        name: 'Ethiopia',
        dialingCode: '251',
        isoAlpha2: 'ET',
      ),
      const _CountryCode(
        id: 'ng-fallback',
        name: 'Nigeria',
        dialingCode: '234',
        isoAlpha2: 'NG',
      ),
      const _CountryCode(
        id: 'gh-fallback',
        name: 'Ghana',
        dialingCode: '233',
        isoAlpha2: 'GH',
      ),
      const _CountryCode(
        id: 'za-fallback',
        name: 'South Africa',
        dialingCode: '27',
        isoAlpha2: 'ZA',
      ),
    ];
    _selectedCountry = _countries.firstWhere(
      (c) => c.isoAlpha2 == 'KE',
      orElse: () => _countries.first,
    );
  }

  /// Get full phone number with country code
  String get _fullPhoneNumber {
    if (_selectedCountry == null) return _phoneController.text.trim();
    final code = _selectedCountry!.dialingCode;
    final number = _phoneController.text.trim().replaceAll(' ', '');
    // Remove leading zeros from the local number
    final cleaned = number.startsWith('0') ? number.substring(1) : number;
    return '+$code$cleaned';
  }

  /// Send OTP via Supabase Auth (phone SMS only).
  /// Ensures OTP is sent successfully before proceeding.
  Future<void> _sendOtp() async {
    final phone = _fullPhoneNumber;
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your phone number');
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
      final result = await authService.sendOtp(phone: phone);

      if (!mounted) return;

      if (result.success && result.confirmed) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
          _successMessage = 'OTP sent successfully to your phone via SMS';
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
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the complete 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await widget.onAuthenticate!(
        contact: _fullPhoneNumber,
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
    if (value.length == 1 && index < 5) {
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

              if (!_otpSent) ...[
                // ═══════════════════════════════════════════════
                // STEP 1: Phone Number Input (No method selection)
                // ═══════════════════════════════════════════════

                // ── Phone Icon Header ──
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.phone_android_outlined,
                      size: 36,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Country Code Dropdown + Phone Input ──
                Text(
                  'Phone Number',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Country Code Dropdown ──
                    SizedBox(
                      width: 130,
                      child: _countriesLoading
                          ? DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              items: const [],
                              onChanged: null,
                              hint: const SizedBox(
                                width: 80,
                                child: Text('Loading...', overflow: TextOverflow.ellipsis),
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedCountry?.id,
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              items: _countries.map((country) {
                                return DropdownMenuItem<String>(
                                  value: country.id,
                                  child: Text(
                                    country.dialingCodeWithPlus,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedCountry = _countries.firstWhere(
                                      (c) => c.id == value,
                                    );
                                  });
                                }
                              },
                              selectedItemBuilder: (context) {
                                return _countries.map((country) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      country.dialingCodeWithPlus,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                    ),
                    const SizedBox(width: 12),
                    // ── Phone Number Input ──
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '7XX XXX XXX',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    'You will receive a 6-digit OTP via SMS',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
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

                                // ── Phone Display ──
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
                          Icon(Icons.phone_android_outlined,
                              size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            _fullPhoneNumber,
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
                      'via SMS',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),

                // ── OTP Input (6 digits) ──
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
                  children: List.generate(6, (index) {
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
