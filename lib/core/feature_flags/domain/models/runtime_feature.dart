class RuntimeFeature {
  final String key;
  final bool enabled;
  final String? description;

  const RuntimeFeature({
    required this.key,
    required this.enabled,
    this.description,
  });

  factory RuntimeFeature.fromMap(Map<String, dynamic> map) {
    return RuntimeFeature(
      key: map['key'],
      enabled: map['enabled'] ?? false,
      description: map['description'],
    );
  }
}