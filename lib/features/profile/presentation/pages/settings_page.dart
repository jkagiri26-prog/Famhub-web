/// ============================================================
/// SETTINGS PAGE — Personal preferences for the authenticated user
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/profile/presentation/pages/ = profile pages
///
/// ✅ Responsibilities:
///   - Render the canonical Settings state (loading/loaded/saving/error)
///   - Appearance: theme wired to the existing theme provider
///   - Language: displays the persisted supported language (read-only)
///   - Account: link to the existing Profile page
///   - Account action: existing canonical sign-out
///
/// ❌ Does NOT:
///   - Contain personal profile editing (that is the Profile page)
///   - Contain entity/workspace/business settings
///   - Invent notification controls (no notification system exists yet)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/router/route_names.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/features/settings/application/providers/settings_provider.dart';
import 'package:famhub_app/features/settings/domain/models/user_settings.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/layouts/section_container_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/headers/section_header_widget.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // Ensure the canonical state is loaded when the page opens. The
    // controller keeps a single state shared with the rest of the app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(settingsProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);

    return ResponsiveWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          /// HEADER
          const ModuleHeaderWidget(
            title: 'Settings',
            subtitle: 'Preferences • Appearance • Language',
          ),

          const SizedBox(height: 20),

          if (state.isLoading && state.settings == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.settings == null)
            _ErrorCard(
              message: state.error ??
                  'We could not load your settings. Please try again.',
              onRetry: () => ref.read(settingsProvider.notifier).load(),
            )
          else ...[
            /// ACCOUNT
            const SectionHeaderWidget(title: 'Account'),
            const SizedBox(height: 12),
            SectionContainerWidget(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                subtitle: const Text('Personal information'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(AppRoutes.profile),
              ),
            ),

            const SizedBox(height: 20),

            /// APPEARANCE
            const SectionHeaderWidget(title: 'Appearance'),
            const SizedBox(height: 12),
            SectionContainerWidget(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.brightness_6_outlined),
                      const SizedBox(width: 12),
                      const Text('Theme'),
                      const Spacer(),
                      if (state.isSaving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AppThemePreference>(
                      showSelectedIcon: false,
                      segments: [
                        for (final preference
                            in AppThemePreference.values)
                          ButtonSegment<AppThemePreference>(
                            value: preference,
                            label: Text(preference.label),
                          ),
                      ],
                      selected: {
                        state.settings!.theme,
                      },
                      onSelectionChanged: (selection) {
                        ref
                            .read(settingsProvider.notifier)
                            .setTheme(selection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// LANGUAGE
            const SectionHeaderWidget(title: 'Language'),
            const SizedBox(height: 12),
            SectionContainerWidget(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language),
                title: const Text('Language'),
                subtitle: Text(
                  _languageLabel(state.settings!.language),
                ),
              ),
            ),

            /// SAVE ERROR
            if (state.error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(
                message: state.error!,
                onDismiss: () =>
                    ref.read(settingsProvider.notifier).clearError(),
              ),
            ],

            const SizedBox(height: 20),

            /// ACCOUNT ACTION
            SectionContainerWidget(
              child: TextButton(
                onPressed: () => _confirmSignOut(context),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'en':
        return 'English (en)';
      default:
        return code.isEmpty ? '—' : code.toUpperCase();
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
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
      // Existing canonical auth/session sign-out.
      await ref.read(sessionProvider.notifier).signOut();
    }
  }
}

/// Retry card shown when settings could not be loaded at all.
class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionContainerWidget(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Icon(Icons.cloud_off_outlined, size: 40, color: cs.error),
          const SizedBox(height: 12),
          const Text(
            "Couldn't load settings",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Inline banner shown when a save fails (settings still displayed).
class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.error, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close, size: 16, color: cs.error),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
