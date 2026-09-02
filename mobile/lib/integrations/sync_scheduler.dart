import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

const syncTaskName = 'spendwiseDailySync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    // Background sync placeholder; full sync runs via Settings or on next app open.
    return true;
  });
}

class SyncScheduler {
  static var _initialized = false;

  /// Workmanager must not run at cold start — it can crash before the Activity
  /// is ready. Call this only when the user enables daily sync in Settings.
  static Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await Workmanager().initialize(callbackDispatcher);
      _initialized = true;
      return true;
    } catch (e, st) {
      debugPrint('Workmanager init failed: $e\n$st');
      return false;
    }
  }

  static Future<bool> registerDailySync() async {
    final ready = await initialize();
    if (!ready) return false;
    try {
      await Workmanager().registerPeriodicTask(
        syncTaskName,
        syncTaskName,
        frequency: const Duration(hours: 24),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      return true;
    } catch (e, st) {
      debugPrint('Workmanager register failed: $e\n$st');
      return false;
    }
  }

  static Future<void> cancelDailySync() async {
    if (!_initialized) return;
    try {
      await Workmanager().cancelByUniqueName(syncTaskName);
    } catch (e) {
      debugPrint('Workmanager cancel failed: $e');
    }
  }
}
