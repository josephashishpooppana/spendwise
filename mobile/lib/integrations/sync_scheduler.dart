import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

const syncTaskName = 'spendwiseDailySync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    // Background sync is triggered; full sync runs when app opens if this fails.
    return Future.value(true);
  });
}

class SyncScheduler {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
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
