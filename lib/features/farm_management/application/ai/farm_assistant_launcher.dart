/// ============================================================
/// FARM ASSISTANT LAUNCHER — shell wiring for the FAMHUB AI assistant
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/ai/ = AI application layer
///
/// ✅ Responsibilities:
///   - Register the agricultural assistant with the core shell seam for the
///     workspaces whose first capability is agricultural advice
///   - Push the assistant page on the existing navigator
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - No new route, tab, navigation entry or destination
///   - The shell never imports this file — it only sees the registry
///   - A later Trader / Marketplace assistant registers here too, keyed by
///     its own workspace type
///
/// ❌ Does NOT:
///   - Register anything for workspaces that have no assistant yet (those
///     get an honest "not available" message from the shell)
/// ============================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/navigation/resize_optimizer.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_launcher_registry.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/farmer_advisor_page.dart';

/// Workspace types that currently have the agricultural assistant.
///
/// `farmer` is the Farm Management workspace. `service_provider` is the
/// Extension Services workspace, whose home is `/extension`.
const List<String> kAgriculturalAssistantWorkspaceTypes = <String>[
  'farmer',
  'service_provider',
];

/// Registers the agricultural assistant. Safe to call repeatedly.
void registerFarmAssistantLauncher() {
  for (final String workspaceType in kAgriculturalAssistantWorkspaceTypes) {
    AssistantLauncherRegistry.register(workspaceType, _openFarmerAdvisor);
  }
}

/// Opens the assistant.
///
/// Desktop/ultraWide: a right-side slide-over panel that leaves the current
/// page in place and can be dismissed with its close button or the barrier.
/// Tablet/mobile: the existing full-page push.
void _openFarmerAdvisor(BuildContext context, WidgetRef ref, String route) {
  final String deviceType = ref.read(breakpointProvider).deviceType;
  final bool isDesktop =
      deviceType == 'desktop' || deviceType == 'ultraWide';

  if (isDesktop) {
    _showDesktopAssistantPanel(context, route);
    return;
  }

  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: false,
      builder: (_) => FarmerAdvisorPage(initialRoute: route),
    ),
  );
}

/// Right-side, non-full-page assistant for desktop and ultra-wide.
void _showDesktopAssistantPanel(BuildContext context, String route) {
  final double screenWidth = MediaQuery.sizeOf(context).width;
  final double panelWidth =
      math.min(460.0, math.max(380.0, screenWidth * 0.38));

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close AI assistant',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 16,
          clipBehavior: Clip.antiAlias,
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(20)),
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: FarmerAdvisorPage(initialRoute: route, isPanel: true),
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
