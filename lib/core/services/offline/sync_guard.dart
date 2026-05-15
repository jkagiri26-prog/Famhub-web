class SyncGuard {
  bool canSync(bool isOnline, bool isUserLoggedIn) {
    return isOnline && isUserLoggedIn;
  }
}