import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../firebase/firebase_providers.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/fighters/presentation/fighters_page.dart';
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
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: '/fighters',
            builder: (context, state) => const FightersPage(),
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

      final isAdmin = await ref.read(authRepositoryProvider).isAdmin(user.uid);
      if (!isAdmin) {
        await ref.read(authRepositoryProvider).logout();
        return '/login';
      }

      if (onLoginPage) {
        return '/dashboard';
      }
      return null;
    },
  );
});
