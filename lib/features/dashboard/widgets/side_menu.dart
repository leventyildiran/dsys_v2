import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class SideMenu extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const SideMenu({super.key, required this.navigationShell});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: _isHovered ? 250 : 65,
        color: AppTheme.sidebarColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            // Logo / Başlık
            SizedBox(
              height: 40,
              child: _isHovered 
                  ? const Center(
                      child: Text(
                        'DSYS v2',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.clip,
                        maxLines: 1,
                      ),
                    )
                  : const Center(
                      child: Text(
                        'D',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 50),
            _MenuButton(
              title: 'Fatura Oluştur',
              icon: Icons.receipt_long,
              isActive: widget.navigationShell.currentIndex == 0,
              isExpanded: _isHovered,
              onTap: () => widget.navigationShell.goBranch(
                0,
                initialLocation: widget.navigationShell.currentIndex == 0,
              ),
            ),
            _MenuButton(
              title: 'YK Karar Merkezi',
              icon: Icons.gavel,
              isActive: widget.navigationShell.currentIndex == 1,
              isExpanded: _isHovered,
              onTap: () => widget.navigationShell.goBranch(
                1,
                initialLocation: widget.navigationShell.currentIndex == 1,
              ),
            ),
            _MenuButton(
              title: 'Danışmanlık Takibi',
              icon: Icons.support_agent,
              isActive: widget.navigationShell.currentIndex == 2,
              isExpanded: _isHovered,
              onTap: () => widget.navigationShell.goBranch(
                2,
                initialLocation: widget.navigationShell.currentIndex == 2,
              ),
            ),
            _MenuButton(
              title: 'Beyanname Hesapla',
              icon: Icons.calculate,
              isActive: widget.navigationShell.currentIndex == 3,
              isExpanded: _isHovered,
              onTap: () => widget.navigationShell.goBranch(
                3,
                initialLocation: widget.navigationShell.currentIndex == 3,
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white24, indent: 10, endIndent: 10),
            const SizedBox(height: 10),
            _MenuButton(
              title: 'Sistem Ayarları',
              icon: Icons.settings,
              isActive: widget.navigationShell.currentIndex == 4,
              isExpanded: _isHovered,
              onTap: () => widget.navigationShell.goBranch(
                4,
                initialLocation: widget.navigationShell.currentIndex == 4,
              ),
            ),

            const Spacer(),
            const Divider(color: Colors.white24, indent: 10, endIndent: 10),
            _MenuButton(
              title: 'Çıkış Yap',
              icon: Icons.logout,
              isActive: false,
              isExpanded: _isHovered,
              onTap: () {
                context.read<AuthProvider>().signOut();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onTap;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? AppTheme.white : Colors.white54,
                size: 24,
              ),
              if (isExpanded) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive ? AppTheme.white : Colors.white54,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
