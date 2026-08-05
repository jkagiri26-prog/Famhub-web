/// ============================================================
/// SESSION COUNTRY PROVIDER — Single source of truth for country
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/session/providers/ = session management layer
///
/// ✅ Responsibilities:
///   - Own the authenticated user's country from OTP session
///   - Persist country in session storage
///   - Expose current country (id, name, iso code, dialing code)
///   - Refresh on session changes
///   - Cache country information
///   - Single source of truth for country across the app
///
/// ❌ Does NOT:
///   - Determine country from location APIs
///   - Know about geography levels or locations
///   - Contain UI logic
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/auth/domain/models/otp_session.dart';
import 'package:famhub_app/features/auth/infrastructure/services/otp_session_storage.dart';
import 'package:famhub_app/core/services/supabase_service.dart';

/// ────────────────────────────────────────────────────────────
/// Country model derived from core.countries
/// ────────────────────────────────────────────────────────────
class SessionCountry {
  final String id;
  final String name;
  final String isoAlpha2;
  final String dialingCode;

  const SessionCountry({
    required this.id,
    required this.name,
    required this.isoAlpha2,
    required this.dialingCode,
  });

  String get dialingCodeWithPlus =>
      dialingCode.startsWith('+') ? dialingCode : '+$dialingCode';
}

/// ────────────────────────────────────────────────────────────
/// State class
/// ────────────────────────────────────────────────────────────
class SessionCountryState {
  final SessionCountry? country;
  final bool isLoading;
  final String? error;

  const SessionCountryState({
    this.country,
    this.isLoading = false,
    this.error,
  });

  SessionCountryState copyWith({
    SessionCountry? country,
    bool? isLoading,
    String? error,
    bool clearCountry = false,
    bool clearError = false,
  }) {
    return SessionCountryState(
      country: clearCountry ? null : country ?? this.country,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }

  String? get countryId => country?.id;
  String? get countryName => country?.name;
  String? get phoneCode => country?.dialingCode;
}

/// ────────────────────────────────────────────────────────────
/// Controller
/// ────────────────────────────────────────────────────────────
class SessionCountryController extends Notifier<SessionCountryState> {
  @override
  SessionCountryState build() {
    // Eagerly begin initialization so country is available ASAP.
    Future.microtask(() => initialize());
    return const SessionCountryState(isLoading: true);
  }

  /// ── Initialize: load country from persisted OTP session ──
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await OtpSessionStorage.loadSession();

      if (session?.countryId != null) {
        final c = session!;
        state = SessionCountryState(
          country: SessionCountry(
            id: c.countryId!,
            name: c.countryName ?? '',
            isoAlpha2: c.countryIsoAlpha2 ?? '',
            dialingCode: c.dialingCode ?? '',
          ),
          isLoading: false,
        );

        // Enrich with full country metadata from backend
        await _enrichCountry(c.countryId!);
      } else {
        await _loadFromProfile();
      }
    } catch (_) {
      state = const SessionCountryState(
        isLoading: false,
        error: 'Failed to load country',
      );
    }
  }

  /// ── Enrich with backend data ──
  Future<void> _enrichCountry(String countryId) async {
    try {
      final supabase = SupabaseService.instance;
      final row = await supabase
          .from('countries', schema: 'core')
          .select('id, name, iso_alpha2, dialing_code')
          .eq('id', countryId)
          .maybeSingle();

      if (row != null) {
        state = SessionCountryState(
          country: SessionCountry(
            id: row['id'] as String,
            name: row['name'] as String,
            isoAlpha2: row['iso_alpha2'] as String,
            dialingCode: row['dialing_code'] as String,
          ),
          isLoading: false,
        );
      }
    } catch (_) {
      // Keep the current lightweight session data
    }
  }

  /// ── Fallback: load from profiles table ──
  Future<void> _loadFromProfile() async {
    try {
      final supabase = SupabaseService.instance;
      final userId = supabase.currentUserId;
      if (userId == null) {
        state = const SessionCountryState(isLoading: false);
        return;
      }

      final profile = await supabase
          .from('profiles', schema: 'users')
          .select('country_id, countries!inner(id, name, iso_alpha2, dialing_code)')
          .eq('auth_user_id', userId)
          .maybeSingle();

      if (profile != null && profile['country_id'] != null) {
        final c = profile['countries'] as Map<String, dynamic>?;
        state = SessionCountryState(
          country: SessionCountry(
            id: profile['country_id'] as String,
            name: c?['name'] as String? ?? '',
            isoAlpha2: c?['iso_alpha2'] as String? ?? '',
            dialingCode: c?['dialing_code'] as String? ?? '',
          ),
          isLoading: false,
        );
      } else {
        state = const SessionCountryState(isLoading: false);
      }
    } catch (_) {
      state = const SessionCountryState(isLoading: false);
    }
  }

  /// ── Refresh ──
  Future<void> refresh() async {
    await initialize();
  }

  /// ── Clear (e.g. on sign-out) ──
  void clear() {
    state = const SessionCountryState();
  }
}

/// ────────────────────────────────────────────────────────────
/// Providers
/// ────────────────────────────────────────────────────────────

/// Full country state.
final sessionCountryProvider =
    NotifierProvider<SessionCountryController, SessionCountryState>(
  SessionCountryController.new,
);

/// Just the country ID — convenient for dependent providers.
final sessionCountryIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionCountryProvider).countryId;
});

/// Whether the country has been fully loaded.
final isCountryLoadedProvider = Provider<bool>((ref) {
  final s = ref.watch(sessionCountryProvider);
  return !s.isLoading && s.country != null;
});