/// ============================================================
/// FARM DASHBOARD PAGE (BACKWARD COMPATIBILITY WRAPPER)
/// ============================================================
///
/// ⚠️ DEPRECATED: Use farm_home_page.dart instead.
///
/// This file keeps legacy imports pointed at the official tabbed farm
/// workspace for backward compatibility.
///
/// The active farm workspace is:
///   features/farm_management/presentation/pages/farm_home_page.dart
///
/// Routes reference this file via:
///   import '...farm_dashboard_page.dart' as farm;
///   farm.FarmHomePage()
/// ============================================================
library;

export 'farm_home_page.dart';

/// Legacy name retained for callers that still construct the old page.
typedef FarmManagementPage = FarmHomePage;
