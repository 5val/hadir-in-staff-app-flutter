
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../models/slip_filter.dart';
import 'slip_bukti_screen.dart';
import '../services/salary_service.dart';
import '../services/api_client.dart';
import '../services/google_drive_service.dart';
import '../services/slip_drive_sync.dart';
import '../services/slip_deep_link.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ATTENTION PULSE -- animasi perhatian singkat pada kartu yang butuh tindakan
// ─────────────────────────────────────────────────────────────────────────────
/// Menskalakan [child] 1.0 -> 1.08 -> 1.0 sebanyak [pulses] kali (total
/// [duration], <= 3 s) lalu diam. Animasi baru DIMULAI saat kartu benar-benar
/// terlihat: tab-nya aktif (`TickerMode.of`, false selagi disembunyikan
/// IndexedStack) DAN kartu berada di dalam viewport scroll (diperiksa ulang
/// saat di-scroll). Hanya sekali per instance; [onPlayed] dipanggil saat
/// animasi dimulai supaya pemanggil bisa mencatat "sudah tampil".
/// Dilewati bila [play] false atau sistem meminta animasi dimatikan.
class AttentionPulse extends StatefulWidget {
  const AttentionPulse({
    super.key,
    required this.child,
    this.play = true,
    this.onPlayed,
    this.pulses = 2,
    this.duration = const Duration(milliseconds: 2400),
    this.peakScale = 1.08,
  });

  final Widget child;
  final bool play;
  final VoidCallback? onPlayed;
  final int pulses;
  final Duration duration;
  final double peakScale;

  @override
  State<AttentionPulse> createState() => _AttentionPulseState();
}

class _AttentionPulseState extends State<AttentionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _scale = TweenSequence<double>([
    for (var i = 0; i < widget.pulses; i++) ...[
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: widget.peakScale)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: widget.peakScale, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 1),
    ]
  ]).animate(_c);
  bool _done = false;
  ScrollPosition? _pos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _pos) {
      _pos?.removeListener(_tryStart);
      _pos = pos;
      _pos?.addListener(_tryStart);
    }
    // TickerMode.of (di build) mendaftarkan dependensi: method ini dipanggil
    // lagi saat tab menjadi aktif.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryStart());
  }

  bool _isOnScreen() {
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return false;
    final rect = ro.localToGlobal(Offset.zero) & ro.size;
    final sro = Scrollable.maybeOf(context)?.context.findRenderObject();
    final Rect bounds = (sro is RenderBox && sro.attached && sro.hasSize)
        ? sro.localToGlobal(Offset.zero) & sro.size
        : Offset.zero & MediaQuery.of(context).size;
    final inter = rect.intersect(bounds);
    return inter.width > 0 && inter.height >= rect.height * 0.5;
  }

  void _tryStart() {
    if (_done || !mounted || !widget.play) return;
    if (!TickerMode.of(context)) return; // tab tersembunyi
    if (!_isOnScreen()) return;
    _done = true;
    _pos?.removeListener(_tryStart);
    if (MediaQuery.of(context).disableAnimations) return;
    widget.onPlayed?.call();
    _c.forward();
  }

  @override
  void dispose() {
    _pos?.removeListener(_tryStart);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TickerMode.of(context); // pastikan dependensi terdaftar
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BATAL SETUJU DIALOG
// ─────────────────────────────────────────────────────────────────────────────
/// Dialog alasan pembatalan persetujuan. Mengembalikan alasan (trim) lewat
/// `Navigator.pop`; tombol aktif bila panjang alasan 5-300 karakter (batas
/// server).
class BatalSetujuDialog extends StatefulWidget {
  const BatalSetujuDialog({super.key});

  @override
  State<BatalSetujuDialog> createState() => _BatalSetujuDialogState();
}

class _BatalSetujuDialogState extends State<BatalSetujuDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Panjang dihitung dalam unit UTF-16 (Dart `String.length`) -- sama
    // dengan `.length` JS di server -- bukan jumlah grapheme.
    final len = _ctrl.text.trim().length;
    final ok = len >= SalaryService.batalAlasanMin &&
        len <= SalaryService.batalAlasanMax;
    return AlertDialog(
      title: const Text('Batalkan persetujuan?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Slip akan dikembalikan ke HR untuk diperbaiki. Tulis alasannya.'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('batal-alasan'),
            controller: _ctrl,
            maxLines: 3,
            inputFormatters: [
              Utf16LengthLimitingFormatter(SalaryService.batalAlasanMax),
            ],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  'Alasan (minimal ${SalaryService.batalAlasanMin} karakter)',
              border: const OutlineInputBorder(),
              // Hitungan sama persis dengan yang divalidasi server.
              counterText: '$len/${SalaryService.batalAlasanMax}',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kembali')),
        FilledButton(
          key: const Key('batal-kirim'),
          onPressed: ok ? () => Navigator.pop(context, _ctrl.text.trim()) : null,
          child: const Text('Batalkan persetujuan'),
        ),
      ],
    );
  }
}

/// Membatasi panjang input dalam unit UTF-16 (bukan grapheme seperti
/// `LengthLimitingTextInputFormatter`), cocok dengan validasi JS `.length`
/// di server. Pemotongan tidak pernah memisahkan pasangan surrogate.
class Utf16LengthLimitingFormatter extends TextInputFormatter {
  Utf16LengthLimitingFormatter(this.max);
  final int max;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.length <= max) return newValue;
    var cut = max;
    final last = t.codeUnitAt(cut - 1);
    if (last >= 0xD800 && last <= 0xDBFF) cut--; // jangan belah surrogate
    return TextEditingValue(
      text: t.substring(0, cut),
      selection: TextSelection.collapsed(offset: cut),
    );
  }
}

