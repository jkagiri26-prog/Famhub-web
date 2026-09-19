/// ============================================================
/// PROFILE PAGE — Personal identity (the authenticated person)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/profile/presentation/pages/ = profile pages
///
/// ✅ Responsibilities:
///   - Display the authenticated user's profile from the existing
///     SessionController/session state (single source of truth)
///   - Handle loading / loaded / missing / error states
///   - Show the canonical users.profiles fields (first/middle/last
///     name, phone + verification state, country, location)
///
/// ❌ Does NOT:
///   - Create a second profile model/provider
///   - Query users.profiles again when SessionController already has it
///   - Treat the auth UUID as the profile UUID
///   - Own entity/workspace/business identity (that is not personal)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/providers/session_country_provider.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/layouts/section_container_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';

/// Resolves display names for the location ids stored on the profile row.
///
/// The profile row keeps only `core.locations.id` references, so this is a
/// small read-only lookup keyed by the joined id set (stable family key).
/// It is NOT a profile provider — it only decorates the already-loaded
/// SessionController profile.
final _profileLocationNamesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, joinedIds) async {
  final ids = joinedIds
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList();
  if (ids.isEmpty) return const <String, String>{};

  final rows = await SupabaseService.instance
      .from('locations', schema: 'core')
      .select('id, name')
      .inFilter('id', ids);

  return <String, String>{
    for (final row in (rows as List))
      if (row is Map && row['id'] != null)
        row['id'] as String: (row['name'] ?? '').toString(),
  };
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  /// `users.profiles` location columns, in hierarchy order.
  static const List<String> locationColumns = [
    'level_2_location_id',
    'level_3_location_id',
    'level_4_location_id',
    'level_5_location_id',
    'level_6_location_id',
    'level_7_location_id',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return ResponsiveWrapper(
      child: Column(
        children: [
          const SizedBox(height: 12),

          /// HEADER
          const ModuleHeaderWidget(
            title: 'Profile',
            subtitle: 'Personal identity',
            trailingIcon: Icons.settings,
          ),

          const SizedBox(height: 20),

          /// PROFILE (state-driven)
          _ProfileBody(session: session),

          const SizedBox(height: 20),

          /// SIGN OUT
          SectionContainerWidget(
            child: TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content:
                        const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(sessionProvider.notifier).signOut();
                }
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Renders the correct profile body for the current session state.
class _ProfileBody extends StatelessWidget {
  final AppSession session;

  const _ProfileBody({required this.session});

  @override
  Widget build(BuildContext context) {
    final current = session;

    if (current is InitializingSession) {
      return const _StateCard(
        title: 'Loading profile',
        message: 'Fetching your profile…',
        loading: true,
      );
    }

    if (current is SessionFailure) {
      return _StateCard(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load your profile",
        message: current.message,
        isError: true,
      );
    }

    if (current is! AuthenticatedSession) {
      return const _StateCard(
        icon: Icons.lock_outline,
        title: 'Not signed in',
        message: 'Sign in to view your profile.',
      );
    }

    final profile = current.profile;
    if (!current.hasProfile || profile == null) {
      return const _StateCard(
        icon: Icons.person_off_outlined,
        title: 'No profile yet',
        message: 'Your personal profile has not been created yet.',
      );
    }

    return _LoadedProfile(
      session: current,
      profile: profile,
    );
  }
}

/// Loaded profile — reads only the authoritative SessionController profile
/// and decorates it with the country/location display names.
class _LoadedProfile extends ConsumerWidget {
  final AuthenticatedSession session;
  final Map<String, dynamic> profile;

  const _LoadedProfile({
    required this.session,
    required this.profile,
  });

  String _value(String key) => (profile[key] ?? '').toString().trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    final firstName = _value('first_name');
    final middleName = _value('middle_name');
    final lastName = _value('last_name');

    final fullName = [firstName, middleName, lastName]
        .where((part) => part.isNotEmpty)
        .join(' ');
    final displayName = fullName.isNotEmpty ? fullName : session.displayName;

    // Phone is tied to the authenticated account; prefer the profile row,
    // fall back to the auth user.
    final profilePhone = _value('phone');
    final phone = profilePhone.isNotEmpty
        ? profilePhone
        : (SupabaseService.instance.currentUser?.phone ?? '').trim();

    final phoneVerified = profile['is_phone_verified'] == true;

    // Country — authoritative session country provider.
    final country = ref.watch(sessionCountryProvider);
    final countryName = (country.countryName ?? '').trim();

    // Location — resolve names for the stored core.locations ids.
    final locationIds = <String>[
      for (final column in ProfilePage.locationColumns)
        if (_value(column).isNotEmpty) _value(column),
    ];
    final joinedIds = locationIds.join(',');
    final names = joinedIds.isEmpty
        ? const <String, String>{}
        : ref.watch(_profileLocationNamesProvider(joinedIds)).value ??
            const <String, String>{};
    final locationLabel = locationIds
        .map((id) => names[id] ?? '')
        .where((name) => name.isNotEmpty)
        .join(' › ');

    return Column(
      children: [
        /// IDENTITY CARD
        SectionContainerWidget(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: cs.primary.withValues(alpha: 0.1),
                child: Icon(Icons.person, size: 42, color: cs.primary),
              ),
              const SizedBox(height: 12),
              Text(
                displayName.isEmpty ? 'FAMHUB User' : displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (phone.isNotEmpty) ...[
                    Text(
                      phone,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    phoneVerified
                        ? Icons.verified
                        : Icons.error_outline,
                    size: 16,
                    color:
                        phoneVerified ? cs.primary : cs.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),

        /// PERSONAL INFORMATION
        const SectionHeaderWidget(title: 'Personal Information'),
        const SizedBox(height: 12),
        SectionContainerWidget(
          child: Column(
            children: [
              _ProfileFieldRow(label: 'First name', value: firstName),
              _ProfileFieldRow(label: 'Middle name', value: middleName),
              _ProfileFieldRow(label: 'Last name', value: lastName),
              _ProfileFieldRow(label: 'Phone', value: phone),
              _ProfileFieldRow(
                label: 'Phone status',
                value: phoneVerified ? 'Verified' : 'Not verified',
                valueColor: phoneVerified ? cs.primary : cs.error,
              ),
              _ProfileFieldRow(label: 'Country', value: countryName),
              _ProfileFieldRow(label: 'Location', value: locationLabel),
            ],
          ),
        ),
      ],
    );
  }
}

/// Simple label/value row used by the personal information card.
class _ProfileFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ProfileFieldRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: valueColor ?? cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty/loading/error placeholder card.
class _StateCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String message;
  final bool loading;
  final bool isError;

  const _StateCard({
    this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionContainerWidget(
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (loading)
            CircularProgressIndicator(color: cs.primary)
          else
            Icon(
              icon ?? Icons.person_outline,
              size: 40,
              color: isError ? cs.error : cs.primary,
            ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
