import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class SideMenu extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const SideMenu({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppTheme.sidebarColor,
      child: Column(
        children: [
          const SizedBox(height: 50),
          const Text(
            'DSYS v2',
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 50),
          _MenuButton(
            title: 'Fatura Oluştur',
            icon: Icons.receipt_long,
            isActive: navigationShell.currentIndex == 0,
            onTap: () => navigationShell.goBranch(
              0,
              initialLocation: navigationShell.currentIndex == 0,
            ),
          ),
          _MenuButton(
            title: 'YK Karar Merkezi',
            icon: Icons.gavel,
            isActive: navigationShell.currentIndex == 1,
            onTap: () => navigationShell.goBranch(
              1,
              initialLocation: navigationShell.currentIndex == 1,
            ),
          ),
          _MenuButton(
            title: 'Danışmanlık Takibi',
            icon: Icons.support_agent,
            isActive: navigationShell.currentIndex == 2,
            onTap: () => navigationShell.goBranch(
              2,
              initialLocation: navigationShell.currentIndex == 2,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, indent: 20, endIndent: 20),
          const SizedBox(height: 10),

          _MenuButton(
            title: 'Sistem Ayarları',
            icon: Icons.settings,
            isActive: navigationShell.currentIndex == 3,
            onTap: () => navigationShell.goBranch(
              3,
              initialLocation: navigationShell.currentIndex == 3,
            ),
          ),

          const Spacer(),
          const Divider(color: Colors.white24),
          _MenuButton(
            title: 'Çıkış Yap',
            icon: Icons.logout,
            isActive: false,
            onTap: () {
              context.read<AuthProvider>().signOut();
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppTheme.white : Colors.white54,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? AppTheme.white : Colors.white54,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
      onTap: onTap,
    );
  }
}
