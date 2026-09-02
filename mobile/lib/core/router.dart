import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/features/accounts/accounts_screens.dart';
import 'package:spendwise_mobile/features/dashboard/dashboard_screen.dart';
import 'package:spendwise_mobile/features/settings/settings_screen.dart';
import 'package:spendwise_mobile/features/splits/splits_screens.dart';
import 'package:spendwise_mobile/features/transactions/transaction_form_screen.dart';
import 'package:spendwise_mobile/features/transactions/transactions_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.uri.toString(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/sources',
            builder: (context, state) => const AccountsHubScreen(),
          ),
          GoRoute(
            path: '/splits',
            builder: (context, state) => const SplitsHubScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) => const TransactionFormScreen(),
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (context, state) => TransactionDetailScreen(
          transactionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        builder: (context, state) => TransactionFormScreen(
          transactionId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/transactions/:id/split',
        builder: (context, state) => AddSplitScreen(
          transactionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/sources/list',
        builder: (context, state) => const PaymentSourcesScreen(),
      ),
      GoRoute(
        path: '/sources/new',
        builder: (context, state) => const PaymentSourceFormScreen(),
      ),
      GoRoute(
        path: '/sources/:id',
        builder: (context, state) => PaymentSourceFormScreen(
          sourceId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/apps',
        builder: (context, state) => const PaymentAppsScreen(),
      ),
      GoRoute(
        path: '/apps/new',
        builder: (context, state) => const PaymentAppFormScreen(),
      ),
      GoRoute(
        path: '/apps/:id',
        builder: (context, state) => PaymentAppFormScreen(
          appId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/methods',
        builder: (context, state) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: '/contacts/new',
        builder: (context, state) => const ContactFormScreen(),
      ),
      GoRoute(
        path: '/contacts/:id',
        builder: (context, state) => ContactFormScreen(
          contactId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: '/groups/new',
        builder: (context, state) => const GroupFormScreen(),
      ),
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) => GroupFormScreen(
          groupId: state.pathParameters['id'],
        ),
      ),
    ],
  );
});
