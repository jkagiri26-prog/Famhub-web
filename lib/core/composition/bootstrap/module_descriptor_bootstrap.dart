/// ============================================================
/// MODULE DESCRIPTOR BOOTSTRAP (CENTRAL REGISTRATION)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/bootstrap/ = composition bootstrapping
///
/// ✅ Responsibilities:
///   - Register all module runtime descriptors at startup
///   - Single entry point for descriptor registration
///   - Called once during app initialization
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Each module registers its own descriptor
///   - No hardcoded module-specific logic here
///   - The composition engine uses descriptors, not hardcoded references
/// ============================================================
library;

import 'package:famhub_app/core/composition/domain/models/module_descriptor_registry.dart';

// ── Module Descriptor Imports ──
import 'package:famhub_app/features/marketplace/module/marketplace_runtime_descriptor.dart';
import 'package:famhub_app/features/farm_management/module/farm_management_runtime_descriptor.dart';
import 'package:famhub_app/features/financing/module/financing_runtime_descriptor.dart';
import 'package:famhub_app/features/knowledge_link/module/knowledge_link_runtime_descriptor.dart';
import 'package:famhub_app/features/traceability/module/traceability_runtime_descriptor.dart';
import 'package:famhub_app/features/extension_services/module/extension_services_runtime_descriptor.dart';

// ── Phase C: Remaining module descriptors ──
import 'package:famhub_app/features/logistics/module/logistics_runtime_descriptor.dart';
import 'package:famhub_app/features/carbon_credit/module/carbon_credit_runtime_descriptor.dart';
import 'package:famhub_app/features/agribusiness/module/agribusiness_runtime_descriptor.dart';
import 'package:famhub_app/features/opportunities/module/opportunities_runtime_descriptor.dart';
import 'package:famhub_app/features/agri_connect/module/agri_connect_runtime_descriptor.dart';
import 'package:famhub_app/features/agri_tech_lab/module/agri_tech_lab_runtime_descriptor.dart';
import 'package:famhub_app/features/refferal_hub/module/referral_hub_runtime_descriptor.dart';
import 'package:famhub_app/features/analytics/module/analytics_runtime_descriptor.dart';
import 'package:famhub_app/features/admin_console/module/admin_console_runtime_descriptor.dart';
import 'package:famhub_app/features/profile/module/profile_runtime_descriptor.dart';

/// ============================================================
/// BOOTSTRAP ALL MODULE DESCRIPTORS
/// ============================================================
///
/// Call this once during app initialization (in main.dart or bootstrap).
/// Registers every module's runtime descriptor with the central registry.
/// ============================================================
void bootstrapModuleDescriptors() {
  // ── Core Feature Modules (Phase 1) ──
  ModuleDescriptorRegistry.register(createMarketplaceDescriptor());
  ModuleDescriptorRegistry.register(createFarmManagementDescriptor());
  ModuleDescriptorRegistry.register(createFinancingDescriptor());
  ModuleDescriptorRegistry.register(createKnowledgeLinkDescriptor());
  ModuleDescriptorRegistry.register(createTraceabilityDescriptor());
  ModuleDescriptorRegistry.register(createExtensionServicesDescriptor());

  // ── Phase C: All remaining feature modules ──
  ModuleDescriptorRegistry.register(createLogisticsDescriptor());
  ModuleDescriptorRegistry.register(createCarbonCreditDescriptor());
  ModuleDescriptorRegistry.register(createAgribusinessDescriptor());
  ModuleDescriptorRegistry.register(createOpportunitiesDescriptor());
  ModuleDescriptorRegistry.register(createAgriConnectDescriptor());
  ModuleDescriptorRegistry.register(createAgriTechLabDescriptor());
  ModuleDescriptorRegistry.register(createReferralHubDescriptor());
  ModuleDescriptorRegistry.register(createAnalyticsDescriptor());
  ModuleDescriptorRegistry.register(createAdminConsoleDescriptor());
  ModuleDescriptorRegistry.register(createProfileDescriptor());
}

