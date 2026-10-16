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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Opens the assistant on the existing navigator so shell navigation,
/// breakpoints and routing behaviour are untouched.
void _openFarmerAdvisor(BuildContext context, WidgetRef ref, String route) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: false,
      builder: (_) => FarmerAdvisorPage(initialRoute: route),
    ),
  );
}