/// Urutkan slip terbaru dulu (akhir periode, lalu awal periode) dan batasi ke
/// [months] bulan terakhir dihitung dari [now]. Slip `menunggu_konfirmasi`
/// selalu ikut. Server mengurutkan memakai teks `periode`, yang menaruh
/// "2026-W40" selalu di atas "2026-10", jadi urutan harus dibuat ulang di sini.
List<SalarySlip> filterSlipsByMonths(List<SalarySlip> slips, int months,
    {DateTime? now}) {
  final today = now ?? DateTime.now();
  final cutoff = DateTime(today.year, today.month - months, today.day);
  final sorted = [...slips]..sort((a, b) {
      final byEnd = b.periodEnd.compareTo(a.periodEnd);
      return byEnd != 0 ? byEnd : b.periodStart.compareTo(a.periodStart);
    });
  return sorted
      .where((s) => s.perluKonfirmasi || !s.periodEnd.isBefore(cutoff))
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// SALARY SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key, required this.isFromAccount});
  final bool isFromAccount;

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final user = SampleData.currentUser;

  // Slip gaji asli dari backend.
  List<SalarySlip> _slips = [];
  bool _loading = true;
  String? _error;

  // Filter periode: null = "Semua periode"; selain itu `periodeKey` slip.
  String? _periodeKey;

  // Animasi perhatian: sekali per slip per sesi app (bukan per layar/rebuild);
  // dicatat saat animasi benar-benar mulai (kartu terlihat).
  static final Set<String> _pulsedIds = <String>{};

  List<SalarySlip> get _filteredSlips => SlipFilter.apply(_slips, _periodeKey);

  @override
  void initState() {
    super.initState();
    SlipDeepLink.pending.addListener(_onDeepLink);
    _load();
  }

  @override
  void dispose() {
    SlipDeepLink.pending.removeListener(_onDeepLink);
    super.dispose();
  }

  /// Notifikasi slip diketuk: muat ulang diam-diam (slip baru mungkin belum
  /// ada di daftar), lalu buka detailnya. Tidak ketemu -> tetap di daftar.
  Future<void> _onDeepLink() async {
    if (SlipDeepLink.pending.value == null) return;
    await _load(silent: true);
    _openPendingSlip();
  }

  void _openPendingSlip() {
    final id = SlipDeepLink.pending.value;
    if (id == null || !mounted || _loading) return;
    SlipDeepLink.pending.value = null; // dikonsumsi
    final slip = SlipDeepLink.resolve(_slips, id);
    if (slip == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SalaryDetailScreen(slip: slip, user: user)),
    ).then((_) {
      if (mounted) _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await SalaryService.mySlips();
      if (!mounted) return;
      setState(() {
        _slips = list;
        _loading = false;
        _error = null;
        // Periode yang dipilih bisa hilang setelah muat ulang -> kembali ke semua.
        if (_periodeKey != null &&
            !list.any((e) => e.periodeKey == _periodeKey)) {
          _periodeKey = null;
        }
      });
      // Slip yang sudah terkunci disimpan ke Google Drive staff di latar
      // (hanya bila akun Google sudah tersambung; tidak pernah memunculkan
      // dialog login). Tombol manual ada di layar detail.
      SlipDriveSync.autoSyncLocked(list);
      if (!silent) _openPendingSlip(); // permintaan yang datang sebelum daftar siap
    } on ApiException catch (e) {
      // Gagal memuat: permintaan buka-slip lama tidak boleh menggantung dan
      // terbuka pada muat ulang lain yang tidak berkaitan.
      SlipDeepLink.pending.value = null;
      if (silent) return; // muat ulang diam-diam tidak boleh menimpa daftar

      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Widget _buildErrorState() {
    return PullToRefresh(
      onRefresh: _load,
      child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.slate400),
            const SizedBox(height: 12),
            Text(_error ?? 'Gagal memuat slip gaji',
                textAlign: TextAlign.center, style: AppText.body2),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            const Text('📄', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text('Belum ada slip gaji',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            const SizedBox(height: 4),
            Text('Slip gaji akan muncul setelah diterbitkan HR.',
                textAlign: TextAlign.center, style: AppText.body2),
          ],
        ),
      ),
    );
  }

  String _fmtCurrency(int amount) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);

  String _fmtCurrencyShort(int amount) {
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return 'Rp ${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)}jt';
    }
    if (amount >= 1000) return 'Rp ${(amount / 1000).toStringAsFixed(0)}rb';
    return _fmtCurrency(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──────────────────────────────────
            Container(
              color: AppColors.brandNavy,
              padding: widget.isFromAccount
                  ? const EdgeInsets.fromLTRB(4, 16, 20, 16)
                  : const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  if (widget.isFromAccount)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FINANCIAL STATEMENT',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                            letterSpacing: 1.2,
                          )),
                      Text('Gaji Saya',
                          style: AppText.headline2
                              .copyWith(color: AppColors.white)),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.slate200),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brandNavy))
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          color: AppColors.brandNavy,
                          onRefresh: () => _load(silent: true),
                          child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          children: [
                            _buildFilterChips(),
                            const SizedBox(height: 16),
                            if (_slips.isEmpty)
                              _buildEmptyState()
                            else
                              ..._filteredSlips.map((slip) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildSalaryCard(slip),
                                  )),
                          ],
                        ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter Chips ────────────────────────────────────────────
  // "Semua periode" + daftar periode sesuai tipe penggajian staff saat ini
  // (Harian / Mingguan / Bulanan). Slip bertipe lama tetap terjangkau lewat
  // "Semua periode".
  Widget _buildFilterChips() {
    final options = <(String?, String)>[
      (null, 'Semua periode'),
      ...SlipFilter.periodeOptions(_slips,
          profileType: AppSession.staff?.jabatanPeriodeGaji).map((o) => (o.key, o.label)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filter Periode', style: AppText.label),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((opt) {
              final isSelected = _periodeKey == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  key: Key('slip-filter-${opt.$1 ?? 'semua'}'),
                  onTap: () => setState(() => _periodeKey = opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.brandNavy : AppColors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandNavy
                            : AppColors.slate200,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.brandNavy.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check_rounded,
                              size: 13, color: AppColors.brandLime),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          opt.$2,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.white
                                : AppColors.slate600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Salary Card (clickable, no Lihat Detail button) ──────────
  Widget _buildSalaryCard(SalarySlip slip) {
    final card = _buildSalaryCardBody(slip);
    if (!slip.perluAksi) return card;
    return AttentionPulse(
      key: ValueKey('pulse-${slip.id}'),
      play: !_pulsedIds.contains(slip.id),
      onPlayed: () => _pulsedIds.add(slip.id),
      child: card,
    );
  }

  Widget _buildSalaryCardBody(SalarySlip slip) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SalaryDetailScreen(
              slip: slip,
              user: user,
            ),
          ),
        );
        // Status slip bisa berubah di layar detail (konfirmasi/tolak).
        if (mounted) _load(silent: true);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brandNavy,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(slip.periodeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      )),
                ),
                const SizedBox(width: 8),
                Flexible(child: _statusChip(slip)),
                // Tap hint — subtle, no dedicated button
                // Row(
                //   children: [
                //     Text('Ketuk untuk detail',
                //         style: GoogleFonts.inter(
                //           fontSize: 10,
                //           color: Colors.white.withOpacity(0.5),
                //         )),
                //     const SizedBox(width: 4),
                //     Icon(Icons.touch_app_rounded,
                //         size: 13, color: Colors.white.withOpacity(0.45)),
                //   ],
                // ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text('Total Take Home Pay',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.75),
                )),
            const SizedBox(height: 6),
            Text(
              _fmtCurrency(slip.netSalary),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            // Rincian pencairan (tanggal & nama admin) hanya setelah dicairkan.
            if (slip.pencairanDetail != null) ...[
              const SizedBox(height: 10),
              Text(slip.pencairanDetail!,
                  key: const Key('slip-pencairan-label'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandLime)),
            ],
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            //   decoration: BoxDecoration(
            //     color: Colors.white.withOpacity(0.08),
            //     borderRadius: BorderRadius.circular(12),
            //   ),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceAround,
            //     children: [
            //       _miniStat('Pendapatan', _fmtCurrencyShort(slip.totalIncome),
            //           Colors.white),
            //       Container(
            //           width: 1,
            //           height: 28,
            //           color: Colors.white.withOpacity(0.15)),
            //       _miniStat('Potongan', _fmtCurrencyShort(slip.totalDeduction),
            //           const Color(0xFFFCA5A5)),
            //       Container(
            //           width: 1,
            //           height: 28,
            //           color: Colors.white.withOpacity(0.15)),
            //       _miniStat(
            //           'Ditransfer',
            //           DateFormat('dd MMM').format(slip.periodEnd),
            //           AppColors.brandLime),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  /// Status alur konfirmasi di kartu. Slip yang menunggu konfirmasi dibuat
  /// menonjol (lime) supaya staff tahu ada yang harus dilakukan.
  Widget _statusChip(SalarySlip slip) {
    final needsAction = slip.perluAksi;
    final Color bg;
    final Color fg;
    switch (slip.statusSlip) {
      case 'menunggu_konfirmasi':
        bg = AppColors.brandLime;
        fg = AppColors.brandNavy;
        break;
      case 'ditolak':
      case 'draft':
        bg = const Color(0xFFFCA5A5);
        fg = const Color(0xFF7F1D1D);
        break;
      default:
        bg = Colors.white.withOpacity(0.12);
        fg = Colors.white.withOpacity(0.9);
    }
    Widget chip(Color background) => Container(
          key: const Key('slip-status-chip'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: background, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (needsAction) ...[
                Icon(Icons.notifications_active_rounded, size: 12, color: fg),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(slip.statusLabel,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          ),
        );
    // Menunggu konfirmasi: warna chip berkedip 3x saat kartu tampil (fitur
    // 5val); kartunya sendiri berdenyut saat terlihat (AttentionPulse).
    if (!needsAction) return chip(bg);
    return _BlinkThrice(
      key: const Key('slip-status-blink'),
      from: bg,
      to: Colors.white,
      builder: chip,
    );
  }

  // ── Salary Setting ──────────────────────────────────────────
  Widget _buildSalarySetting() {
    // Salary disbursement date — assumed stored on user.position or a fixed value.
    // Using day 25 as example; adjust source field as needed.
    final disbursementDay = user.position.salaryDisbursementDay ?? 25;

    final settings = [
      (
        Icons.account_balance_wallet_rounded,
        'Gaji Pokok',
        _fmtCurrency(user.position.baseSalary),
        'Berdasarkan jabatan ${user.position.name}',
        AppColors.brandNavy
      ),
      (
        Icons.star_rounded,
        'Bonus Harian',
        _fmtCurrency(user.position.dailyBonus),
        'Per hari kerja hadir tepat waktu',
        AppColors.brandLimeDark
      ),
      (
        Icons.favorite_rounded,
        'Tunjangan Kesehatan',
        _fmtCurrency(user.position.healthAllowance),
        'Dibayarkan per bulan',
        AppColors.danger
      ),
      (
        Icons.directions_car_rounded,
        'Tunjangan Transport',
        _fmtCurrency(user.position.transportAllowance),
        'Dibayarkan per bulan',
        const Color(0xFF374151)
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.settings_rounded,
                color: AppColors.brandNavy, size: 18),
            const SizedBox(width: 8),
            Text('Detail Gaji Saya',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Detail gaji berdasarkan jabatan dan penggajian yang berlaku',
          style: AppText.body2,
        ),
        const SizedBox(height: 10),
        // ── Disbursement date info banner ──────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.brandNavy.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.brandNavy.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandNavy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.event_available_rounded,
                    color: AppColors.brandNavy, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Jadwal Pencairan Gaji',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandNavy,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      'Gaji dicairkan setiap tanggal $disbursementDay setiap bulannya',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.slate600),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.brandNavy,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Setiap Tanggal $disbursementDay',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: settings.map((s) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slate200),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandNavy.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: s.$5.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(s.$1, color: s.$5, size: 18),
                  ),
                  const Spacer(),
                  Text(s.$2,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate700,
                      ),
                      maxLines: 2),
                  const SizedBox(height: 2),
                  Text(s.$3,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate900,
                      )),
                  const SizedBox(height: 3),
                  Text(s.$4,
                      style: GoogleFonts.inter(
                          fontSize: 9, color: AppColors.slate400),
                      maxLines: 2),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SALARY DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SalaryDetailScreen extends StatefulWidget {
  const SalaryDetailScreen({
    super.key,
    required this.slip,
    required this.user,
    this.batalSetujuCall,
    this.slipLoader,
  });

  final SalarySlip slip;
  final UserProfile user;

  /// Hanya untuk test: pengganti `SalaryService.batalSetuju` / `slipById`.
  final Future<void> Function(String slipId, String alasan,
      {String? dikirimKonfirmasiAt})? batalSetujuCall;
  final Future<SalarySlip> Function(String slipId)? slipLoader;

  @override
  State<SalaryDetailScreen> createState() => _SalaryDetailScreenState();
}

class _SalaryDetailScreenState extends State<SalaryDetailScreen> {
  // Status slip bisa berubah di layar ini (staff menekan Konfirmasi/Tolak), jadi
  // salinan yang diperbarui disimpan di state dan seluruh isi layar membacanya.
  late SalarySlip slip = widget.slip;
  UserProfile get user => widget.user;

  bool _busy = false;
  bool? _savedToDrive;

  @override
  void initState() {
    super.initState();
    if (slip.bisaUnduh) {
      SlipDriveSync.isSaved(slip.id).then((v) {
        if (mounted) setState(() => _savedToDrive = v);
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _fmt(int amount) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);

  // ── PDF: dari server, template yang sama dengan email HR ─────────
  //
  // Dulu app menyusun PDF-nya sendiri di HP (template kedua yang berbeda dari
  // PDF server). Sekarang yang diunduh adalah PDF yang dirender server, jadi
  // tampilan, identitas (NPWP/BPJS) dan angkanya identik di mana pun.
  Future<void> _downloadPdf(BuildContext context) async {
    if (!slip.bisaUnduh || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await SalaryService.downloadPdf(slip.id);
      await Printing.sharePdf(bytes: bytes, filename: SlipDriveSync.filenameFor(slip));
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveToDrive() async {
    if (!slip.bisaUnduh || _busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await SlipDriveSync.save(slip, interactive: true);
      if (!mounted) return;
      setState(() => _savedToDrive = true);
      _snack(outcome == DriveSaveOutcome.alreadySaved
          ? 'Slip ini sudah ada di Google Drive Anda.'
          : 'Slip disimpan ke Google Drive Anda (folder "Hadir-In - Slip Gaji").');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Konfirmasi / tolak slip ───────────────────────────────
  Future<void> _konfirmasi() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi slip gaji?'),
        content: Text(
            'Dengan mengonfirmasi, Anda menyatakan angka di slip ${slip.period} sudah benar. '
            'Setelah itu HR akan mengunci slip dan gaji bisa dicairkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, sudah benar')),
        ],
      ),
    );
    if (ok != true || _busy) return;

    setState(() => _busy = true);
    try {
      final result = await SalaryService.konfirmasi(slip.id,
          dikirimKonfirmasiAt: slip.dikirimKonfirmasiAt);
      if (!mounted) return;
      // Status datang dari server (sekarang `terkunci`), bukan hardcode.
      final updated = result.applyTo(slip);
      setState(() => slip = updated);
      if (updated.bisaUnduh) {
        _snack('Slip dikonfirmasi dan sudah final. Anda bisa mengunduhnya.');
        // Sama seperti sinkron otomatis di daftar: simpan ke Drive di latar
        // (diam bila akun Google belum tersambung).
        SlipDriveSync.autoSyncLocked([updated]).then((_) async {
          final saved = await SlipDriveSync.isSaved(updated.id);
          if (mounted && saved) setState(() => _savedToDrive = true);
        });
      } else {
        _snack('Slip dikonfirmasi. Menunggu HR mengunci slip.');
      }
    } on ApiException catch (e) {
      _snack(e.message);
      _reloadIfStale(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Batalkan persetujuan (D1) ─────────────────────────────
  Future<void> _batalSetuju() async {
    final alasan = await showDialog<String>(
      context: context,
      builder: (ctx) => const BatalSetujuDialog(),
    );
    if (alasan == null || _busy) return;

    setState(() => _busy = true);
    try {
      await (widget.batalSetujuCall ?? SalaryService.batalSetuju)(slip.id, alasan,
          dikirimKonfirmasiAt: slip.dikirimKonfirmasiAt);
      if (!mounted) return;
      setState(() => slip = slip.copyWith(
            statusSlip: 'ditolak',
            alasanTolak: 'Persetujuan dibatalkan staff: ${alasan.trim()}',
            bisaUnduh: false,
            bisaBatalSetuju: false,
            ditolakAt: DateTime.now(), // reject-once: setelah dikirim ulang HR hanya bisa dikonfirmasi
            bisaTolak: false,
            perluAksiServer: false,
          ));
      _snack('Persetujuan dibatalkan. HR akan memperbaiki dan mengirim ulang slip.');
    } on ApiException catch (e) {
      // Pesan server (mis. 409 "sudah disetujui untuk dicairkan") apa adanya.
      // TIDAK menutup layar: tetap di sini dan segarkan status slip dari
      // server (yang mungkin sudah siap cair/dibayar) agar tombol hilang.
      _snack(e.message);
      if (e.statusCode == 409) await _refreshSlip();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshSlip() async {
    try {
      final fresh = await (widget.slipLoader ?? SalaryService.slipById)(slip.id);
      if (mounted) setState(() => slip = fresh);
    } catch (_) {
      // Gagal menyegarkan: biarkan tampilan apa adanya.
    }
  }

  Widget _buildBatalSetujuCard() {
    if (!slip.bisaBatalSetujuEfektif) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ada yang keliru? Selama HR belum menyetujui pencairan, Anda bisa '
            'membatalkan persetujuan. Slip kembali ke HR untuk diperbaiki.',
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.45, color: AppColors.slate600),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('btn-batal-setuju'),
            onPressed: _busy ? null : _batalSetuju,
            icon: const Icon(Icons.undo_rounded, size: 18),
            label: const Text('Batalkan persetujuan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB91C1C),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
            ),
          ),
        ],
      ),
    );
  }

  void _bukaBukti() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SlipBuktiScreen(
        title: 'Bukti pembayaran - ${slip.periodeLabel}',
        loader: () => SalaryService.buktiBayar(slip.id),
      ),
    ));
  }

  /// 409: slip sudah diperbarui HR. Tidak ada perubahan status lokal; tutup
  /// layar detail agar daftar slip memuat ulang (lihat `_buildSalaryCard`).
  void _reloadIfStale(ApiException e) {
    if (SalaryService.isSlipStaleConflict(e) && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  /// Bagian slip yang bisa dicentang staff saat menolak: hanya Gaji Pokok,
  /// Lembur, tiap Tunjangan dan tiap Fasilitas. Baris lain (bonus, THR, uang
  /// makan, pajak, potongan, kehadiran, THP) tidak bisa ditolak.
  List<_TolakItem> _tolakItems() {
    String? sectionOf(SalaryComponent c) {
      if (c.key == 'col:gajiPokok' || c.key == 'col:lemburTotal') {
        return 'Pendapatan Pokok';
      }
      if (c.key.startsWith('tunjangan:')) return 'Tunjangan';
      if (c.key.startsWith('fasilitas:')) return 'Fasilitas';
      return null;
    }

    return [
      for (final c in slip.components)
        if (sectionOf(c) != null)
          _TolakItem(
              key: c.key,
              section: sectionOf(c)!,
              label: c.label,
              amount: _fmt(c.amount)),
    ];
  }

  Future<void> _tolak() async {
    if (!slip.bisaTolak) return;
    final hasil = await showDialog<({String alasan, List<String> bagian})>(
      context: context,
      builder: (ctx) => _TolakSlipDialog(items: _tolakItems()),
    );
    if (hasil == null || _busy) return;
    final alasan = hasil.alasan;

    setState(() => _busy = true);
    try {
      await SalaryService.tolak(slip.id, alasan,
          dikirimKonfirmasiAt: slip.dikirimKonfirmasiAt, bagian: hasil.bagian);
      if (!mounted) return;
      setState(() => slip = slip.copyWith(
            statusSlip: 'ditolak',
            alasanTolak: alasan.trim(),
            bisaTolak: false,
            ditolakAt: DateTime.now(),
            bagianTolak: hasil.bagian,
          ));
      _snack('Slip ditolak. HR akan memeriksa dan merevisinya.');
    } on ApiException catch (e) {
      _snack(e.message);
      _reloadIfStale(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Banner status di atas rincian: menjelaskan apa yang sedang terjadi pada
  /// slip dan apa yang bisa dilakukan staff.
  Widget _buildStatusBanner() {
    final IconData icon;
    final Color bg;
    final Color fg;
    final String title;
    final String body;
    Widget? action;
    switch (slip.statusSlip) {
      case 'menunggu_konfirmasi' when slip.pernahDitolak:
        icon = Icons.published_with_changes_rounded;
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        title = 'Slip sudah direvisi HR';
        body = 'HR sudah memeriksa penolakan Anda dan mengirim ulang slip ini. '
            'Ikon ⓘ merah = bagian yang Anda tolak, ikon ⓘ hijau = hasil revisi '
            'admin/manajer (ketuk untuk melihat detailnya).\n\n'
            'Penolakan hanya bisa dilakukan sekali. Jika masih ada yang tidak '
            'sesuai, hubungi HR secara langsung.';
        action = _buildRevisiList();
        break;
      case 'menunggu_konfirmasi':
        icon = Icons.fact_check_outlined;
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        title = 'Mohon periksa slip ini';
        body = 'HR meminta Anda memeriksa angka di bawah. Jika sudah benar tekan '
            '"Konfirmasi". Jika ada yang salah tekan "Ada yang salah", centang '
            'bagiannya dan tulis alasannya. Penolakan hanya bisa dilakukan sekali. '
            'Slip baru bisa diunduh setelah Anda konfirmasi.';
        break;
      case 'dikonfirmasi':
        // Legacy: sama dengan kartu & slip terkunci -> "Disetujui".
        icon = Icons.verified_rounded;
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        title = 'Disetujui';
        body = 'Anda sudah menyetujui slip ini.';
        break;
      case 'ditolak':
      case 'draft':
        icon = Icons.report_gmailerrorred_rounded;
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        title = slip.sedangDirevisi
            ? 'Anda menolak slip ini, HR sedang merevisi'
            : 'Anda menolak slip ini';
        body = 'HR akan memeriksa dan merevisinya, lalu mengirim ulang untuk Anda konfirmasi. '
            'Bagian yang Anda tolak ditandai ikon ⓘ merah.'
            '${slip.alasanTolakTampil != null ? '\n\nAlasan Anda: ${slip.alasanTolakTampil}' : ''}';
        break;
      default:
        // Banner "Anda menyetujui" (dengan tombol unduh) hanya untuk slip
        // yang memang boleh diunduh menurut server; status lain yang tak
        // dikenal tidak menampilkan apa pun ketimbang tombol yang tidak
        // berfungsi.
        return slip.bisaUnduh ? _buildFinalBanner() : const SizedBox.shrink();
    }
    return _banner(icon, bg, fg, title, body, action: action);
  }

  /// Daftar semua perubahan HR sejak staff menolak -- juga mencakup baris
  /// yang tidak punya tempat di tabel (mis. tunjangan yang dihapus jadi Rp0).
  Widget? _buildRevisiList() {
    if (slip.revisi.isEmpty) return null;
    return Container(
      key: const Key('slip-revisi-list'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in slip.revisi.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.info_rounded,
                        size: 14, color: _InfoMarker.revisiColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        '${r.label}: ${_fmt(r.sebelum)} → ${_fmt(r.sesudah)}',
                        style: GoogleFonts.inter(
                            fontSize: 11.5, color: AppColors.slate800)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Tanda ⓘ: bagian yang ditolak staff (merah) / direvisi HR (hijau) ──
  List<Widget> _markers(List<String> keys) {
    final ditolak = keys.any(slip.ditolakBagian);
    SlipLineRevision? revisi;
    for (final k in keys) {
      revisi ??= slip.revisi[k];
    }
    // Satu ikon saja per baris: hijau bila sudah direvisi (menang atas
    // merah), merah bila hanya ditolak.
    if (revisi != null) {
      final r = revisi;
      return [
        _InfoMarker(
          key: ValueKey('marker-revisi-${keys.first}'),
          color: _InfoMarker.revisiColor,
          tooltip: 'Direvisi admin/manajer',
          onTap: () => _showRevisiInfo(r, sebelumnyaDitolak: ditolak),
        ),
      ];
    }
    if (ditolak) {
      return [
        _InfoMarker(
          key: ValueKey('marker-tolak-${keys.first}'),
          color: _InfoMarker.tolakColor,
          tooltip: 'Bagian yang Anda tolak',
          onTap: _showTolakInfo,
        ),
      ];
    }
    return const [];
  }

  void _showTolakInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_rounded, color: _InfoMarker.tolakColor),
        title: const Text('Bagian yang Anda tolak'),
        content: Text([
          if (slip.ditolakAt != null)
            'Anda menolak slip ini pada ${formatTanggalJam(slip.ditolakAt!)}.',
          if (slip.alasanTolak != null) 'Alasan Anda: ${slip.alasanTolak}',
        ].join('\n\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  void _showRevisiInfo(SlipLineRevision r, {bool sebelumnyaDitolak = false}) {
    final naik = r.sesudah > r.sebelum;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_rounded, color: _InfoMarker.revisiColor),
        title: Text('Direvisi: ${r.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sebelum: ${_fmt(r.sebelum)}',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.slate600,
                    decoration: TextDecoration.lineThrough)),
            const SizedBox(height: 4),
            Text('Sesudah: ${_fmt(r.sesudah)}',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900)),
            Text(
                '${naik ? '+' : '−'} ${_fmt((r.sesudah - r.sebelum).abs())}',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: naik ? _InfoMarker.revisiColor : AppColors.danger)),
            const SizedBox(height: 12),
            Text(
                [
                  'Diubah${r.oleh != null ? ' oleh ${r.oleh}' : ''}'
                      '${r.pada != null ? ' pada ${formatTanggalJam(r.pada!)}' : ''}.',
                  if (r.alasan != null) 'Keterangan: ${r.alasan}',
                  if (sebelumnyaDitolak) 'Bagian ini sebelumnya Anda tolak.',
                ].join('\n'),
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate700)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  /// Status pencairan: "Sedang diproses pencairan" setelah HR menyetujui cair,
  /// "Sudah dicairkan" setelah dibayar. Tidak tampil bila belum ada kabar.
  Widget _buildPencairanBanner() {
    final label = slip.pencairanLabel;
    if (label == null) return const SizedBox.shrink();
    final paid = slip.sudahDicairkan;
    return _banner(
      paid ? Icons.payments_rounded : Icons.hourglass_top_rounded,
      paid ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
      paid ? const Color(0xFF15803D) : const Color(0xFFB45309),
      label,
      paid
          ? [
              'Gaji periode ini sudah ditransfer ke rekening Anda.',
              if (slip.paidAt != null) 'Waktu: ${formatTanggalJam(slip.paidAt!)}',
              if (slip.paidOleh != null) 'Dicairkan oleh: ${slip.paidOleh}',
            ].join('\n')
          : 'HR sudah menyetujui slip ini untuk dicairkan. Gaji akan segera ditransfer.',
      action: slip.tampilCatatanBuktiGabungan
          ? Text('Bukti transfer gabungan disimpan oleh HR',
              key: const Key('bukti-gabungan-note'),
              style: GoogleFonts.inter(
                  fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.slate600))
          : (paid && slip.adaBuktiBayar)
          ? OutlinedButton.icon(
              key: const Key('btn-lihat-bukti'),
              onPressed: _bukaBukti,
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Lihat bukti pembayaran'),
            )
          : null,
    );
  }

  Widget _buildFinalBanner() {
    final saved = _savedToDrive == true;
    return _banner(
      Icons.verified_rounded,
      const Color(0xFFF0FDF4),
      const Color(0xFF15803D),
      'Anda menyetujui slip ini',
      'Slip sudah terkunci dan bisa diunduh.',
      // Wrap, bukan Row: dua tombol berdampingan tidak muat di layar sempit
      // (overflow 100+ px di HP 360dp) dan harus turun ke baris berikutnya.
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _downloadPdf(context),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Unduh PDF'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: (_busy || saved) ? null : _saveToDrive,
            icon: Icon(saved ? Icons.check_circle_rounded : Icons.cloud_upload_outlined, size: 18),
            label: Text(saved ? 'Tersimpan di Drive' : 'Simpan ke Google Drive'),
          ),
        ],
      ),
    );
  }

  Widget _banner(IconData icon, Color bg, Color fg, String title, String body, {Widget? action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: GoogleFonts.inter(fontSize: 12, height: 1.45, color: fg)),
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    );
  }

  /// Bilah aksi di bawah layar selama slip menunggu konfirmasi.
  Widget _buildKonfirmasiBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.slate200)),
        ),
        child: Row(
          children: [
            // Penolakan hanya boleh sekali (server: `bisaTolak`). Setelah HR
            // merevisi & mengirim ulang, staff hanya bisa mengonfirmasi.
            if (slip.bisaTolak) ...[
              Expanded(
                child: OutlinedButton(
                  key: const Key('slip-tolak-button'),
                  onPressed: _busy ? null : _tolak,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Ada yang salah'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _busy ? null : _konfirmasi,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandNavy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Konfirmasi, sudah benar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Fase 8 -- struktur slip mengikuti aturan yang diminta:
    //   Gaji Bersih   = pendapatan pokok (gaji pokok, bonus, lembur, THR) - PPh
    //   Take Home Pay = Gaji Bersih + Tunjangan - Potongan
    // Karena itu rinciannya dipecah 4 kelompok, bukan lagi hanya
    // "pendapatan vs potongan": tunjangan & potongan sekarang berdiri sendiri
    // DI BAWAH gaji bersih.
    final pokok = slip.components
        .where((c) => c.group == SalaryGroup.pendapatanPokok)
        .toList();
    final tunjangan =
        slip.components.where((c) => c.group == SalaryGroup.tunjangan).toList();
    final pajak =
        slip.components.where((c) => c.group == SalaryGroup.pajak).toList();
    final potongan =
        slip.components.where((c) => c.group == SalaryGroup.potongan).toList();

    return Scaffold(
      backgroundColor: AppColors.slate50,
      bottomNavigationBar: slip.perluKonfirmasi ? _buildKonfirmasiBar() : null,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──────────────────────────────────────
            Container(
              color: AppColors.brandNavy,
              padding: const EdgeInsets.fromLTRB(4, 16, 20, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FINANCIAL STATEMENT',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                              letterSpacing: 1.2,
                            )),
                        Row(
                          children: [
                            Flexible(
                              child: Text('Detail Salary',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.headline2
                                      .copyWith(color: AppColors.white)),
                            ),
                            const SizedBox(width: 2),
                            // Legend tahapan, menyorot posisi SLIP INI.
                            IconButton(
                              key: const Key('slip-status-help'),
                              tooltip: 'Tahapan status slip gaji',
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.help_outline_rounded,
                                  color: AppColors.white, size: 20),
                              onPressed: () =>
                                  showSlipStatusGuide(context, slip),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Unduh hanya untuk slip yang sudah dikunci HR (server yang
                  // memutuskan lewat `bisaUnduh`); selama masih konfirmasi
                  // slip ini hanya untuk dilihat.
                  if (slip.bisaUnduh)
                  GestureDetector(
                    onTap: () => _downloadPdf(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.brandLimeDark,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandNavy.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 5),
                          Text('Download PDF',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.slate200),

            // ── Content ──────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.brandNavy,
                onRefresh: _refreshSlip,
                child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  _buildStatusBanner(),
                  _buildBatalSetujuCard(),
                  _buildPencairanBanner(),
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildAttendanceInfo(context),
                  const SizedBox(height: 10),
                  _buildSummaryCard(),
                  const SizedBox(height: 20),

                  // 1. Pendapatan pokok
                  _buildSectionTitle(
                      Icons.trending_up_rounded, 'Pendapatan Pokok'),
                  const SizedBox(height: 8),
                  _buildSalaryTable(pokok, isDeduction: false),

                  // 2. PPh 21 -> menghasilkan GAJI BERSIH
                  if (pajak.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionTitle(Icons.receipt_long_rounded, 'Pajak'),
                    const SizedBox(height: 8),
                    _buildSalaryTable(pajak, isDeduction: true),
                  ],
                  // const SizedBox(height: 12),
                  // _buildLineTotal('Gaji Bersih', slip.gajiBersih,
                  //     'Pendapatan pokok dikurangi PPh 21'),

                  // 3. Tunjangan -- di bawah gaji bersih, sesuai permintaan
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                      Icons.card_giftcard_rounded, 'Tunjangan'),
                  const SizedBox(height: 8),
                  _buildSalaryTable(tunjangan, isDeduction: false),

                  // 4. Potongan -- di bawah gaji bersih, sesuai permintaan
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                      Icons.trending_down_rounded, 'Potongan'),
                  const SizedBox(height: 8),
                  _buildSalaryTable(potongan, isDeduction: true),

                  // 5. Take home pay
                  // const SizedBox(height: 16),
                  // _buildLineTotal('Take Home Pay', slip.takeHomePay,
                  //     highlight: true),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Baris total besar (Gaji Bersih / Take Home Pay).
  Widget _buildLineTotal(String label, int amount, String note,
      {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? AppColors.brandNavy : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: highlight ? AppColors.brandNavy : AppColors.slate200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color:
                            highlight ? Colors.white : AppColors.slate900)),
                const SizedBox(height: 2),
                Text(note,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: highlight
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.slate600)),
              ],
            ),
          ),
          Text(_fmt(amount),
              style: GoogleFonts.inter(
                  fontSize: highlight ? 18 : 15,
                  fontWeight: FontWeight.w900,
                  color:
                      highlight ? AppColors.brandLime : AppColors.slate900)),
        ],
      ),
    );
  }

  // ── Hero Card ────────────────────────────────────────────────
  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                  const SizedBox(height: 3),
                  Text(user.position.name,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.65),
                      )),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.brandLime.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(slip.period,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandLime,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Take Home Pay',
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 6),
          Text(_fmt(slip.takeHomePay),
              style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              )),
          // Hanya bila sudah ada kabar pencairan (dulu selalu "Ditransfer
          // <akhir periode>", walau belum dicairkan).
          if (slip.pencairanDetail != null || slip.pencairanLabel != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: slip.sudahDicairkan
                          ? AppColors.brandLime
                          : const Color(0xFFFBBF24),
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    slip.pencairanDetail ?? slip.pencairanLabel!,
                    key: const Key('slip-hero-pencairan'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.white.withOpacity(0.75)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Attendance Info (with leave & permission tappable) ───────
  Widget _buildAttendanceInfo(BuildContext context) {
    final leaveDays = slip.leaveDays ?? 0;
    final permissionDays = slip.permissionDays ?? 0;

    final mainItems = [
      (
        Icons.calendar_month_rounded,
        'Hari Kerja',
        '${slip.workDays} hari',
        AppColors.brandNavy,
        false,
        null as VoidCallback?,
      ),
      (
        Icons.check_circle_rounded,
        'Hadir',
        '${slip.presentDays} hari',
        const Color(0xFF16A34A),
        false,
        null as VoidCallback?,
      ),
      (
        Icons.cancel_rounded,
        'Tidak Hadir',
        '${slip.absentDays} hari',
        AppColors.danger,
        false,
        null as VoidCallback?,
      ),
      (
        slip.presentDays == slip.workDays ? Icons.mood : Icons.mood_bad,
        'Bonus',
        slip.presentDays == slip.workDays ? 'Full' : 'Parsial',
        AppColors.brandLimeDark,
        false,
        null as VoidCallback?,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (slip.ditolakBagian('umum:kehadiran'))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ..._markers(const ['umum:kehadiran']),
                  Text('Data kehadiran',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate800)),
                ],
              ),
            ),
          // ── Main attendance row ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: mainItems.map((item) {
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.$4.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$1, color: item.$4, size: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(item.$3,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: item.$4,
                      )),
                  const SizedBox(height: 2),
                  Text(item.$2,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.slate700)),
                ],
              );
            }).toList(),
          ),

          // ── Divider ──────────────────────────────────
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.slate100,
          ),

          // ── Cuti & Izin row (tappable) ────────────────
          Row(
            children: [
              Expanded(
                child: _buildLeavePermissionTile(
                  context: context,
                  icon: Icons.beach_access_rounded,
                  label: 'Cuti',
                  days: leaveDays,
                  color: const Color(0xFF7C3AED),
                  historyType: 'cuti',
                  history: slip.leaveHistory ?? [],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLeavePermissionTile(
                  context: context,
                  icon: Icons.assignment_late_rounded,
                  label: 'Izin',
                  days: permissionDays,
                  color: const Color(0xFF0891B2),
                  historyType: 'izin',
                  history: slip.permissionHistory ?? [],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cuti / Izin tile ─────────────────────────────────────────
  Widget _buildLeavePermissionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int days,
    required Color color,
    required String historyType,
    required List<LeaveRecord> history,
  }) {
    return GestureDetector(
      onTap: () => _showLeaveHistorySheet(
        context: context,
        type: historyType,
        color: color,
        icon: icon,
        history: history,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$days hari',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color,
                      )),
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: AppColors.slate600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.6), size: 16),
          ],
        ),
      ),
    );
  }

  // ── Leave / Permission History Bottom Sheet ───────────────────
  void _showLeaveHistorySheet({
    required BuildContext context,
    required String type,
    required Color color,
    required IconData icon,
    required List<LeaveRecord> history,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Riwayat ${type == 'cuti' ? 'Cuti' : 'Izin'}',
                            style: AppText.headline3
                                .copyWith(color: AppColors.slate900),
                          ),
                          Text(
                            slip.period,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: AppColors.slate700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: AppColors.slate100),
                // List
                Expanded(
                  child: history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon,
                                  size: 40, color: color.withOpacity(0.3)),
                              const SizedBox(height: 10),
                              Text(
                                'Tidak ada riwayat ${type == 'cuti' ? 'cuti' : 'izin'}\npada periode ini',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: AppColors.slate400),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                          itemCount: history.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final rec = history[i];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.slate200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(icon, color: color, size: 14),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(rec.reason,
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.slate800,
                                                )),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _statusColor(rec.status)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                rec.status,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      _statusColor(rec.status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${DateFormat("dd MMM yyyy").format(rec.startDate)} – ${DateFormat("dd MMM yyyy").format(rec.endDate)}  ·  ${rec.totalDays} hari',
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.slate700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'disetujui':
      case 'approved':
        return const Color(0xFF16A34A);
      case 'ditolak':
      case 'rejected':
        return AppColors.danger;
      default:
        return const Color(0xFFD97706);
    }
  }

  // ── Section Title ─────────────────────────────────────────────
  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brandNavy, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: AppText.headline3.copyWith(color: AppColors.slate900)),
      ],
    );
  }

  // ── Salary Table ─────────────────────────────────────────────
  Widget _buildSalaryTable(
    List<SalaryComponent> components, {
    required bool isDeduction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(4),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: AppColors.brandNavy),
              children: [
                _th('Komponen'),
                _th('Keterangan'),
                _th('Jumlah', align: TextAlign.right),
              ],
            ),
            ...components.asMap().entries.map((entry) {
              final isAlt = entry.key.isOdd;
              final comp = entry.value;
              final isLastRow = entry.key == components.length - 1;
              return TableRow(
                decoration: BoxDecoration(
                  color: isAlt ? AppColors.slate50 : AppColors.white,
                  border: isLastRow
                      ? null
                      : const Border(
                          bottom:
                              BorderSide(color: AppColors.slate100, width: 1)),
                ),
                children: [
                  _tdLabel(comp),
                  _tdNote(comp),
                  _td(
                    isDeduction ? '- ${_fmt(comp.amount)}' : _fmt(comp.amount),
                    isDeduction: isDeduction,
                    isBold: true,
                    align: TextAlign.right,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _th(String text, {TextAlign align = TextAlign.left}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(text,
            textAlign: align,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
      );

  /// Kolom "Komponen": nama baris + tanda ⓘ merah (ditolak staff) / hijau
  /// (direvisi admin/manajer).
  Widget _tdLabel(SalaryComponent comp) {
    final markers = comp.key.isEmpty ? const <Widget>[] : _markers([comp.key]);
    if (markers.isEmpty) return _td(comp.label, isBold: true);
    // Ikon ⓘ di KIRI teks (bukan di bawahnya).
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...markers,
          Flexible(
            child: Text(comp.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate800,
                )),
          ),
        ],
      ),
    );
  }

  /// Kolom "Keterangan": teks catatan + badge kalau komponen ini TIDAK ikut
  /// menambah Take Home Pay (tunjangan barang, fasilitas, uang makan).
  /// Item-nya tetap tampil — staff berhak tahu haknya — tapi harus jelas
  /// kenapa jumlah rincian tunjangan tidak sama dengan yang menambah THP.
  Widget _tdNote(SalaryComponent comp) {
    if (!comp.excludedFromThp) return _td(comp.note, isMuted: true);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comp.note.isNotEmpty)
            Text(comp.note,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.slate700)),
          if (comp.note.isNotEmpty) const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Text('Di luar THP',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate600,
                )),
          ),
        ],
      ),
    );
  }

  Widget _td(
    String text, {
    bool isDeduction = false,
    bool isBold = false,
    bool isMuted = false,
    TextAlign align = TextAlign.left,
  }) {
    final color = isDeduction
        ? AppColors.danger
        : isMuted
            ? AppColors.slate700
            : AppColors.slate800;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(text,
          textAlign: align,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: color,
          )),
    );
  }

  // ── Summary Card ─────────────────────────────────────────────
  Widget _buildSummaryCard() {
    // Sprint 2 EPIC 9 — ringkasan ini HARUS bisa dijumlah sendiri oleh staff
    // dan ketemu angka Take Home Pay yang sama dengan yang ditransfer:
    //
    //   Pendapatan Pokok − Total Potongan + Tunjangan Tunai = Take Home Pay
    //
    // Identitas ini persis formula server (payroll-calc.ts):
    //   gajiNetto = (grossForTax − totalPotongan) + totalTunjanganUang
    //
    // Sebelumnya baris di sini memakai tebakan berdasarkan teks label
    // (`label.contains('tunjangan')`) — meleset untuk tunjangan bernama bebas
    // seperti "Transport"/"Sepatu Kerja", dan barisnya tidak pernah menjumlah
    // ke Take Home Pay. Sekarang semuanya dari angka slip, bukan nama label.
    final tunjanganTunai = slip.totalTunjanganUang;
    final diluarThp = slip.tunjanganDiluarThp;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandNavy.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment
            .end, // Membantu merapikan info transfer di bagian bawah
        children: [
          _summaryRow('Pendapatan Pokok', _fmt(slip.pendapatanPokok)),
          _divider(),
          _summaryRow('Total Potongan', '- ${_fmt(slip.totalDeduction)}',
              isDeduction: true),
          if (slip.pajak > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _summaryRow('  • PPh 21', '- ${_fmt(slip.pajak)}',
                  isDeduction: true),
            ),
          if (slip.totalPotongan > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _summaryRow(
                  '  • Potongan lain', '- ${_fmt(slip.totalPotongan)}',
                  isDeduction: true),
            ),
          _divider(),
          _summaryRow('Tunjangan Tunai', _fmt(tunjanganTunai)),
          // if (diluarThp > 0)
          //   Padding(
          //     padding: const EdgeInsets.only(top: 4),
          //     child: Text(
          //       'Tunjangan barang, fasilitas & uang makan senilai '
          //       '${_fmt(diluarThp)} tampil di rincian, tetapi tidak menambah '
          //       'Take Home Pay.',
          //       textAlign: TextAlign.right,
          //       style: GoogleFonts.inter(
          //         fontSize: 10,
          //         height: 1.35,
          //         color: Colors.white.withOpacity(0.6),
          //       ),
          //     ),
          //   ),
          _divider(),
          _summaryRow('Take Home Pay', _fmt(slip.netSalary),
              isTotal: true, markers: _markers(const ['umum:thp', 'col:gajiNetto'])),
        ],
      ),
    );
  }
}

