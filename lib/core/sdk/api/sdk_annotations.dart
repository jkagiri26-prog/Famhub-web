/// ============================================================
/// SDK ANNOTATIONS — Marker annotations for SDK classes/methods
/// ============================================================
library;

/// Annotation for SDK methods — marks a method as part of the public SDK API
/// Lowercase variant used by: access_sdk, capability_sdk
class sdkMethod {
  final String version;
  const sdkMethod({this.version = '1.0.0'});
}

/// Annotation for SDK methods — uppercase variant
/// Used by: ai_context_sdk, dashboard_sdk, navigation_sdk, notification_sdk, policy_sdk, shell_sdk
class SdkMethod {
  final String version;
  const SdkMethod({this.version = '1.0.0'});
}

/// Annotation for public SDK classes
class PublicSdk {
  const PublicSdk();
}

/// Annotation for SDK provider declarations — uppercase variant
class SdkProvider {
  const SdkProvider();
}

/// Annotation for SDK provider declarations — lowercase variant
class sdkProvider {
  const sdkProvider();
}

/// Annotation for public SDK classes — lowercase variant
/// Used by: capability_sdk, dashboard_sdk, policy_sdk, workspace_sdk
class publicSdk {
  const publicSdk();
}

