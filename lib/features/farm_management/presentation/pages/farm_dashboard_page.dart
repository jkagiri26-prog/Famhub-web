import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ============================================================
/// FARM MANAGEMENT PAGE (PRIMARY MODULE PAGE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/pages/ = page layer
///
/// ✅ Responsibilities:
///   - Primary module page for farm management
///   - Delegates rendering to the unified dashboard engine via
///     ModuleRuntimeDescriptor contributions
///   - Follows same page pattern as Marketplace, Analytics, etc.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Uses providers (never direct Supabase calls)
///   - Reusable widgets from presentation/widgets/
///   - Unified dashboard engine for cross-module dashboard
/// ============================================================

/// Primary module page for Farm Management.
///
/// This page is rendered by the unified dashboard engine based on
/// ModuleRuntimeDescriptor contributions. The actual dashboard widgets
/// (KPIs, activity timeline, production summary, etc.) are registered
/// via the WidgetRegistry in farm_widget_registration_bootstrap.dart
/// and composed by the DashboardEngine.
class FarmManagementPage extends ConsumerWidget {
  const FarmManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The unified dashboard engine (DashboardEngine) handles composition
    // of all registered widgets. This page acts as the entry point.
    // When DashboardEngine integration is active, this can delegate to:
    //   return const DashboardEnginePage(moduleKey: 'farm_management');
    //
    // For now, it renders a simple placeholder that the unified dashboard
    // engine will replace at runtime.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Management'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: const Center(
        child: Text('Farm Management Dashboard'),
      ),
    );
  }
}

/// @deprecated Use [FarmManagementPage] instead.
typedef FarmDashboardPage = FarmManagementPage;