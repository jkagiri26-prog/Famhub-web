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
///   - Loads country list from core.countries (never hardcoded fallbacks)
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
///   - Use hardcoded/fake country IDs (always from backend)
/// ============================================================
library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:famhub_app/core/services/auth_service.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/auth/domain/models/otp_session.dart';
import 'package:famhub_app/features/auth/infrastructure/services/otp_session_storage.dart';

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
  final Future<bool> Function({required String contact, required String otp})?
  onAuthenticate;

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
  bool _countriesError = false;
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
  /// If the backend call fails, shows an error with a retry option —
  /// never uses hardcoded fallback IDs.
  Future<void> _loadCountries() async {
    try {
      final supabase = SupabaseService.instance;
      final response = await supabase
          .from('countries', schema: 'core')
          .select('id, name, dialing_code, iso_alpha2')
          .eq('is_active', true)
          .order('name');

      final countries = (response as List)
          .map(
            (c) => _CountryCode(
              id: c['id'] as String,
              name: c['name'] as String,
              dialingCode: c['dialing_code'] as String,
              isoAlpha2: (c['iso_alpha2'] as String).trim(),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _countries = countries;
        _countriesLoading = false;
        _countriesError = false;

        // Auto-select Kenya (+254) as default
        _selectedCountry = countries.cast<_CountryCode?>().firstWhere(
          (c) => c!.isoAlpha2 == 'KE',
          orElse: () => countries.isNotEmpty ? countries.first : null,
        );
      });
    } catch (e) {
      debugPrint('Failed to load countries from core.countries: $e');
      if (!mounted) return;
      setState(() {
        _countriesLoading = false;
        _countriesError = true;
      });
    }
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
        // ── Persist OTP session with country context ──
        // The profile creation screen reads this to display the
        // user's country as read-only (backend contract).
        final otpSession = OtpSession(
          phoneNumber: phone,
          verificationId: null,
          countryId: _selectedCountry?.id,
          countryName: _selectedCountry?.name,
          countryIsoAlpha2: _selectedCountry?.isoAlpha2,
        );
        await OtpSessionStorage.saveSession(otpSession);

        if (!mounted) return;

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

  /// Handle digit input for OTP fields (supports paste and auto-advance)
  void _handleOtpChanged(int index, String value) {
    if (value.isEmpty) return;

    // ── Paste support: distribute multiple digits across consecutive fields ──
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '').split('');
      final count = digits.length;

      for (var i = 0; i < count && index + i < 6; i++) {
        _otpControllers[index + i].text = digits[i];
      }
      // Ensure the active field shows only its single digit
      _otpControllers[index].text = digits.isNotEmpty ? digits.first : '';

      // Advance focus to the next unfilled field
      final nextIndex = index + count;
      if (nextIndex < 6) {
        _otpFocusNodes[nextIndex].requestFocus();
      } else {
        _otpFocusNodes[5].unfocus();
      }
      return;
    }

    // ── Single digit typed: auto-advance to the next field ──
    if (index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
  }

  /// Build a single responsive OTP digit field.
  Widget _buildOtpField(
    int index, {
    required double width,
    required double height,
    required double marginLeft,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = _otpControllers[index];
    final focusNode = _otpFocusNodes[index];

    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.only(left: marginLeft),
      child: Focus(
        onKeyEvent: (node, event) {
          // Move to the previous field when backspace is pressed on an empty field
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty &&
              index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Semantics(
          label: 'OTP digit ${index + 1} of 6',
          textField: true,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            // Allow multiple digits so pasting the full 6-digit OTP works;
            // _handleOtpChanged immediately distributes them to separate fields.
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) => _handleOtpChanged(index, value),
          ),
        ),
      ),
    );
  }

  /// Responsive OTP row: always keeps all 6 boxes on a single line.
  Widget _buildOtpRow() {
    const double spacing = 6;
    const double maxBoxWidth = 46;
    const double boxHeight = 54;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // Box width adapts to the available width while respecting the
        // 40–46 px target range on normal devices. On ultra-narrow screens
        // it shrinks slightly instead of overflowing or wrapping.
        final computedWidth = (availableWidth - spacing * 5) / 6;
        final boxWidth = math.min(computedWidth, maxBoxWidth);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return _buildOtpField(
              index,
              width: boxWidth,
              height: boxHeight,
              marginLeft: index > 0 ? spacing : 0,
            );
          }),
        );
      },
    );
  }

  /// Build the country code dropdown section.
  /// Shows loading spinner, error with retry, or the populated dropdown.
  Widget _buildCountryDropdown(ColorScheme colorScheme) {
    if (_countriesLoading) {
      return SizedBox(
        width: 130,
        child: DropdownButtonFormField<String>(
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
            child: Text(
              'Loading...',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    if (_countriesError) {
      return SizedBox(
        width: 130,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _countriesLoading = true;
              _countriesError = false;
            });
            _loadCountries();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.error),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.refresh, size: 16, color: colorScheme.error),
                const SizedBox(width: 4),
                Text(
                  'Retry',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 130,
      child: DropdownButtonFormField<String>(
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
                country.dialingCode,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  if (_error != null) const SizedBox(height: 16),
                  if (_successMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: colorScheme.onPrimaryContainer),
                      ),
                    ),
                  if (_successMessage != null) const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildCountryDropdown(colorScheme),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            hintText: 'Phone number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading || _countriesLoading || _countriesError
                          ? null
                          : _otpSent
                              ? _resendOtp
                              : _sendOtp,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_otpSent ? Icons.refresh : Icons.send_rounded),
                      label: Text(
                        _otpSent ? 'Resend OTP' : 'Send OTP',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Enter the 6-digit code sent to your phone',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildOtpRow(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Verify OTP'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: _isLoading ? null : _resendOtp,
                        child: const Text('Resend code'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}