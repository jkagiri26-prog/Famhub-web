/// =======================================================
/// MODULE ACTIVATION MODEL
/// =======================================================
///
/// Represents the remote activation state of a module.
/// Backend is authoritative — this is a cached model only.
///
/// Rules:
/// - NO business logic
/// - NO feature decisions
/// - Simple serialization only
///
/// =======================================================
library;

class ModuleActivation {
  final String moduleId;
  final String moduleKey;
  final bool isActive;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> config;

  const ModuleActivation({
    required this.moduleId,
    required this.moduleKey,
    required this.isActive,
    this.activatedAt,
    this.expiresAt,
    this.config = const {},
  });

  factory ModuleActivation.fromJson(Map<String, dynamic> json) {
    return ModuleActivation(
      moduleId: json['moduleId'] as String? ?? json['id'] as String? ?? '',
      moduleKey: json['moduleKey'] as String? ?? json['key'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? json['active'] as bool? ?? false,
      activatedAt: json['activatedAt'] != null
          ? DateTime.tryParse(json['activatedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'moduleId': moduleId,
        'moduleKey': moduleKey,
        'isActive': isActive,
        'activatedAt': activatedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'config': config,
      };
}
