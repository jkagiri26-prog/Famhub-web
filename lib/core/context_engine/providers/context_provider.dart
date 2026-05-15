final contextProvider =
    StateNotifierProvider<ContextController, EntityContext>((ref) {
  return ContextController(
    ContextStorageService(),
    ContextSyncService(),
  );
});