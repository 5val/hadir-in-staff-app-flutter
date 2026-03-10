import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

const _mockUser = {
  'name': 'Ahmad Fauzi',
  'email': 'ahmad.fauzi@company.com',
  'phone': '+62 812 3456 7890',
  'position': 'Software Engineer',
  'department': 'IT & Development',
  'employeeId': 'EMP-2024-0156',
  'joinDate': '15 Januari 2024',
  'avatar': 'AF',
};

final _menuItems = [
  {
    'id': 'personal',
    'title': 'Informasi Pribadi',
    'icon': Icons.person_outline,
    'color': BrandColors.navy,
  },
  {
    'id': 'attendance',
    'title': 'Riwayat Kehadiran',
    'icon': Icons.calendar_month_outlined,
    'color': SemanticColors.info,
  },
  {
    'id': 'leave',
    'title': 'Pengajuan Cuti/Izin',
    'icon': Icons.description_outlined,
    'color': SemanticColors.warning,
  },
  {
    'id': 'payslip',
    'title': 'Slip Gaji',
    'icon': Icons.wallet_outlined,
    'color': SemanticColors.success,
  },
  {
    'id': 'settings',
    'title': 'Pengaturan',
    'icon': Icons.settings_outlined,
    'color': NeutralColors.slate600,
  },
  {
    'id': 'help',
    'title': 'Bantuan',
    'icon': Icons.help_outlined,
    'color': BrandColors.cyan,
  },
];

// Workaround: Icons.help_circle_outlined doesn't exist in Flutter — use help_outline
// We'll use Icons.help_outline for the last item

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _handleMenuPress(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Segera Hadir'),
        content: const Text(
            'Fitur ini sedang dalam pengembangan dan akan segera tersedia.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            style: TextButton.styleFrom(
                foregroundColor: SemanticColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeutralColors.slate100,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  _buildEmployeeInfoCard(),
                  const SizedBox(height: 16),
                  _buildMenuCard(context),
                  const SizedBox(height: 16),
                  _buildLogoutButton(context),
                  const SizedBox(height: 24),
                  _buildVersionInfo(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.navy, BrandColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            children: [
              const Text('Profil',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 24),
              // Profile card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [BrandColors.cyan, BrandColors.lime],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _mockUser['avatar']!,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_mockUser['name']!,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(_mockUser['position']!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xCCFFFFFF))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.business_outlined,
                                    size: 12, color: BrandColors.cyan),
                                const SizedBox(width: 4),
                                Text(_mockUser['department']!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          size: 20, color: BrandColors.navy),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Employee Info Card ─────────────────────────
  Widget _buildEmployeeInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('ID Karyawan',
                    style: TextStyle(
                        fontSize: 12, color: NeutralColors.slate500)),
                const SizedBox(height: 4),
                Text(_mockUser['employeeId']!,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: NeutralColors.slate900)),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: NeutralColors.slate200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('Bergabung Sejak',
                    style: TextStyle(
                        fontSize: 12, color: NeutralColors.slate500)),
                const SizedBox(height: 4),
                Text(_mockUser['joinDate']!,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: NeutralColors.slate900),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Menu Card ──────────────────────────────────
  Widget _buildMenuCard(BuildContext context) {
    final icons = [
      Icons.person_outline,
      Icons.calendar_month_outlined,
      Icons.description_outlined,
      Icons.wallet_outlined,
      Icons.settings_outlined,
      Icons.help_outline,
    ];
    final colors = [
      BrandColors.navy,
      SemanticColors.info,
      SemanticColors.warning,
      SemanticColors.success,
      NeutralColors.slate600,
      BrandColors.cyan,
    ];
    final titles = [
      'Informasi Pribadi',
      'Riwayat Kehadiran',
      'Pengajuan Cuti/Izin',
      'Slip Gaji',
      'Pengaturan',
      'Bantuan',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: const Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: List.generate(titles.length, (i) {
          final isLast = i == titles.length - 1;
          return InkWell(
            onTap: () => _handleMenuPress(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(
                            color: NeutralColors.slate100)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors[i].withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icons[i], size: 20, color: colors[i]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(titles[i],
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: NeutralColors.slate800)),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 20, color: NeutralColors.slate400),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Logout ────────────────────────────────────
  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleLogout(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SemanticColors.errorBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_outlined,
                  size: 20, color: SemanticColors.error),
            ),
            const SizedBox(width: 12),
            const Text('Keluar',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SemanticColors.error)),
          ],
        ),
      ),
    );
  }

  // ── Version ────────────────────────────────────
  Widget _buildVersionInfo() {
    return const Column(
      children: [
        Text('Hadir-In Staff v1.0.0',
            style: TextStyle(
                fontSize: 13,
                color: NeutralColors.slate500,
                fontWeight: FontWeight.w500)),
        SizedBox(height: 4),
        Text('© 2026 Hadir-In. All rights reserved.',
            style: TextStyle(
                fontSize: 11, color: NeutralColors.slate400)),
      ],
    );
  }
}
