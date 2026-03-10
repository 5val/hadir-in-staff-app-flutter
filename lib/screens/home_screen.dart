import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/attendance_provider.dart';
import '../providers/office_provider.dart';
import '../theme/app_theme.dart';

const _mockHistory = [
  {
    'date': 'Selasa, 20 Jan 2026',
    'checkIn': '07:55',
    'checkOut': '17:05',
    'status': 'Hadir'
  },
  {
    'date': 'Senin, 19 Jan 2026',
    'checkIn': '08:05',
    'checkOut': '17:30',
    'status': 'Hadir'
  },
  {
    'date': 'Jumat, 16 Jan 2026',
    'checkIn': '09:15',
    'checkOut': '17:00',
    'status': 'Terlambat'
  },
  {
    'date': 'Kamis, 15 Jan 2026',
    'checkIn': '-',
    'checkOut': '-',
    'status': 'Izin'
  },
  {
    'date': 'Rabu, 14 Jan 2026',
    'checkIn': '07:50',
    'checkOut': '17:15',
    'status': 'Hadir'
  },
];

class HomeScreen extends StatefulWidget {
  final VoidCallback onGoToAbsen;
  const HomeScreen({super.key, required this.onGoToAbsen});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _refreshing = false;
  DateTime _currentTime = DateTime.now();
  Timer? _timer;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _refreshing = false);
  }

  Map<String, dynamic> _getStatusBadge(String status) {
    switch (status) {
      case 'Hadir':
        return {
          'bg': SemanticColors.successBg,
          'color': SemanticColors.success,
          'icon': Icons.check_circle
        };
      case 'Terlambat':
        return {
          'bg': SemanticColors.warningBg,
          'color': SemanticColors.warning,
          'icon': Icons.access_time
        };
      case 'Izin':
        return {
          'bg': SemanticColors.infoBg,
          'color': SemanticColors.info,
          'icon': Icons.description
        };
      case 'Cuti':
        return {
          'bg': const Color(0x26CAED3F),
          'color': BrandColors.lime,
          'icon': Icons.calendar_today
        };
      default:
        return {
          'bg': NeutralColors.slate100,
          'color': NeutralColors.slate500,
          'icon': Icons.help_outline
        };
    }
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) {
    const days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu'
    ];
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${days[dt.weekday % 7]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final attendanceData = context.watch<AttendanceProvider>().attendanceData;

    return Scaffold(
      backgroundColor: NeutralColors.slate50,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: BrandColors.navy,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusSection(attendanceData),
                        const SizedBox(height: 25),
                        _buildQuickActions(),
                        const SizedBox(height: 25),
                        _buildStatsSection(),
                        const SizedBox(height: 25),
                        _buildHistorySection(),
                        const SizedBox(height: 25),
                        const _DummyLocationSection(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.navy, BrandColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        colors: [BrandColors.cyan, BrandColors.lime],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: Text('AF',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selamat Datang,',
                            style: TextStyle(
                                fontSize: 12, color: Color(0x99FFFFFF))),
                        Text('Ahmad Fauzi',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text('Software Engineer',
                            style: TextStyle(
                                fontSize: 11, color: Color(0x80FFFFFF))),
                      ],
                    ),
                  ),
                  // Notification button
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            size: 22, color: Colors.white),
                      ),
                      Positioned(
                        top: 10,
                        right: 11,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: SemanticColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: BrandColors.navy, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 25),
              // Clock
              Text(
                _formatTime(_currentTime),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(_currentTime),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xB3FFFFFF)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STATUS CARD
  // ─────────────────────────────────────────────
  Widget _buildStatusSection(AttendanceData? data) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: data == null
              ? _buildNotCheckedIn()
              : _buildCheckedIn(data),
        ),
        if (data != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: NeutralColors.slate400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.address,
                    style: const TextStyle(
                        fontSize: 12, color: NeutralColors.slate400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotCheckedIn() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9EB),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Icon(Icons.access_time_outlined,
                size: 32, color: SemanticColors.warning),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Belum Absen Hari Ini',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: NeutralColors.slate900)),
        const SizedBox(height: 4),
        const Text(
          'Pastikan Anda berada di area kantor',
          style: TextStyle(fontSize: 13, color: NeutralColors.slate500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: widget.onGoToAbsen,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [BrandColors.navy, Color(0xFF2A4B7C)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Text('Absen Sekarang',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckedIn(AttendanceData data) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: SemanticColors.successBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Icon(Icons.check_circle,
                size: 32, color: SemanticColors.success),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sudah Absen Masuk',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: SemanticColors.success)),
              const SizedBox(height: 2),
              Text(data.time,
                  style: const TextStyle(
                      fontSize: 13, color: NeutralColors.slate500)),
              Text(data.date,
                  style: const TextStyle(
                      fontSize: 13, color: NeutralColors.slate500)),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: SemanticColors.successBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('TEPAT WAKTU',
              style: TextStyle(
                  color: SemanticColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────────────────
  Widget _buildQuickActions() {
    final actions = [
      {
        'label': 'Absen',
        'icon': Icons.camera_alt,
        'color': BrandColors.navy,
        'onTap': widget.onGoToAbsen
      },
      {
        'label': 'Izin',
        'icon': Icons.description,
        'color': SemanticColors.warning,
        'onTap': () {}
      },
      {
        'label': 'Cuti',
        'icon': Icons.calendar_today,
        'color': SemanticColors.info,
        'onTap': () {}
      },
      {
        'label': 'Riwayat',
        'icon': Icons.access_time,
        'color': BrandColors.lime,
        'onTap': () {}
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Layanan Cepat',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: NeutralColors.slate800)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((a) {
            final color = a['color'] as Color;
            return GestureDetector(
              onTap: a['onTap'] as VoidCallback,
              child: Column(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Icon(a['icon'] as IconData,
                          size: 24, color: color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(a['label'] as String,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: NeutralColors.slate700)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // STATS
  // ─────────────────────────────────────────────
  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ringkasan Kehadiran',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: NeutralColors.slate800)),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatBox(
                label: 'Hadir',
                value: '18',
                color: SemanticColors.success,
                bg: SemanticColors.successBg),
            const SizedBox(width: 12),
            _StatBox(
                label: 'Telat',
                value: '2',
                color: SemanticColors.warning,
                bg: SemanticColors.warningBg),
            const SizedBox(width: 12),
            _StatBox(
                label: 'Izin',
                value: '1',
                color: SemanticColors.info,
                bg: SemanticColors.infoBg),
            const SizedBox(width: 12),
            _StatBox(
                label: 'Cuti',
                value: '0',
                color: SemanticColors.error,
                bg: SemanticColors.errorBg),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // HISTORY
  // ─────────────────────────────────────────────
  Widget _buildHistorySection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Riwayat Kehadiran',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: NeutralColors.slate800)),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Lihat Semua',
                  style: TextStyle(
                      fontSize: 13,
                      color: BrandColors.navy,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: List.generate(_mockHistory.length, (i) {
              final item = _mockHistory[i];
              final badge = _getStatusBadge(item['status']!);
              final isLast = i == _mockHistory.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 15, vertical: 15),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(
                              color: NeutralColors.slate100)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['date']!,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: NeutralColors.slate800)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.login,
                                  size: 14,
                                  color: NeutralColors.slate400),
                              const SizedBox(width: 4),
                              Text(item['checkIn']!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: NeutralColors.slate500,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(width: 16),
                              const Icon(Icons.logout,
                                  size: 14,
                                  color: NeutralColors.slate400),
                              const SizedBox(width: 4),
                              Text(item['checkOut']!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: NeutralColors.slate500,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      constraints:
                          const BoxConstraints(minWidth: 85),
                      decoration: BoxDecoration(
                        color: badge['bg'] as Color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(badge['icon'] as IconData,
                              size: 12, color: badge['color'] as Color),
                          const SizedBox(width: 4),
                          Text(item['status']!,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: badge['color'] as Color)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// STAT BOX widget
// ─────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const _StatBox(
      {required this.label,
      required this.value,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: NeutralColors.slate500)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DUMMY LOCATION SECTION (Dev-only)
// ─────────────────────────────────────────────
class _DummyLocationSection extends StatefulWidget {
  const _DummyLocationSection();

  @override
  State<_DummyLocationSection> createState() =>
      _DummyLocationSectionState();
}

class _DummyLocationSectionState extends State<_DummyLocationSection> {
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late TextEditingController _radiusCtrl;

  @override
  void initState() {
    super.initState();
    final loc = context.read<OfficeProvider>().location;
    _latCtrl = TextEditingController(text: loc.lat);
    _lngCtrl = TextEditingController(text: loc.lng);
    _radiusCtrl = TextEditingController(text: loc.radius);
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Color(0xFFF59E0B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF59E0B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
      ),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<OfficeProvider>();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚙️ Titik Absen Dummy (Dev Only)',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF92400E),
                fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Latitude',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _latCtrl,
                      onChanged: provider.updateLat,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF92400E)),
                      decoration: _inputDecoration(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Longitude',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _lngCtrl,
                      onChanged: provider.updateLng,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF92400E)),
                      decoration: _inputDecoration(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Radius (m)',
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _radiusCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: provider.updateRadius,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF92400E)),
                      decoration: _inputDecoration(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              final loc = context.read<OfficeProvider>().location;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Konfigurasi Disimpan'),
                  content: Text(
                      'Titik Absen: ${loc.lat}, ${loc.lng}\nRadius: ${loc.radius}m'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK')),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF92400E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_outlined,
                      size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Terapkan Parameter',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
