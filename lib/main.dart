import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'features/fatura/providers/batch_fatura_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/user_provider.dart';

late final GoRouter _router;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final authProvider = AuthProvider();
  _router = AppRouter.createRouter(authProvider);
  runApp(DsysApp(authProvider: authProvider));
}

class DsysApp extends StatelessWidget {
  final AuthProvider authProvider;
  
  const DsysApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(authProvider: authProvider),
          update: (_, auth, userProvider) => userProvider ?? UserProvider(authProvider: auth),
        ),
        ChangeNotifierProvider(create: (_) => BatchFaturaProvider()),
      ],
      child: MaterialApp.router(
        title: 'DSYS v2',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