Widget _divider() => Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.white.withOpacity(0.12),
    );

Widget _summaryRow(
  String label,
  String amount, {
  bool isDeduction = false,
  bool isTotal = false,
  List<Widget> markers = const [],
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...markers, // ikon ⓘ di kiri teks
          Text(label,
              style: GoogleFonts.inter(
                fontSize: isTotal ? 13 : 12,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
                color: Colors.white,
              )),
        ],
      ),
      Text(amount,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.w800,
            color: isDeduction ? const Color(0xFFFCA5A5) : Colors.white,
          )),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _EarningsRow extends StatelessWidget {
  final String label, amount;
  final bool isDeduction;
  const _EarningsRow({
    required this.label,
    required this.amount,
    required this.isDeduction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: isDeduction ? AppColors.danger : AppColors.brandLimeDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900)),
          ),
          Text(
            isDeduction ? '- $amount' : amount,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDeduction ? AppColors.danger : AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, amount;
  final bool isDeduction;
  final bool bold;
  const _SummaryRow(this.label, this.amount, this.isDeduction,
      {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: bold ? AppColors.slate900 : AppColors.slate600,
              )),
          Text(
            isDeduction ? '- $amount' : amount,
            style: GoogleFonts.inter(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: isDeduction
                  ? AppColors.danger
                  : (bold ? AppColors.brandNavy : AppColors.slate900),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG: alasan menolak slip
// ─────────────────────────────────────────────────────────────────────────────
/// Satu baris yang bisa dicentang di dialog tolak.
class _TolakItem {
  /// Kunci baris (lihat [SalaryComponent.key]) yang dikirim sebagai `bagian`.
  final String key;
  final String section;
  final String label;
  final String? amount;
  const _TolakItem(
      {required this.key,
      required this.section,
      required this.label,
      this.amount});

  /// Teks yang dikirim ke HR, mis. "Tunjangan: Transport Harian".
  String get text => '$section: $label';
}

class _TolakSlipDialog extends StatefulWidget {
  final List<_TolakItem> items;
  const _TolakSlipDialog({required this.items});

  @override
  State<_TolakSlipDialog> createState() => _TolakSlipDialogState();
}

class _TolakSlipDialogState extends State<_TolakSlipDialog> {
  final _controller = TextEditingController();
  final _checked = <int>{};
  static const _min = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _bagian => [
        for (var i = 0; i < widget.items.length; i++)
          if (_checked.contains(i)) widget.items[i].text,
      ];

  /// Valid bila ada bagian yang dicentang ATAU catatan cukup panjang.
  bool get _valid =>
      _checked.isNotEmpty || _controller.text.trim().length >= _min;

  @override
  Widget build(BuildContext context) {
    final sections = <String>[];
    for (final i in widget.items) {
      if (!sections.contains(i.section)) sections.add(i.section);
    }
    final maxHeight = MediaQuery.of(context).size.height * 0.4;

    return AlertDialog(
      title: const Text('Apa yang salah?'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Centang bagian slip yang tidak sesuai supaya HR tahu apa yang '
                'harus diperbaiki. Catatan tambahan boleh diisi.\n\n'
                'Penolakan hanya bisa dilakukan sekali, jadi pastikan semua '
                'bagian yang salah sudah dicentang.'),
            const SizedBox(height: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final section in sections) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 2),
                        child: Text(section,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate600)),
                      ),
                      for (var i = 0; i < widget.items.length; i++)
                        if (widget.items[i].section == section)
                          CheckboxListTile(
                            key: ValueKey('tolak-item-$i'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _checked.contains(i),
                            onChanged: (v) => setState(() {
                              v == true ? _checked.add(i) : _checked.remove(i);
                            }),
                            title: Text(widget.items[i].label,
                                style: GoogleFonts.inter(fontSize: 13)),
                            secondary: widget.items[i].amount == null
                                ? null
                                : Text(widget.items[i].amount!,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.slate700)),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('tolak-catatan'),
              controller: _controller,
              maxLines: 2,
              maxLength: 300,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _checked.isEmpty
                    ? 'Catatan (minimal 5 karakter bila tidak ada yang dicentang)'
                    : 'Catatan tambahan (opsional), mis. "kurang 2 jam"',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(context, (
                    alasan: SalaryService.susunAlasanTolak(
                        _bagian, _controller.text),
                    bagian: [
                      for (var i = 0; i < widget.items.length; i++)
                        if (_checked.contains(i)) widget.items[i].key,
                    ],
                  ))
              : null,
          child: const Text('Kirim ke HR'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TANDA ⓘ & KEDIP STATUS
// ─────────────────────────────────────────────────────────────────────────────
/// Ikon ⓘ kecil di samping baris slip: merah = bagian yang ditolak staff,
/// hijau = hasil revisi admin/manajer. Ketuk untuk detailnya.
class _InfoMarker extends StatelessWidget {
  static const tolakColor = Color(0xFFDC2626);
  static const revisiColor = Color(0xFF16A34A);

  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _InfoMarker({
    super.key,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.info_rounded, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

/// Mengedipkan warna latar [builder] dari [from] ke [to] tiga kali saat
/// pertama tampil, lalu berhenti di [from].
class _BlinkThrice extends StatefulWidget {
  final Color from;
  final Color to;
  final Widget Function(Color background) builder;

  const _BlinkThrice({
    super.key,
    required this.from,
    required this.to,
    required this.builder,
  });

  @override
  State<_BlinkThrice> createState() => _BlinkThriceState();
}

class _BlinkThriceState extends State<_BlinkThrice>
    with SingleTickerProviderStateMixin {
  static const _blinks = 3;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500 * _blinks),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        // 0 -> 1 -> 0 per kedipan.
        final phase = (_controller.value * _blinks) % 1.0;
        final t = _controller.isCompleted ? 0.0 : 1 - (2 * phase - 1).abs();
        return widget.builder(Color.lerp(widget.from, widget.to, t)!);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POPUP TAHAPAN STATUS SLIP
// ─────────────────────────────────────────────────────────────────────────────
/// Satu tahap di popup bantuan.
class _SlipStep {
  final IconData icon;
  final String title;
  final String body;
  const _SlipStep(this.icon, this.title, this.body);
}

const _slipSteps = [
  _SlipStep(Icons.calculate_outlined, 'HR menghitung & mengirim slip',
      'Admin/manajer menghitung gaji periode ini lalu mengirim slip ke Anda untuk diperiksa.'),
  _SlipStep(Icons.fact_check_outlined, 'Menunggu konfirmasi Anda',
      'Periksa angka di slip. Tekan "Konfirmasi" jika sudah benar, atau "Ada yang salah" jika tidak sesuai.'),
  _SlipStep(
      Icons.published_with_changes_rounded,
      'Ditolak & direvisi HR (bila ada)',
      'Bila Anda menolak, HR memperbaiki lalu mengirim ulang. Penolakan hanya bisa sekali. '
          'Di rincian slip, tanda berikut muncul di samping baris:'),
  _SlipStep(Icons.verified_rounded, 'Staff menyetujui',
      'Anda menyetujui slip, slip terkunci dan bisa diunduh.'),
  _SlipStep(Icons.hourglass_top_rounded, 'Disetujui untuk dicairkan',
      'HR menyetujui slip untuk dicairkan. Gaji segera ditransfer.'),
  _SlipStep(Icons.payments_rounded, 'Gaji dicairkan',
      'Gaji sudah ditransfer. Tanggal, nama admin yang mencairkan dan bukti transfer ada di detail slip.'),
];

/// Tahap [_slipSteps] tempat [slip] berada sekarang; null bila tidak ada slip.
int? slipCurrentStep(SalarySlip? slip) {
  if (slip == null) return null;
  if (slip.sudahDicairkan) return 5;
  if (slip.sedangDiprosesPencairan) return 4;
  switch (slip.statusSlip) {
    case 'menunggu_konfirmasi':
      return 1;
    case 'ditolak':
    case 'draft': // hanya terlihat bila pernah ditolak staff
      return 2;
    case 'dikonfirmasi':
    case 'terkunci':
      return 3;
    default:
      return 0;
  }
}

/// Popup legend tahapan status slip gaji, menyorot posisi [slip] (slip
/// terbaru) sekarang.
Future<void> showSlipStatusGuide(BuildContext context, SalarySlip? slip) {
  final current = slipCurrentStep(slip);
  // Tahap revisi hanya "dilalui" bila slip memang pernah ditolak.
  final revisiDilalui = slip?.pernahDitolak ?? false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      key: const Key('slip-status-guide'),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Tahapan Slip Gaji',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            const SizedBox(height: 4),
            Text(
                slip == null
                    ? 'Belum ada slip gaji.'
                    : 'Posisi slip ${slip.period} ditandai "Sekarang".',
                style: AppText.body2),
            const SizedBox(height: 14),
            for (var i = 0; i < _slipSteps.length; i++)
              _buildGuideStep(
                index: i,
                step: _slipSteps[i],
                isCurrent: i == current,
                isDone: current != null &&
                    i < current &&
                    (i != 2 || revisiDilalui),
                isSkipped:
                    current != null && i == 2 && i < current && !revisiDilalui,
                isLast: i == _slipSteps.length - 1,
                // Legend ikon ⓘ ditaruh di detail tahap revisi, tempat
                // penjelasannya relevan.
                extra: i == 2
                    ? Column(
                        key: const Key('slip-guide-legend'),
                        children: [
                          const SizedBox(height: 6),
                          _guideLegend(
                              _InfoMarker.tolakColor, 'Bagian yang Anda tolak'),
                          const SizedBox(height: 4),
                          _guideLegend(_InfoMarker.revisiColor,
                              'Hasil revisi admin/manajer'),
                        ],
                      )
                    : null,
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _guideLegend(Color color, String text) => Row(
      children: [
        Icon(Icons.info_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style:
                    GoogleFonts.inter(fontSize: 12, color: AppColors.slate700))),
      ],
    );

Widget _buildGuideStep({
  required int index,
  required _SlipStep step,
  required bool isCurrent,
  required bool isDone,
  required bool isSkipped,
  required bool isLast,
  Widget? extra,
}) {
  final Color color = isCurrent
      ? AppColors.brandNavy
      : isDone
          ? _InfoMarker.revisiColor
          : AppColors.slate400;
  return IntrinsicHeight(
    key: ValueKey('slip-step-$index${isCurrent ? '-current' : ''}'),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color:
                    isCurrent ? AppColors.brandNavy : color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(isDone ? Icons.check_rounded : step.icon,
                  size: 16, color: isCurrent ? AppColors.brandLime : color),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: isDone ? _InfoMarker.revisiColor : AppColors.slate200,
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${index + 1}. ${step.title}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight:
                                isCurrent ? FontWeight.w800 : FontWeight.w600,
                            color: isCurrent
                                ? AppColors.brandNavy
                                : AppColors.slate800)),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.brandLime,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('Sekarang',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brandNavy)),
                      ),
                    if (isSkipped)
                      Text('(tidak ada)',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.slate400)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(step.body,
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.4,
                        color: AppColors.slate600)),
                if (extra != null) extra,
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
