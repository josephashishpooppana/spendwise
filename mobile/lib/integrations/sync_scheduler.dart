/// Daily sync scheduling stub.
///
/// Background Workmanager was removed because its native Android code caused
/// crashes on cold start on some devices. Use **Sync now** in Settings instead.
class SyncScheduler {
  static Future<bool> registerDailySync() async {
    // No-op: user can sync manually from Settings.
    return true;
  }

  static Future<void> cancelDailySync() async {}
}
