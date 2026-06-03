import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/side_menu.dart';
import '../widgets/header.dart';
import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardScreen({super.key, required this.navigationShell});

  String _getScreenTitle(int currentIndex) {
    switch (currentIndex) {
      case 0:
        return 'Fatura İşlemleri';
      case 1:
        return 'Yönetim Kurulu Kararları';
      case 2:
        return 'Danışmanlık Takibi';
      case 3:
        return 'Sistem Yönetimi (Super Admin)';
      case 4:
        return 'Sistem Ayarları';
      default:
        return 'DSYS Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Row(
        children: [
          SideMenu(navigationShell: navigationShell),
          Expanded(
            child: Column(
              children: [
                Header(title: _getScreenTitle(navigationShell.currentIndex)),
                Expanded(
                  child: navigationShell,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
