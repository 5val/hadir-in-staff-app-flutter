import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'main_screen.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with TickerProviderStateMixin {
  final UserProfile user  = SampleData.currentUser;
  final ShiftModel  shift = SampleData.morningShift;

  bool   _useGps           = true;
  bool   _isLoadingLocation = false;
  bool   _showSuccess       = false;
  bool   _showMascot        = false;
  String _locationLabel     = '';
  DateTime _now = DateTime.now();
  Timer?   _clockTimer;

  // ── Auto check-type cutoff ───────────────────────────────
  /// Jam berapa sistem beralih otomatis ke check-out.
  /// Sebelum jam ini → hanya bisa check-in.
  /// Setelah/tepat jam ini → hanya bisa check-out (check-in dikunci).
  static const int _checkoutCutoffHour = 12; // 12:00 siang

  /// True jika sudah lewat cutoff hour — check-in tidak bisa lagi.
  bool get _pastCutoff => _now.hour >= _checkoutCutoffHour;

  /// Tipe aktif berdasarkan waktu sekarang (bukan pilihan manual).
  /// Sebelum 12:00 → checkin; Setelah 12:00 → checkout.
  String get _autoCheckType => _pastCutoff ? 'checkout' : 'checkin';

  late AnimationController _successCtrl, _locationCtrl;
  late Animation<double>   _successScale, _successFade, _locationFade;

  @override
  void initState() {
    super.initState();
    _successCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _locationCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _successScale = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut));
    _successFade  = CurvedAnimation(parent: _successCtrl, curve: Curves.easeIn);
    _locationFade = CurvedAnimation(parent: _locationCtrl, curve: Curves.easeIn);
    _clockTimer   = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _successCtrl.dispose(); _locationCtrl.dispose();
    super.dispose();
  }

  bool get _isWorkDay => _now.weekday >= 1 && _now.weekday <= 5;
  bool get _canCheckin {
    if (!_isWorkDay) return false;
    final start = DateTime(_now.year, _now.month, _now.day,
        shift.startTime.hour, shift.startTime.minute);
    return _now.isAfter(start.subtract(const Duration(minutes: 30)));
  }
  int  get _lateMinutes {
    final start = DateTime(_now.year, _now.month, _now.day,
        shift.startTime.hour, shift.startTime.minute);
    return _now.isBefore(start) ? 0 : _now.difference(start).inMinutes;
  }
  bool get _isLate  => _lateMinutes > 0;
  bool get _isEarly => _now.isBefore(DateTime(_now.year, _now.month, _now.day,
      shift.startTime.hour, shift.startTime.minute));

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:${dt.second.toString().padLeft(2,'0')}';

  String _fmtDate(DateTime dt) {
    const days   = ['','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    const months = ['','Januari','Februari','Maret','April','Mei','Juni',
                    'Juli','Agustus','September','Oktober','November','Desember'];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  // ── Cutoff info banner ───────────────────────────────────
  Widget _buildCutoffBanner() {
    if (_pastCutoff) {
      // Setelah jam 12: banner bahwa hanya checkout yang tersedia
      return SectionCard(
        color: AppColors.brandNavy.withOpacity(0.05),
        borderColor: AppColors.brandNavy.withOpacity(0.2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.brandNavy.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule_rounded,
                  color: AppColors.brandNavy, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode Check-out Aktif',
                    style: AppText.label.copyWith(color: AppColors.brandNavy),
                  ),
                  Text(
                    'Sudah lewat pukul $_checkoutCutoffHour:00 — hanya check-out yang tersedia.',
                    style: AppText.body2,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Sebelum jam 12: info bahwa check-in aktif
      return SectionCard(
        color: AppColors.brandLime.withOpacity(0.06),
        borderColor: AppColors.brandLimeDark.withOpacity(0.25),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.brandLimeDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.login_rounded,
                  color: AppColors.brandLimeDark, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode Check-in Aktif',
                    style: AppText.label.copyWith(color: AppColors.brandLimeDark),
                  ),
                  Text(
                    'Check-out tersedia setelah pukul $_checkoutCutoffHour:00 siang.',
                    style: AppText.body2,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _fetchLocation() async {
    setState(() { _isLoadingLocation = true; _locationLabel = ''; });
    _locationCtrl.reset();
    await Future.delayed(const Duration(milliseconds: 1500));
    const locs = [
      'Jl. Sudirman No. 12, Kel. Karet Tengsin, Jakarta Pusat',
      'Jl. Gatot Subroto No. 5, Kel. Menteng Atas, Jakarta Selatan',
      'Jl. HR Rasuna Said Kav. 1, Kel. Kuningan Timur',
    ];
    if (mounted) {
      setState(() {
        _locationLabel     = locs[DateTime.now().second % 3];
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

    if (_autoCheckType == 'checkin' && (_isEarly || _lateMinutes == 0)) {
      // Check-in tepat waktu / lebih awal → tampilkan maskot melambai
      _successCtrl.reverse().then((_) {
        setState(() { _showSuccess = false; _showMascot = true; });
      });
    } else {
      // Check-in terlambat ATAU check-out → langsung ke HomeScreen
      _successCtrl.reverse().then((_) {
        setState(() => _showSuccess = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // AppBar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: AppColors.white,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: AppColors.slate700),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Image.asset(AppAssets.logoIcon, height: 28),
                      const SizedBox(width: 8),
                      Text('Absensi', style: AppText.headline3),
                      const Spacer(),
                      // Type toggle
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Row(
                          children: [
                            _TypeBtn(
                              label: 'Check-in',
                              selected: _autoCheckType == 'checkin',
                              enabled: !_pastCutoff,
                              color: AppColors.brandNavy,
                            ),
                            _TypeBtn(
                              label: 'Check-out',
                              selected: _autoCheckType == 'checkout',
                              enabled: _pastCutoff,
                              color: AppColors.brandNavy,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.slate200),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // Clock
                        _ClockCard(
                          time: _fmtTime(_now), date: _fmtDate(_now),
                          isLate: _isLate, isEarly: _isEarly,
                          lateMinutes: _lateMinutes,
                        ),

                        const SizedBox(height: 14),

                        // ── Auto cutoff info banner ─────────
                        _buildCutoffBanner(),

                        const SizedBox(height: 14),

                        // Shift info
                        SectionCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.brandNavy.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.schedule_rounded,
                                    color: AppColors.brandNavy, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(shift.name, style: AppText.label),
                                    Text('${shift.startTimeStr} — ${shift.endTimeStr}',
                                        style: AppText.body1.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.slate900)),
                                  ],
                                ),
                              ),
                              if (!_isWorkDay)
                                StatusBadge(label: 'Libur', color: AppColors.warning)
                              else if (_isEarly)
                                StatusBadge(label: 'Lebih Awal', color: AppColors.brandLimeDark)
                              else if (_lateMinutes == 0)
                                StatusBadge(label: 'Tepat Waktu', color: AppColors.brandLimeDark)
                              else
                                StatusBadge(label: 'Terlambat', color: AppColors.danger),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // GPS toggle
                        SectionCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (_useGps ? AppColors.brandCyanDark : AppColors.slate400)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _useGps ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                                  color: _useGps ? AppColors.brandCyanDark : AppColors.slate400,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Gunakan GPS', style: AppText.body1),
                                    Text(_useGps ? 'Lokasi akan dicatat' : 'Tanpa lokasi',
                                        style: AppText.body2),
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
                          const SizedBox(height: 10),
                          SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded,
                                        color: AppColors.danger, size: 16),
                                    const SizedBox(width: 6),
                                    Text('Lokasi Sekarang', style: AppText.label),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: _isLoadingLocation ? null : _fetchLocation,
                                      icon: _isLoadingLocation
                                          ? const SizedBox(width: 12, height: 12,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2, color: AppColors.brandNavy))
                                          : const Icon(Icons.refresh_rounded,
                                              size: 13, color: AppColors.brandNavy),
                                      label: Text(
                                        _isLoadingLocation ? 'Mencari...' : 'Perbarui',
                                        style: const TextStyle(
                                            color: AppColors.brandNavy, fontSize: 12),
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
                                        style: AppText.body1.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.slate900)),
                                  ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Main button / state
                        if (!_isWorkDay)
                          SectionCard(
                            color: AppColors.warning.withOpacity(0.07),
                            borderColor: AppColors.warning.withOpacity(0.3),
                            child: Column(
                              children: [
                                const Icon(Icons.weekend_rounded,
                                    color: AppColors.warning, size: 36),
                                const SizedBox(height: 8),
                                Text('Hari Libur',
                                    style: AppText.headline3
                                        .copyWith(color: AppColors.warning)),
                                const SizedBox(height: 4),
                                Text('Check-in hanya tersedia pada hari kerja (Senin–Jumat)',
                                    style: AppText.body2, textAlign: TextAlign.center),
                              ],
                            ),
                          )
                        else if (_autoCheckType == 'checkin' && !_canCheckin)
                          SectionCard(
                            color: AppColors.brandNavy.withOpacity(0.05),
                            borderColor: AppColors.brandNavy.withOpacity(0.2),
                            child: Column(
                              children: [
                                const Icon(Icons.timer_outlined,
                                    color: AppColors.brandNavy, size: 36),
                                const SizedBox(height: 8),
                                Text('Belum Waktunya', style: AppText.headline3),
                                const SizedBox(height: 4),
                                Text(
                                  'Check-in tersedia 30 menit sebelum shift (${shift.startTimeStr})',
                                  style: AppText.body2, textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          PulseButton(
                            pulseColor: _autoCheckType == 'checkin'
                                ? AppColors.brandNavy
                                : AppColors.brandCyanDark,
                            size: 180,
                            onTap: _performCheckin,
                            child: Container(
                              width: 160, height: 160,
                              decoration: BoxDecoration(
                                color: _autoCheckType == 'checkin'
                                    ? AppColors.brandNavy
                                    : AppColors.brandCyanDark,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_autoCheckType == 'checkin'
                                            ? AppColors.brandNavy
                                            : AppColors.brandCyanDark)
                                        .withOpacity(0.3),
                                    blurRadius: 24, spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _autoCheckType == 'checkin'
                                        ? Icons.login_rounded
                                        : Icons.logout_rounded,
                                    color: Colors.white, size: 44,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _autoCheckType == 'checkin' ? 'Check-in' : 'Check-out',
                                    style: GoogleFonts.inter(
                                      color: Colors.white, fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 14),

                        if (_isLate && _autoCheckType == 'checkin')
                          SectionCard(
                            color: AppColors.danger.withOpacity(0.05),
                            borderColor: AppColors.danger.withOpacity(0.3),
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
                                      Text('Kamu terlambat $_lateMinutes menit dari jadwal shift',
                                          style: AppText.body2),
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

          // Success overlay
          if (_showSuccess)
            Positioned.fill(
              child: FadeTransition(
                opacity: _successFade,
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: ScaleTransition(
                      scale: _successScale,
                      child: SectionCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _autoCheckType == 'checkin'
                                    ? AppColors.brandNavy
                                    : AppColors.brandCyanDark,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _autoCheckType == 'checkin'
                                  ? (_isEarly || _lateMinutes == 0
                                      ? '🎉 Tepat Waktu!'
                                      : 'Check-in Berhasil!')
                                  : 'Check-out Berhasil!',
                              style: AppText.headline3,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _autoCheckType == 'checkin'
                                  ? (_isEarly || _lateMinutes == 0
                                      ? 'Kamu datang tepat waktu. Semangat! 💪'
                                      : 'Terlambat $_lateMinutes menit. Lebih awal besok ya!')
                                  : 'Terima kasih! Istirahat yang baik. 🌙',
                              style: AppText.body2, textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Mascot overlay for on-time check-in
          if (_showMascot)
            Positioned.fill(
              child: MascotOverlay(
                wave: true,
                message: 'Tepat Waktu!\nSemangat hari ini 🎉',
                onDismiss: () {
                  setState(() => _showMascot = false);
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const MainScreen()));
                },
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
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;

  const _TypeBtn({
    required this.label,
    required this.selected,
    required this.color,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // Tampilkan tooltip kalau button dikunci
      message: !enabled
          ? (label == 'Check-in'
              ? 'Tidak bisa check-in setelah pukul 12:00'
              : 'Tidak bisa check-out sebelum pukul 12:00')
          : '',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!enabled && !selected)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.lock_rounded,
                      size: 10, color: AppColors.slate400),
                ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : (!enabled ? AppColors.slate300 : AppColors.slate400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Clock Card ────────────────────────────────────────────────
class _ClockCard extends StatelessWidget {
  final String time, date;
  final bool isLate, isEarly;
  final int lateMinutes;
  const _ClockCard({required this.time, required this.date,
      required this.isLate, required this.isEarly, required this.lateMinutes});

  @override
  Widget build(BuildContext context) {
    final borderC = isLate
        ? AppColors.danger.withOpacity(0.3)
        : AppColors.brandNavy.withOpacity(0.15);
    final bgC = isLate
        ? AppColors.danger.withOpacity(0.04)
        : AppColors.brandNavy.withOpacity(0.03);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: bgC,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderC),
      ),
      child: Column(
        children: [
          Text(date, style: AppText.body2),
          const SizedBox(height: 6),
          Text(
            time,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 40, fontWeight: FontWeight.w800,
              color: isLate ? AppColors.danger : AppColors.brandNavy,
            ),
          ),
          if (isLate) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.warning_rounded, color: AppColors.danger, size: 14),
              const SizedBox(width: 4),
              Text('Terlambat $lateMinutes menit',
                  style: GoogleFonts.inter(
                      color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ] else if (isEarly) ...[
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star_rounded, color: AppColors.brandLimeDark, size: 14),
              const SizedBox(width: 4),
              Text('Lebih awal dari jadwal 👍',
                  style: GoogleFonts.inter(
                      color: AppColors.brandLimeDark, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ],
        ],
      ),
    );
  }
}