/// ============================================================
/// CREATE PROFILE PAGE — First-time profile creation
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/profile/presentation/pages/ = profile pages
///
/// ✅ Responsibilities:
///   - Display ONLY: First Name, Country (read-only), Location Levels
///   - Hidden fields (phone, countryId) forwarded silently from OTP session
///   - Centered elevated card, responsive on desktop & mobile
///   - Retry / refresh when geography levels fail to load
///   - Save profile via sessionProvider.createProfile
///
/// ❌ Does NOT:
///   - Display phone, country code, or other hidden payload fields
///   - Fetch backend data directly
///   - Hardcode location level names
/// ============================================================
library famhub_app.features.profile.presentation.pages.create_profile_page;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/session/providers/session_country_provider.dart';
import 'package:famhub_app/features/profile/application/providers/profile_location_provider.dart';
import 'package:famhub_app/features/profile/presentation/widgets/dynamic_location_fields.dart';
import 'package:famhub_app/features/auth/domain/models/otp_session.dart';
import 'package:famhub_app/features/auth/infrastructure/services/otp_session_storage.dart';

class CreateProfilePage extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const CreateProfilePage({super.key, required this.onComplete});

  @override
  ConsumerState<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends ConsumerState<CreateProfilePage> {
  final _firstNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _error;

  // ── Hidden payload (resolved from OTP session, never displayed) ──
  String? _phone;
  String? _countryId;

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onFormChanged);
    _loadHiddenPayload();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  /// Load phone and countryId from persisted OTP session.
  /// These are silently forwarded to the backend; never shown in the UI.
  Future<void> _loadHiddenPayload() async {
    final session = await OtpSessionStorage.loadSession();
    if (!mounted) return;
    setState(() {
      _phone = session?.phoneNumber;
      _countryId = session?.countryId;
    });
  }

  bool get _canSubmit =>
      _firstNameController.text.trim().length >= 2 && !_isSaving;

  Future<void> _createProfile() async {
    if (_phone == null || _phone!.isEmpty ||
        _countryId == null || _countryId!.isEmpty) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final entries =
        ref.read(profileLocationProvider.notifier).selectedEntries;

    final success = await ref.read(sessionProvider.notifier).createProfile(
          firstName: _firstNameController.text.trim(),
          countryId: _countryId!,
          phone: _phone!,
          locationLevels: entries,
        );

    if (!mounted) return;
    if (success) {
      widget.onComplete();
    } else {
      setState(() {
        _isSaving = false;
        _error = 'Failed to create profile. Please try again.';
      });
    }
  }

  /// Retry loading geography levels (bound to the retry button).
  void _retryLevels() {
    if (_countryId == null) return;
    ref.read(profileLocationProvider.notifier).refresh(_countryId!);
  }

  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch country for display name only
    final countryState = ref.watch(sessionCountryProvider);

    // Init location hierarchy once we know the country ID
    if (_countryId != null) {
      ref.watch(profileLocationInitProvider(_countryId!));
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.06),
              colorScheme.primary.withValues(alpha: 0.02),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 8,
                  shadowColor:
                      colorScheme.primary.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  color: colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header Icon ──
                          Center(
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.primary
                                        .withValues(alpha: 0.7),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                  Icons.person_add_rounded,
                                  size: 30,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Title ──
                          Center(
                            child: Text(
                              'Create Your Profile',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Tell us a bit about yourself.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── First Name * ──
                          _sectionLabel(theme, 'First Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _firstNameController,
                            textCapitalization:
                                TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. Samuel',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color:
                                    colorScheme.onSurfaceVariant,
                              ),
                              prefixIcon: Icon(
                                  Icons.person_outline,
                                  color: colorScheme.primary,
                                  size: 20),
                              filled: true,
                              fillColor: colorScheme
                                  .surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 1.5),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                            ),
                            validator: (v) {
                              if (v == null ||
                                  v.trim().length < 2) {
                                return 'Enter at least 2 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // ── LOCATION HEADING (umbrella for both country + levels) ──
                          _sectionLabel(theme, 'Location'),
                          const SizedBox(height: 10),

                          // ── Country (read-only, from session) ──
                          _buildCountryReadOnly(
                              colorScheme, countryState),
                          const SizedBox(height: 20),

                          // ── Dynamic Location Levels (country skipped) ──
                          if (_countryId != null)
                            DynamicLocationFields(
                              onRetry: _retryLevels,
                              skipCountryLevel: true,
                            )
                          else
                            const _InlineLoader(
                                label:
                                    'Loading location levels…'),
                          const SizedBox(height: 4),

                          // ── Error banner ──
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _errorBanner(colorScheme),
                          ],

                          const SizedBox(height: 28),

                          // ── Submit button ──
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed:
                                  _canSubmit ? _createProfile : null,
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    colorScheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                                elevation: 2,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Create Profile',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight:
                                            FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  Widget _sectionLabel(ThemeData theme, String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCountryReadOnly(
    ColorScheme colorScheme,
    SessionCountryState countryState,
  ) {
    if (countryState.isLoading) {
      return const _InlineLoader(label: 'Loading country…');
    }

    final country = countryState.country;
    final name = country?.name ?? 'Resolving from session…';
    final flag = country?.isoAlpha2 ?? '';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.public_outlined,
                size: 19, color: colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Country (from your phone number)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  flag.isNotEmpty ? '$flag  $name' : name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle,
              size: 18, color: colorScheme.primary),
        ],
      ),
    );
  }

  Widget _errorBanner(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: colorScheme.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.inter(
                  color: colorScheme.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small reusable inline loading placeholder used inside the card.
class _InlineLoader extends StatelessWidget {
  final String label;
  const _InlineLoader({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}