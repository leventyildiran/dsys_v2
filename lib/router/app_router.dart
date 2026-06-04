import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/danismanlik/screens/danismanlik_dashboard_screen.dart';
import '../features/danismanlik/screens/danismanlik_form_screen.dart';
import '../features/yk_karar/screens/yk_karar_screen.dart';
import '../features/yk_karar/models/yk_karar_model.dart';
import '../features/danismanlik/screens/danismanlik_screen.dart';
import '../features/danismanlik/screens/danismanlik_detay_screen.dart';
import '../features/admin/screens/admin_dashboard_screen.dart';
import '../features/fatura/screens/batch_verification_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/ayarlar/screens/sistem_ayarlari_screen.dart';
import '../features/danismanlik/models/danismanlik_model.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuth = authProvider.isAuthenticated;
        final isGoingToLogin = state.uri.path == '/login';
        
        if (authProvider.isLoading) return null; // Wait for initialization
        
        if (!isAuth && !isGoingToLogin) return '/login';
        if (isAuth && isGoingToLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return DashboardScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const BatchVerificationScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/yk-karar',
                  builder: (context, state) => const YkKararScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/danismanlik',
                  builder: (context, state) => const DanismanlikDashboardScreen(),
                  routes: [
                    GoRoute(
                      path: 'detay',
                      builder: (context, state) {
                        final model = state.extra as DanismanlikModel;
                        return DanismanlikDetayScreen(danismanlik: model);
                      },
                    ),
                    GoRoute(
                      path: 'yeni',
                      builder: (context, state) {
                        final ykKarar = state.extra as YkKararModel?;
                        return DanismanlikFormScreen(ykKarar: ykKarar);
                      },
                    ),
                  ],
                ),
              ],
            ),

            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/ayarlar',
                  builder: (context, state) => const SistemAyarlariScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
