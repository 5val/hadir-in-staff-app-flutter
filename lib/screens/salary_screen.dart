import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/salary_service.dart';
import '../services/api_client.dart';
import '../services/google_drive_service.dart';
import '../services/slip_drive_sync.dart';

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

  // Filter: 1 = 1 bulan terakhir, 2 = 2 bulan terakhir, 3 = 3 bulan terakhir
  int _filterMonths = 1;

  List<SalarySlip> get _filteredSlips => _slips.take(_filterMonths).toList();

  @override
  void initState() {
    super.initState();
    _load();
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
      });
      // Slip yang sudah terkunci disimpan ke Google Drive staff di latar
      // (hanya bila akun Google sudah tersambung; tidak pernah memunculkan
      // dialog login). Tombol manual ada di layar detail.
      SlipDriveSync.autoSyncLocked(list);
    } on ApiException catch (e) {
      if (silent) return; // muat ulang diam-diam tidak boleh menimpa daftar

      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Widget _buildErrorState() {
    return Center(
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
                      : ListView(
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
          ],
        ),
      ),
    );
  }

  // ── Filter Chips ────────────────────────────────────────────
  Widget _buildFilterChips() {
    final options = [
      (1, '1 Bulan Terakhir'),
      (2, '2 Bulan Terakhir'),
      (3, '3 Bulan Terakhir'),
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
              final isSelected = _filterMonths == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filterMonths = opt.$1),
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
                  child: Text(slip.period,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      )),
                ),
                _statusChip(slip),
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
            const SizedBox(height: 10),
            // ── Mini summary row ──────────────────────────
            _miniStat('Ditransfer', DateFormat('dd MMM').format(slip.periodEnd),
                AppColors.brandLime),
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
    final needsAction = slip.perluKonfirmasi;
    final Color bg;
    final Color fg;
    switch (slip.statusSlip) {
      case 'menunggu_konfirmasi':
        bg = AppColors.brandLime;
        fg = AppColors.brandNavy;
        break;
      case 'ditolak':
        bg = const Color(0xFFFCA5A5);
        fg = const Color(0xFF7F1D1D);
        break;
      default:
        bg = Colors.white.withOpacity(0.12);
        fg = Colors.white.withOpacity(0.9);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (needsAction) ...[
            Icon(Icons.notifications_active_rounded, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(slip.statusLabel,
              style: GoogleFonts.inter(
                  fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text('$label $value',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            )),
        // const SizedBox(height: 2),
        // Text(label,
        //     style: GoogleFonts.inter(
        //         fontSize: 13, color: Colors.white.withOpacity(0.55))),
      ],
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
  });

  final SalarySlip slip;
  final UserProfile user;

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
      await SalaryService.konfirmasi(slip.id);
      if (!mounted) return;
      setState(() => slip = slip.copyWith(statusSlip: 'dikonfirmasi'));
      _snack('Slip dikonfirmasi. Menunggu HR mengunci slip.');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tolak() async {
    final alasan = await showDialog<String>(
      context: context,
      builder: (ctx) => const _TolakSlipDialog(),
    );
    if (alasan == null || _busy) return;

    setState(() => _busy = true);
    try {
      await SalaryService.tolak(slip.id, alasan);
      if (!mounted) return;
      setState(() => slip = slip.copyWith(statusSlip: 'ditolak', alasanTolak: alasan.trim()));
      _snack('Slip ditolak. HR akan memeriksa dan merevisinya.');
    } on ApiException catch (e) {
      _snack(e.message);
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
    switch (slip.statusSlip) {
      case 'menunggu_konfirmasi':
        icon = Icons.fact_check_outlined;
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF1D4ED8);
        title = 'Mohon periksa slip ini';
        body = 'HR meminta Anda memeriksa angka di bawah. Jika sudah benar tekan '
            '"Konfirmasi". Jika ada yang salah tekan "Ada yang salah" dan tulis alasannya. '
            'Slip baru bisa diunduh setelah dikunci HR.';
        break;
      case 'dikonfirmasi':
        icon = Icons.hourglass_top_rounded;
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        title = 'Sudah Anda konfirmasi';
        body = 'Menunggu HR mengunci slip. Setelah dikunci slip bisa diunduh.';
        break;
      case 'ditolak':
        icon = Icons.report_gmailerrorred_rounded;
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        title = 'Anda menolak slip ini';
        body = 'HR akan memeriksa dan merevisinya, lalu mengirim ulang untuk Anda konfirmasi.'
            '${slip.alasanTolak != null ? '\n\nAlasan Anda: ${slip.alasanTolak}' : ''}';
        break;
      default:
        return _buildFinalBanner();
    }
    return _banner(icon, bg, fg, title, body);
  }

  Widget _buildFinalBanner() {
    final saved = _savedToDrive == true;
    return _banner(
      Icons.verified_rounded,
      const Color(0xFFF0FDF4),
      const Color(0xFF15803D),
      'Slip final',
      'Slip ini sudah dikunci HR dan bisa diunduh.',
      action: Row(
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
            Expanded(
              child: OutlinedButton(
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
                        Text('Detail Salary',
                            style: AppText.headline2
                                .copyWith(color: AppColors.white)),
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  _buildStatusBanner(),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: AppColors.brandLime, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                'Ditransfer ${DateFormat("dd MMMM yyyy").format(slip.periodEnd)}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withOpacity(0.75)),
              ),
            ],
          ),
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
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(4),
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
                  _td(comp.label, isBold: true),
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
          _summaryRow('Take Home Pay', _fmt(slip.netSalary), isTotal: true),

          // BERUBAH: Menambahkan info ditransfer menggunakan apa di bawah gaji bersih
          const SizedBox(height: 10),
          Text(
            'Ditransfer via ${slip.transferBy}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.65),
              fontStyle: FontStyle.italic,
            ),
          ),
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
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
            color: Colors.white,
          )),
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
class _TolakSlipDialog extends StatefulWidget {
  const _TolakSlipDialog();

  @override
  State<_TolakSlipDialog> createState() => _TolakSlipDialogState();
}

class _TolakSlipDialogState extends State<_TolakSlipDialog> {
  final _controller = TextEditingController();
  static const _min = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _controller.text.trim().length >= _min;
    return AlertDialog(
      title: const Text('Apa yang salah?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'Tulis bagian yang tidak sesuai supaya HR bisa memperbaikinya, '
              'mis. "Lembur saya kurang 2 jam".'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Alasan (minimal 5 karakter)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, _controller.text.trim()) : null,
          child: const Text('Kirim ke HR'),
        ),
      ],
    );
  }
}
