/// ============================================================
/// SPATIAL SDK — PUBLIC FACADE IN SDK LAYER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// This is the SDK-layer re-export of the Spatial SDK.
/// Feature modules access spatial via:
///   sdk.spatial.currentAsset()
///   sdk.spatial.selectAsset(asset)
///   sdk.spatial.area()
///
/// ✅ Responsibilities:
///   - Re-export SpatialSdk from core/spatial/sdk
///   - Provide a provider for the SDK
///
/// ❌ Does NOT:
///   - Duplicate logic (delegates to SpatialSdk)
///   - Import Flutter widgets
///   - Contain business logic
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/spatial/sdk/spatial_sdk.dart'
    as spatial_sdk;
import 'api/sdk_annotations.dart';

/// ============================================================
/// SPATIAL SDK (SDK-LAYER ALIAS)
/// ============================================================
///
/// Re-export of the core SpatialSdk for the FamhubSdk facade.
/// ============================================================
@PublicSdk()
typedef SpatialSdk = spatial_sdk.SpatialSdk;

/// ============================================================
/// PROVIDER: SPATIAL SDK
/// ============================================================
@SdkProvider()
final famhubSpatialSdkProvider = Provider<SpatialSdk>((ref) {
  return SpatialSdk(ref);
});
