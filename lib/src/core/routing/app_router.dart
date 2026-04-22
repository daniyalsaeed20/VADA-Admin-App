import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../firebase/firebase_providers.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/fighters/presentation/fighters_page.dart';
import '../../features/contacts/presentation/contacts_page.dart';
import '../../features/locations/presentation/locations_page.dart';
import '../../features/shared/presentation/coming_soon_page.dart';
import '../../features/shell/presentation/admin_shell.dart';
import 'router_refresh_stream.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final refreshStream = RouterRefreshStream(authRepo.authStateChanges());
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refreshStream,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            _noTransitionPage(state: state, child: const LoginPage()),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) =>
                _noTransitionPage(state: state, child: const DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.fighters,
            pageBuilder: (context, state) =>
                _noTransitionPage(state: state, child: const FightersPage()),
          ),
          GoRoute(
            path: AppRoutes.contacts,
            pageBuilder: (context, state) =>
                _noTransitionPage(state: state, child: const ContactsPage()),
          ),
          GoRoute(
            path: AppRoutes.locations,
            pageBuilder: (context, state) =>
                _noTransitionPage(state: state, child: const LocationsPage()),
          ),
          GoRoute(
            path: AppRoutes.whereabouts,
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.whereabouts'),
            ),
          ),
          GoRoute(
            path: AppRoutes.checkins,
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.checkins'),
            ),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.notifications'),
            ),
          ),
          GoRoute(
            path: AppRoutes.reports,
            pageBuilder: (context, state) => _noTransitionPage(
              state: state,
              child: const ComingSoonPage(titleKey: 'nav.reports'),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
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
      final onLoginPage = state.matchedLocation == AppRoutes.login;

      if (user == null) {
        return onLoginPage ? null : AppRoutes.login;
      }

      final isAdmin = await authRepo.isAdmin(user.uid);
      if (!isAdmin) {
        await authRepo.logout();
        return AppRoutes.login;
      }

      if (onLoginPage) {
        return AppRoutes.dashboard;
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
