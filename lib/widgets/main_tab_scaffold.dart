import 'package:flutter/material.dart';
import '../screens/absen_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../theme/app_theme.dart';

class MainTabScaffold extends StatefulWidget {
  const MainTabScaffold({super.key});

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  int _currentIndex = 0;

  void _goToAbsen() => setState(() => _currentIndex = 1);
  void _goToHome() => setState(() => _currentIndex = 0);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onGoToAbsen: _goToAbsen),
      AbsenScreen(onAttendanceSuccess: _goToHome),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _buildTabBar(),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: NeutralColors.slate200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _buildTabItem(0, Icons.home, Icons.home_outlined, 'Home'),
              _buildTabItem(
                  1, Icons.camera_alt, Icons.camera_alt_outlined, 'Absen'),
              _buildTabItem(
                  2,
                  Icons.account_circle,
                  Icons.account_circle_outlined,
                  'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
      int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    final color =
        isActive ? BrandColors.navy : NeutralColors.slate400;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              size: 24,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
