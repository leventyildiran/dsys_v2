import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/side_menu.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Ana İçerik
          Positioned.fill(
            left: 65, // Sol menünün kapalı genişliği kadar boşluk
            child: navigationShell,
          ),

          // Sol Menü (SideMenu) - Kendi içinde hover yönetir
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SideMenu(navigationShell: navigationShell),
          ),
        ],
      ),
    );
  }
}
