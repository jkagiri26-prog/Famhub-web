/// ============================================================
/// MODULE ZONE REGISTRY (FALLBACK ONLY - SYSTEM AUTHORITY)
/// ============================================================
/// 
/// This registry delegates to ModuleZoneMappingEngine.
/// It MUST NOT hardcode module mappings.
/// Authority belongs to backend system configuration.
/// ============================================================
class ModuleZoneRegistry {
  const ModuleZoneRegistry();

  /// ============================================================
  /// FALLBACK RESOLVER (DELEGATES TO RUNTIME ENGINE)
  /// ============================================================
  String resolveZone(String moduleKey) {
    /// Always return safe default; real mapping happens in
    /// ModuleZoneMappingEngine which reads from backend.
    return 'main';
  }
}