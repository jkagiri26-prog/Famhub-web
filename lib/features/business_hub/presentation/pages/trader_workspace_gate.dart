/// ============================================================
/// TRADER WORKSPACE GATE (FIRST-USE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/business_hub/presentation/pages/ = module pages
///
/// The Trader workspace entry point. It reads the AUTHORITATIVE active
/// context (`contextProvider` — the canonical context engine, never local
/// business selection) and resolves:
///
///   context loading                → "Loading your business..."
///   no active entity               → application error/context state
///   businessProfileId == null      → Create your business
///   businessProfileId != null      → normal Trader Dashboard
///
/// The Entity already exists. This gate NEVER creates an Entity, a Trader
/// workspace, or a Business Profile automatically — creation happens only
/// through the explicit Create Business form.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';

import 'business_hub_page.dart';
import 'create_business_page.dart';

class TraderWorkspaceGate extends ConsumerWidget {
  const TraderWorkspaceGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextState = ref.watch(contextProvider);

    // Preserve the existing loading behavior while the canonical context
    // resolves.
    if (contextState.isLoading) {
      return const ResponsiveWrapper(
        child: LoadingStateWidget(message: 'Loading your business...'),
      );
    }

    final entityId = contextState.entityId;
    if (entityId == null || entityId.isEmpty) {
      // No valid active Trader Entity — never fabricate or create one.
      if (contextState.isGuest) {
        return const ResponsiveWrapper(
          child: ErrorStateWidget(
            title: 'Sign in required',
            message: 'Sign in to set up and manage your business.',
          ),
        );
      }
      return ResponsiveWrapper(
        child: ErrorStateWidget(
          title: 'No active business entity',
          message:
              'We could not resolve an active business entity for '
              'your account. Please try again.',
          retryLabel: 'Retry',
          onRetry: () => ref.read(contextProvider.notifier).init(),
        ),
      );
    }

    // The authoritative gate: the active context carries the linked
    // commerce.business_profiles id (or null when onboarding is required).
    final businessProfileId = contextState.businessProfileId;
    if (businessProfileId == null || businessProfileId.isEmpty) {
      return const CreateBusinessPage();
    }

    return const BusinessHubPage();
  }
}
