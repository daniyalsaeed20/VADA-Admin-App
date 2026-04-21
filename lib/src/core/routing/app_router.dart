import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../firebase/firebase_providers.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/fighters/presentation/fighters_page.dart';
import '../../features/shared/presentation/coming_soon_page.dart';
import '../../features/shell/presentation/admin_shell.dart';
import 'router_refresh_stream.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final refreshStream = RouterRefreshStream(authRepo.authStateChanges());
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refreshStream,
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _noTransitionPage(state: state, child: const LoginPage()),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) =>
                _noTransitionPage(state: state, child: const DashboardPage()),
          ),
          GoRoute(
            path: '/fighters',
            pageBuilder: (context, state) =>
                _noTransitionPage(state: state, child: const FightersPage()),
          ),
          GoRoute(
            path: '/contacts',
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.contacts'),
            ),
          ),
          GoRoute(
            path: '/locations',
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.locations'),
            ),
          ),
          GoRoute(
            path: '/whereabouts',
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.whereabouts'),
            ),
          ),
          GoRoute(
            path: '/checkins',
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.checkins'),
            ),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.notifications'),
            ),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.reports'),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.settings'),
            ),
          ),
        ],
      ),
    ],
    redirect: (context, state) async {
      final auth = ref.read(firebaseAuthProvider);
      final user = auth.currentUser;
      final onLoginPage = state.matchedLocation == '/login';

      if (user == null) {
        return onLoginPage ? null : '/login';
      }

      final isAdmin = await authRepo.isAdmin(user.uid);
      if (!isAdmin) {
        await authRepo.logout();
        return '/login';
      }

      if (onLoginPage) {
        return '/dashboard';
      }
      return null;
    },
  );
});

NoTransitionPage<void> _noTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}
