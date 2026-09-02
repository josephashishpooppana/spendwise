import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/router.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/integrations/sync_scheduler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SyncScheduler.initialize();
  runApp(const ProviderScope(child: SpendWiseApp()));
}

class SpendWiseApp extends ConsumerWidget {
  const SpendWiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SpendWise',
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
