import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_tab.dart';
import 'leave_tab.dart';
import 'salary_screen.dart';
import 'account_tab.dart';
import 'checkin_screen.dart';

/// Bottom-nav wrapper — Home | Leave & Time Off | [FAB Check-In] | Salary | Account
class MainScreen extends StatefulWidget {
  final int initialTab;
  const MainScreen({super.key, this.initialTab = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  void _onTabTap(int i) {
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(onNavigateToAccount: () => _onTabTap(4)),
          const LeaveTab(),
          const CheckinScreen(),  // slot 2 reserved untuk FAB
          const SalaryScreen(isFromAccount: false),
          const AccountTab(),
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
              icon: Icons.event_note_rounded, label: 'Cuti & Izin',
              selected: _tab == 1, onTap: () => _onTabTap(1),
            ),
            const SizedBox(width: 56), // spacer FAB
            _NavItem(
              icon: Icons.account_balance_wallet_rounded, label: 'Gaji',
              selected: _tab == 3, onTap: () => _onTabTap(3),
            ),
            _NavItem(
              icon: Icons.person_rounded, label: 'Akun',
              selected: _tab == 4, onTap: () => _onTabTap(4),
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
          // onTap: () => Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (_) => const CheckinScreen()),
          // ),
          onTap: () => _onTabTap(2),
          child: const Icon(Icons.fingerprint_rounded,
              color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
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