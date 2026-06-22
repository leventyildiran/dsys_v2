import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/danismanlik/screens/danismanlik_dashboard_screen.dart';
import '../features/danismanlik/screens/danismanlik_form_screen.dart';
import '../features/yk_karar/screens/yk_yeni_karar_ekle_screen.dart';
import '../features/yk_karar/screens/yk_eski_kararlar_screen.dart';
import '../features/yk_karar/screens/yk_toplanti_arsiv_detay_screen.dart';
import '../features/yk_karar/models/yk_karar_model.dart';
import '../features/yk_karar/screens/gundem_yonetim_screen.dart';
import '../features/danismanlik/screens/danismanlik_detay_screen.dart';
import '../features/danismanlik/screens/danismanlik_dagitim_screen.dart';
import '../features/danismanlik/screens/danismanlik_takip_screen.dart';
import '../features/beyanname/screens/beyanname_hesapla_screen.dart';
import '../features/fatura/screens/batch_verification_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/pending_approval_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/ayarlar/screens/sistem_ayarlari_screen.dart';
import '../features/danismanlik/models/danismanlik_model.dart';
import '../features/danismanlik/widgets/danismanlik_layout.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final path = state.uri.path;
        final isAuth = authProvider.isAuthenticated;
        final canAccess = authProvider.canAccess;
        final isGoingToLogin = path == '/login';
        final isGoingToSignup = path == '/signup';
        final isGoingToPending = path == '/pending-approval';
        final isPublicRoute =
            isGoingToLogin || isGoingToSignup || isGoingToPending;
        final isSettingsRoute = path == '/ayarlar';

        if (authProvider.isLoading) return null;

        if (!isAuth && !isPublicRoute) return '/login';

        if (isAuth && !canAccess && !isGoingToPending) {
          return '/pending-approval';
        }

        if (isAuth &&
            canAccess &&
            (isGoingToLogin || isGoingToSignup || isGoingToPending)) {
          return '/';
        }

        if (isAuth && isSettingsRoute && !authProvider.isAdmin) {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/pending-approval',
          builder: (context, state) => const PendingApprovalScreen(),
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
                  builder: (context, state) => const YkYeniKararEkleScreen(),
                  routes: [
                    GoRoute(
                      path: 'eski',
                      builder: (context, state) => const YkEskiKararlarScreen(),
                      routes: [
                        GoRoute(
                          path: ':toplantiId',
                          builder: (context, state) =>
                              YkToplantiArsivDetayScreen(
                                toplantiId: state.pathParameters['toplantiId']!,
                              ),
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'gundem',
                      builder: (context, state) => const GundemScreen(),
                    ),
                  ],
                ),
              ],
            ),

            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/danismanlik',
                  builder: (context, state) =>
                      const DanismanlikDashboardScreen(),
                  routes: [
                    GoRoute(
                      path: 'detay/:id',
                      builder: (context, state) {
                        if (state.extra is DanismanlikModel) {
                          return DanismanlikDetayScreen(
                            danismanlik: state.extra as DanismanlikModel,
                          );
                        }
                        return DanismanlikDetayLoader(
                          id: state.pathParameters['id']!,
                        );
                      },
                    ),
                    GoRoute(
                      path: 'dagitim',
                      builder: (context, state) {
                        if (state.extra is DanismanlikRouteExtra) {
                          final e = state.extra as DanismanlikRouteExtra;
                          return DanismanlikDagitimScreen(
                            danismanlik: e.model,
                            taksit: e.taksit,
                          );
                        }
                        final model = state.extra as DanismanlikModel;
                        return DanismanlikDagitimScreen(danismanlik: model);
                      },
                    ),
                    GoRoute(
                      path: 'takip',
                      builder: (context, state) =>
                          const DanismanlikTakipScreen(),
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
                  path: '/beyanname-hesapla',
                  builder: (context, state) => const BeyannameHesaplaScreen(),
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
