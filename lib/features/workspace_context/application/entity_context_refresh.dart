/// ============================================================
/// ENTITY-CONTEXT REFRESH
/// ============================================================
///
/// After a successful workspace/entity context activation, refresh ONLY
/// the providers whose data is scoped to the active entity/business.
///
/// ✅ Invalidated (entity/business scoped):
///   - Business Hub entities + active business selection
///   - Marketplace seller/owned listings + eligible stock
///   - Farm selection + lifecycle + dashboard
///   - Access policy (role/entity-scoped authorization result)
///
/// ❌ Intentionally NOT invalidated (global/shared):
///   - Marketplace public discovery (`marketplaceProvider`)
///   - Modules / navigation (handled reactively via contextProvider)
///
/// This is a bounded refresh — it does not invalidate the whole app.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/access/application/providers/access_policy_provider.dart';
import 'package:famhub_app/features/business_hub/application/providers/active_business_provider.dart';
import 'package:famhub_app/features/business_hub/application/providers/my_businesses_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_lifecycle_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/marketplace/application/providers/marketplace_provider.dart';

/// Invalidate the entity/business-scoped provider set after a switch.
void refreshEntityScopedProviders(WidgetRef ref) {
  // ── Business Hub (entity/business scoped) ──
  ref.invalidate(myBusinessesProvider);
  // The business profile (commerce.business_profiles) is entity-scoped and
  // must be re-read after context changes (e.g. right after first-use
  // creation), otherwise a previously cached null keeps hiding the name.
  ref.invalidate(businessProfileProvider);

  // ── Marketplace (seller/owned scoped — NOT global discovery) ──
  ref.invalidate(sellerListingsProvider);
  ref.invalidate(eligibleStockProvider);

  // ── Farm (entity/farm-context scoped) ──
  ref.invalidate(farmSelectorProvider);
  ref.invalidate(farmLifecycleProvider);
  ref.invalidate(farmDashboardProvider);

  // ── Authorization (entity/role scoped) ──
  // `get_access_policy` derives the result from the ACTIVE entity-context
  // session and is cached in a non-autoDispose FutureProvider. It must be
  // refetched whenever the active entity/role changes, otherwise the
  // previous context's permissions (e.g. Admin) remain in effect after
  // switching back. The runtime decision engine and Admin capability
  // providers watch this provider, so invalidating it refreshes them
  // without any new provider or architecture change.
  ref.invalidate(accessPolicyProvider);
}
