import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_tab.dart';
import 'history_screen.dart';
import 'salary_screen.dart';
import 'checkin_screen.dart';
import 'login_screen.dart';

/// Bottom-nav wrapper — Home | History | [FAB Check-In] | Leave | Salary.
/// Tab Leave selalu redirect ke re-verifikasi login.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;

  void _onTabTap(int i) {
    if (i == 2) {
      // Tab Leave → redirect ke re-verifikasi, bukan langsung masuk
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(destination: LoginDestination.leaveRequest),
        ),
      );
      return; // jangan update _tab ke 2 — tetap di tab sebelumnya
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeTab(),
          HistoryScreen(),
          // index 2 = Leave tidak pernah dirender langsung dari sini
          // tapi kita butuh widget placeholder agar IndexedStack tidak error
          _LeavePlaceholder(),
          SalaryScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: AppColors.white,
      elevation: 8,
      shadowColor: AppColors.brandNavy.withOpacity(0.1),
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded, label: 'Home',
              selected: _tab == 0, onTap: () => _onTabTap(0),
            ),
            _NavItem(
              icon: Icons.history_rounded, label: 'History',
              selected: _tab == 1, onTap: () => _onTabTap(1),
            ),
            const SizedBox(width: 56), // spacer untuk FAB
            _NavItem(
              icon: Icons.event_note_rounded, label: 'Leave',
              selected: false, // tidak pernah "selected" — selalu redirect
              onTap: () => _onTabTap(2),
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_rounded, label: 'Salary',
              selected: _tab == 3, onTap: () => _onTabTap(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.35),
            blurRadius: 14, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CheckinScreen()),
          ),
          child: const Icon(Icons.fingerprint_rounded,
              color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _LeavePlaceholder extends StatelessWidget {
  const _LeavePlaceholder();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon, required this.label,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandNavy : AppColors.slate400;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}