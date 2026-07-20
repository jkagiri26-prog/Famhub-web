/// ============================================================
/// FARM DASHBOARD PAGE (BACKWARD COMPATIBILITY WRAPPER)
/// ============================================================
///
/// ⚠️ DEPRECATED: Use farm_management_page.dart instead.
///
/// This file re-exports FarmManagementPage from the new location
/// for backward compatibility with existing imports.
///
/// All actual logic has moved to:
///   features/farm_management/presentation/pages/farm_management_page.dart
///
/// Routes reference this file via:
///   import '...farm_dashboard_page.dart' as farm;
///   farm.FarmManagementPage()
/// ============================================================

export 'farm_management_page.dart';
