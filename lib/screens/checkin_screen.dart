import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'home_screen.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with TickerProviderStateMixin {
  final UserProfile user = SampleData.currentUser;

  bool _useGps           = true;
  bool _isLoadingLocation = false;
  bool _showSuccess       = false;
  String _locationLabel   = '';
  String _checkType       = 'checkin';

  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  final ShiftModel shift = SampleData.morningShift;

  late AnimationController _successCtrl;
  late AnimationController _locationCtrl;
  late Animation<double> _successScale;
  late Animation<double> _successFade;
  late Animation<double> _locationFade;

  @override
  void initState() {
    super.initState();

    _successCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _locationCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );

    _successScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );
    _successFade = CurvedAnimation(parent: _successCtrl, curve: Curves.easeIn);
    _locationFade = CurvedAnimation(parent: _locationCtrl, curve: Curves.easeIn);

    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _successCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  bool get _isWorkDay => _now.weekday >= DateTime.monday && _now.weekday <= DateTime.friday;

  bool get _canCheckin {
    if (!_isWorkDay) return false;
    final shiftStart = DateTime(_now.year, _now.month, _now.day,
        shift.startTime.hour, shift.startTime.minute);
    return _now.isAfter(shiftStart.subtract(const Duration(minutes: 30)));
  }

  int get _lateMinutes {
    final shiftStart = DateTime(_now.year, _now.month, _now.day,
        shift.startTime.hour, shift.startTime.minute);
    if (_now.isBefore(shiftStart)) return 0;
    return _now.difference(shiftStart).inMinutes;
  }

  bool get _isLate  => _lateMinutes > 0;
  bool get _isEarly => _now.isBefore(DateTime(_now.year, _now.month, _now.day,
      shift.startTime.hour, shift.startTime.minute));

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) {
    const days   = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const months = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  Future<void> _fetchLocation() async {
    setState(() { _isLoadingLocation = true; _locationLabel = ''; });
    _locationCtrl.reset();
    await Future.delayed(const Duration(milliseconds: 1500));
    final locs = [
      'Jl. Sudirman No. 12, Kel. Karet Tengsin, Kec. Tanah Abang, Jakarta Pusat',
      'Jl. Gatot Subroto No. 5, Kel. Menteng Atas, Kec. Setiabudi, Jakarta Selatan',
      'Jl. HR Rasuna Said Kav. 1, Kel. Kuningan Timur, Kec. Setiabudi',
    ];
    if (mounted) {
      setState(() {
        _locationLabel     = locs[DateTime.now().second % locs.length];
        _isLoadingLocation = false;
      });
      _locationCtrl.forward();
    }
  }

  Future<void> _performCheckin() async {
    if (_useGps && _locationLabel.isEmpty) await _fetchLocation();
    setState(() => _showSuccess = true);
    _successCtrl.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _successCtrl.reverse().then((_) {
      setState(() => _showSuccess = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── App Bar ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: AppColors.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text('Absensi', style: AppText.headline3),
                      const Spacer(),
                      // Type toggle
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            _TypeBtn(
                              label: 'Check-in',
                              selected: _checkType == 'checkin',
                              accentColor: AppColors.primary,
                              onTap: () => setState(() => _checkType = 'checkin'),
                            ),
                            _TypeBtn(
                              label: 'Check-out',
                              selected: _checkType == 'checkout',
                              accentColor: AppColors.primary,
                              onTap: () => setState(() => _checkType = 'checkout'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // ── Clock ──────────────────────────
                        _ClockCard(
                          time: _formatTime(_now),
                          date: _formatDate(_now),
                          isLate: _isLate,
                          isEarly: _isEarly,
                          lateMinutes: _lateMinutes,
                        ),

                        const SizedBox(height: 16),

                        // ── Shift Info ─────────────────────
                        SectionCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.schedule_rounded,
                                    color: AppColors.primary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(shift.name, style: AppText.label),
                                    Text(
                                      '${shift.startTimeStr} — ${shift.endTimeStr}',
                                      style: AppText.body1.copyWith(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isWorkDay)
                                StatusBadge(label: 'Libur', color: AppColors.warning)
                              else if (_isEarly)
                                StatusBadge(label: 'Lebih Awal', color: AppColors.success)
                              else if (_lateMinutes == 0)
                                StatusBadge(label: 'Tepat Waktu', color: AppColors.success)
                              else
                                StatusBadge(label: 'Terlambat', color: AppColors.danger),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── GPS Toggle ─────────────────────
                        SectionCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (_useGps ? AppColors.primary : AppColors.textMuted)
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _useGps
                                      ? Icons.gps_fixed_rounded
                                      : Icons.gps_off_rounded,
                                  color: _useGps ? AppColors.primary : AppColors.textMuted,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Gunakan GPS', style: AppText.body1),
                                    Text(
                                      _useGps ? 'Lokasi akan dicatat' : 'Tanpa lokasi',
                                      style: AppText.body2,
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _useGps,
                                onChanged: (v) => setState(() {
                                  _useGps = v;
                                  if (!v) _locationLabel = '';
                                }),
                              ),
                            ],
                          ),
                        ),

                        if (_useGps) ...[
                          const SizedBox(height: 12),
                          SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.location_on_rounded,
                                        color: AppColors.danger, size: 16),
                                    const SizedBox(width: 6),
                                    Text('Lokasi Sekarang', style: AppText.label),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: _isLoadingLocation ? null : _fetchLocation,
                                      icon: _isLoadingLocation
                                          ? const SizedBox(
                                              width: 14, height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2, color: AppColors.primary,
                                              ))
                                          : const Icon(Icons.refresh_rounded,
                                              size: 14, color: AppColors.primary),
                                      label: Text(
                                        _isLoadingLocation ? 'Mencari...' : 'Perbarui',
                                        style: const TextStyle(
                                            color: AppColors.primary, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (_isLoadingLocation)
                                  const ShimmerBox(width: double.infinity, height: 14)
                                else if (_locationLabel.isEmpty)
                                  Text('Tekan "Perbarui" untuk mendapatkan lokasi',
                                      style: AppText.body2)
                                else
                                  FadeTransition(
                                    opacity: _locationFade,
                                    child: Text(_locationLabel,
                                        style: AppText.body1
                                            .copyWith(fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // ── Main button / state ──────────────
                        if (!_isWorkDay)
                          SectionCard(
                            child: Column(
                              children: [
                                const Icon(Icons.weekend_rounded,
                                    color: AppColors.warning, size: 36),
                                const SizedBox(height: 10),
                                Text('Hari Libur',
                                    style: AppText.headline3
                                        .copyWith(color: AppColors.warning)),
                                const SizedBox(height: 4),
                                Text(
                                  'Check-in hanya tersedia pada hari kerja (Senin–Jumat)',
                                  style: AppText.body2,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else if (_checkType == 'checkin' && !_canCheckin)
                          SectionCard(
                            child: Column(
                              children: [
                                const Icon(Icons.timer_outlined,
                                    color: AppColors.primary, size: 36),
                                const SizedBox(height: 10),
                                Text('Belum Waktunya', style: AppText.headline3),
                                const SizedBox(height: 4),
                                Text(
                                  'Check-in tersedia 30 menit sebelum shift (${shift.startTimeStr})',
                                  style: AppText.body2,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          PulseButton(
                            pulseColor: _checkType == 'checkin'
                                ? AppColors.primary
                                : AppColors.teal,
                            size: 180,
                            onTap: _performCheckin,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                color: _checkType == 'checkin'
                                    ? AppColors.primary
                                    : AppColors.teal,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _checkType == 'checkin'
                                        ? Icons.login_rounded
                                        : Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 44,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _checkType == 'checkin' ? 'Check-in' : 'Check-out',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // ── Late warning ────────────────────
                        if (_isLate && _checkType == 'checkin')
                          SectionCard(
                            borderColor: AppColors.danger.withOpacity(0.4),
                            color: AppColors.danger.withOpacity(0.08),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: AppColors.danger, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Keterlambatan',
                                          style: AppText.label
                                              .copyWith(color: AppColors.danger)),
                                      Text(
                                        'Kamu terlambat $_lateMinutes menit dari jadwal shift',
                                        style: AppText.body2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Success Overlay ─────────────────────────────
          if (_showSuccess)
            Positioned.fill(
              child: FadeTransition(
                opacity: _successFade,
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: ScaleTransition(
                      scale: _successScale,
                      child: SectionCard(
                        padding: const EdgeInsets.all(36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isEarly || _lateMinutes == 0)
                              const Text('😊', style: TextStyle(fontSize: 64))
                            else
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _checkType == 'checkin'
                                      ? AppColors.primary
                                      : AppColors.teal,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 40),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              _checkType == 'checkin'
                                  ? (_isEarly || _lateMinutes == 0
                                      ? '🎉 Tepat Waktu!'
                                      : 'Check-in Berhasil!')
                                  : 'Check-out Berhasil!',
                              style: AppText.headline3,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _checkType == 'checkin'
                                  ? (_isEarly || _lateMinutes == 0
                                      ? 'Kamu datang tepat waktu. Semangat! 💪'
                                      : 'Terlambat $_lateMinutes menit. Lebih awal besok ya!')
                                  : 'Thank you for today! Istirahat yang baik. 🌙',
                              style: AppText.body2,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
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
}

// ── Type Toggle Button ────────────────────────────────────────
class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _TypeBtn({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Clock Card ────────────────────────────────────────────────
class _ClockCard extends StatelessWidget {
  final String time;
  final String date;
  final bool isLate;
  final bool isEarly;
  final int lateMinutes;

  const _ClockCard({
    required this.time,
    required this.date,
    required this.isLate,
    required this.isEarly,
    required this.lateMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final borderC = isLate
        ? AppColors.danger.withOpacity(0.4)
        : AppColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: isLate
            ? AppColors.danger.withOpacity(0.07)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderC),
      ),
      child: Column(
        children: [
          Text(date, style: AppText.body2),
          const SizedBox(height: 6),
          Text(
            time,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: isLate ? AppColors.danger : AppColors.textPrimary,
            ),
          ),
          if (isLate) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_rounded, color: AppColors.danger, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Terlambat $lateMinutes menit',
                  style: GoogleFonts.inter(
                    color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
              ],
            ),
          ] else if (isEarly) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.success, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Lebih awal dari jadwal 👍',
                  style: GoogleFonts.inter(
                    color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}