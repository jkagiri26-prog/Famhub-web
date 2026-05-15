class ConflictItem {
  final String recordId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;

  ConflictItem({
    required this.recordId,
    required this.localData,
    required this.serverData,
  });
}