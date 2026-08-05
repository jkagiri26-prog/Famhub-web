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

  String get dialingCodeWithPlus => '+${dialingCode.replaceFirst(RegExp(r'^\+'), '')}';
}

/// Simple provider accessor for AuthService.
class _AuthServiceProvider {
  static AuthService? _instance;
  static AuthService get() {
    _instance ??= AuthService();
    return _instance!;
  }
}

class SignInScreenPage extends StatefulWidget {
  final Future<bool> Function({required String contact, required String otp})?
      onAuthenticate;
  final VoidCallback onBack;
  final String title;
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
  String? _success;

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
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════
  // DATA
  // ════════════════════════════════════════════

  Future<void> _loadCountries() async {
    try {
      final supabase = SupabaseService.instance;
      final response = await supabase
          .from('countries', schema: 'core')
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
        _countriesError = false;
        _selectedCountry = countries.cast<_CountryCode?>().firstWhere(
              (c) => c!.isoAlpha2 == 'KE',
              orElse: () => countries.isNotEmpty ? countries.first : null,
            );
      });
    } catch (e) {
      debugPrint('Failed to load countries: $e');
      if (!mounted) return;
      setState(() { _countriesLoading = false; _countriesError = true; });
    }
  }

    String get _fullPhoneNumber {
    if (_selectedCountry == null) return _phoneController.text.trim();
    final code = _selectedCountry!.dialingCode.replaceFirst(RegExp(r'^\+'), '');
    final number = _phoneController.text.trim().replaceAll(' ', '');
    final cleaned = number.startsWith('0') ? number.substring(1) : number;
    return '+$code$cleaned';
  }

  // ════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════

  Future<void> _sendOtp() async {
    final phone = _fullPhoneNumber;
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return;
    }
    setState(() { _isLoading = true; _error = null; _success = null; });

    try {
      final result = await _AuthServiceProvider.get().sendOtp(phone: phone);
      if (!mounted) return;

      if (result.success && result.confirmed) {
        await OtpSessionStorage.saveSession(OtpSession(
          phoneNumber: phone,
          countryId: _selectedCountry?.id,
          countryName: _selectedCountry?.name,
          countryIsoAlpha2: _selectedCountry?.isoAlpha2,
          dialingCode: _selectedCountry?.dialingCode,
        ));
        if (!mounted) return;
        setState(() {
          _otpSent = true;
          _isLoading = false;
          _success = 'OTP sent successfully';
        });
        Future.delayed(const Duration(milliseconds: 100),
            () => _otpFocusNodes[0].requestFocus());
      } else {
        setState(() {
          _isLoading = false;
          _error = result.error ?? 'Failed to send OTP. Please try again.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Network error. Please check your connection and try again.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _error = 'Please enter the complete 6-digit code');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final success = await widget.onAuthenticate!(
          contact: _fullPhoneNumber, otp: otp);
      if (!mounted) return;
      if (!success) {
        setState(() { _error = 'Invalid OTP. Please try again.'; _isLoading = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Verification failed.'; });
    }
  }

  Future<void> _resendOtp() async {
    setState(() { _error = null; _success = null; });
    for (final c in _otpControllers) c.clear();
    await _sendOtp();
  }

  void _handleOtpChanged(int index, String value) {
    if (value.isEmpty) return;
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '').split('');
      for (var i = 0; i < digits.length && index + i < 6; i++) {
        _otpControllers[index + i].text = digits[i];
      }
      _otpControllers[index].text = digits.isNotEmpty ? digits.first : '';
      final nextIndex = index + digits.length;
      if (nextIndex < 6) {
        _otpFocusNodes[nextIndex].requestFocus();
      } else {
        _otpFocusNodes[5].unfocus();
      }
      return;
    }
    if (index < 5) _otpFocusNodes[index + 1].requestFocus();
  }

  // ════════════════════════════════════════════
  // BUILDERS
  // ════════════════════════════════════════════

  Widget _otpBox(int index, {required double size, required double gap}) {
    final cs = Theme.of(context).colorScheme;
    final ctrl = _otpControllers[index];
    final node = _otpFocusNodes[index];

    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.only(left: index > 0 ? gap : 0),
      child: Focus(
        onKeyEvent: (n, e) {
          if (e is KeyDownEvent &&
              e.logicalKey == LogicalKeyboardKey.backspace &&
              ctrl.text.isEmpty &&
              index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: ctrl,
          focusNode: node,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (v) => _handleOtpChanged(index, v),
        ),
      ),
    );
  }

  Widget _otpRow() {
    const double gap = 8;
    const double maxSize = 52;
    return LayoutBuilder(builder: (_, constraints) {
      final size = math.min((constraints.maxWidth - gap * 5) / 6, maxSize);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(6, (i) => _otpBox(i, size: size, gap: gap)),
      );
    });
  }

  Widget _countryPicker() {
    final cs = Theme.of(context).colorScheme;

    if (_countriesLoading) {
      return SizedBox(
        width: 130,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_countriesError) {
      return SizedBox(
        width: 130,
        child: GestureDetector(
          onTap: () {
            setState(() { _countriesLoading = true; _countriesError = false; });
            _loadCountries();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: cs.error),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.refresh, size: 16, color: cs.error),
                const SizedBox(width: 4),
                Text('Retry',
                    style: TextStyle(color: cs.error, fontWeight: FontWeight.w600, fontSize: 13)),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: _countries
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.dialingCodeWithPlus, style: const TextStyle(fontWeight: FontWeight.w600))))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            setState(() => _selectedCountry = _countries.firstWhere((c) => c.id == v));
          }
        },
        selectedItemBuilder: (_) => _countries
            .map((c) => Align(alignment: Alignment.centerLeft, child: Text(c.dialingCode, style: const TextStyle(fontWeight: FontWeight.w600))))
            .toList(),
      ),
    );
  }

  Widget _banner(String msg, {required bool isError}) {
    final cs = Theme.of(context).colorScheme;
    final bg = isError ? cs.error.withValues(alpha: 0.08) : cs.primary.withValues(alpha: 0.08);
    final fg = isError ? cs.error : cs.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: TextStyle(fontSize: 13, color: fg))),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Back arrow (top-left, self-aligns) ──
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── PREMIUM CARD ──
                  Card(
                    elevation: 2,
                    shadowColor: cs.shadow.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    color: cs.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Logo / Icon ──
                          Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.lock_outline_rounded, size: 28, color: cs.primary),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Title ──
                          Center(
                            child: Text(widget.title,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(widget.subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Messages ──
                          if (_error != null) ...[_banner(_error!, isError: true), const SizedBox(height: 14)],
                          if (_success != null) ...[_banner(_success!, isError: false), const SizedBox(height: 14)],

                          // ── Phone row ──
                          Row(
                            children: [
                              _countryPicker(),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    hintText: 'Phone number',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // ── Primary button ──
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: _isLoading || _countriesLoading || _countriesError
                                  ? null
                                  : _otpSent ? _resendOtp : _sendOtp,
                              child: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_otpSent ? Icons.refresh_rounded : Icons.send_rounded, size: 18),
                                        const SizedBox(width: 8),
                                        Text(_otpSent ? 'Resend OTP' : 'Send OTP', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                            ),
                          ),

                          // ── OTP section ──
                          if (_otpSent) ...[
                            const SizedBox(height: 28),
                            Center(
                              child: Text('Enter the 6‑digit code',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _otpRow(),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _verifyOtp,
                                child: _isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('Verify OTP', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}