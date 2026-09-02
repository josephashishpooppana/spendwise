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
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> registerDailySync() async {
    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskName,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> cancelDailySync() async {
    await Workmanager().cancelByUniqueName(syncTaskName);
  }
}
