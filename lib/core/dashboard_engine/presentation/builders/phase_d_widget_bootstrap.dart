/// ============================================================
/// PHASE D — COMPREHENSIVE WIDGET REGISTRATION BOOTSTRAP
/// ============================================================
///
/// Central bootstrap point for ALL Phase D production widget registrations.
/// Bridges module descriptors → live widget builders → observability.
///
/// Workstreams:
///   1. Farm Management — 10 dashboard widgets with live providers
///   2. Marketplace — 5 dashboard widgets with live providers
///   3. Analytics — 4 dashboard widgets
///   4. Knowledge Link — 4 dashboard widgets
///   5. Extension Services — 4 dashboard widgets
///   6. Financing — 5 dashboard widgets
///
/// Each widget:
///   - Is registered with the enterprise WidgetRegistry
///   - Connects to a live Riverpod provider
///   - Wraps itself in ModuleErrorBoundary
///   - Reports timing to observability
///
/// Call this once at app startup AFTER bootstrapWidgetRegistrations().
/// ============================================================
library;

import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_widget_registration_bootstrap.dart';
import 'package:famhub_app/features/marketplace/presentation/widgets/marketplace_widget_registration.dart';

/// ============================================================
/// BOOTSTRAP ALL PHASE D WIDGET REGISTRATIONS
/// ============================================================
///
/// Called during app initialization after the legacy bootstrap.
/// Registers all Phase D live-data widget builders.
/// ============================================================
void bootstrapPhaseDWidgetRegistrations() {
  // ── Workstream 1: Farm Management ──
  bootstrapFarmWidgets();

  // ── Workstream 2: Marketplace ──
  bootstrapMarketplaceWidgets();

  // ── Future workstreams (when they have live providers) ──
  // bootstrapAnalyticsWidgets();    // Workstream 3
  // bootstrapKnowledgeWidgets();    // Workstream 4
  // bootstrapExtensionWidgets();    // Workstream 5
  // bootstrapFinancingWidgets();    // Workstream 6
}
