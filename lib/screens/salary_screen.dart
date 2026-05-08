import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

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
  final slips = SampleData.salaryHistory;
  int _idx = 0;

  SalarySlip get _slip => slips[_idx];

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
              color: AppColors.white,
              padding: widget.isFromAccount
                  ? const EdgeInsets.fromLTRB(4, 16, 20, 16)
                  : const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  if (widget.isFromAccount)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.brandNavy, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FINANCIAL STATEMENT',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandNavy,
                            letterSpacing: 1.2,
                          )),
                      Text('Gaji Saya',
                          style: AppText.headline2
                              .copyWith(color: AppColors.slate900)),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.slate200),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  _buildMonthSelector(),
                  const SizedBox(height: 16),
                  _buildSalaryCard(),
                  const SizedBox(height: 20),
                  _buildSalarySetting(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Month Selector ──────────────────────────────────────────
  Widget _buildMonthSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pilih Periode Gaji', style: AppText.label),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandNavy.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _idx,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.brandNavy, size: 22),
              items: List.generate(slips.length, (i) {
                return DropdownMenuItem<int>(
                  value: i,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _idx
                              ? AppColors.brandNavy
                              : AppColors.slate300,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        slips[i].period,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight:
                              i == _idx ? FontWeight.w700 : FontWeight.w500,
                          color: i == _idx
                              ? AppColors.brandNavy
                              : AppColors.slate700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              selectedItemBuilder: (_) => List.generate(slips.length, (i) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    slips[i].period,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandNavy,
                    ),
                  ),
                );
              }),
              onChanged: (val) {
                if (val != null) setState(() => _idx = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Salary Card ─────────────────────────────────────────────
  Widget _buildSalaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
                child: Text(_slip.period,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    )),
              ),
              // ── Tombol Lihat Detail → navigate ke SalaryDetailScreen ──
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SalaryDetailScreen(
                        slip: _slip,
                        user: user,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.brandLime.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text('Lihat Detail',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandLime,
                          )),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 10, color: AppColors.brandLime),
                    ],
                  ),
                ),
              ),
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
          Text('Total Gaji Bersih (Take Home Pay)',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.75),
              )),
          const SizedBox(height: 6),
          Text(
            _fmtCurrency(_slip.netSalary),
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
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
                'Ditransfer ${DateFormat("dd MMM yyyy").format(_slip.periodEnd)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Salary Setting ──────────────────────────────────────────
  Widget _buildSalarySetting() {
    final settings = [
      (
        Icons.account_balance_wallet_rounded,
        'Gaji Pokok',
        _fmtCurrencyShort(user.position.baseSalary),
        'Berdasarkan jabatan ${user.position.name}',
        AppColors.brandNavy
      ),
      (
        Icons.star_rounded,
        'Bonus Harian',
        _fmtCurrencyShort(user.position.dailyBonus),
        'Per hari kerja hadir tepat waktu',
        AppColors.brandLimeDark
      ),
      (
        Icons.favorite_rounded,
        'Tunjangan Kesehatan',
        _fmtCurrencyShort(user.position.healthAllowance),
        'Dibayarkan per bulan',
        AppColors.danger
      ),
      (
        Icons.directions_car_rounded,
        'Tunjangan Transport',
        _fmtCurrencyShort(user.position.transportAllowance),
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
            Text('Pengaturan Gaji Saya',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Konfigurasi gaji berdasarkan jabatan dan penggajian yang berlaku',
          style: AppText.body2,
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
class SalaryDetailScreen extends StatelessWidget {
  const SalaryDetailScreen({
    super.key,
    required this.slip,
    required this.user,
  });

  final SalarySlip slip;
  final UserProfile user;

  String _fmt(int amount) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);

  // ── Generate & share PDF ──────────────────────────────────
  Future<void> _downloadPdf(BuildContext context) async {
    final income = slip.components.where((c) => !c.isDeduction).toList();
    final deductions = slip.components.where((c) => c.isDeduction).toList();

    final pdf = pw.Document();

    const navyColor   = PdfColor.fromInt(0xFF0F2D5A);
    const limeColor   = PdfColor.fromInt(0xFFCBF563);
    const slate100    = PdfColor.fromInt(0xFFF1F5F9);
    const slate500    = PdfColor.fromInt(0xFF64748B);
    const slate700    = PdfColor.fromInt(0xFF334155);
    const dangerColor = PdfColor.fromInt(0xFFEF4444);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);

    pw.TextStyle bold(double sz, {PdfColor color = slate700}) =>
        pw.TextStyle(fontSize: sz, fontWeight: pw.FontWeight.bold, color: color);
    pw.TextStyle regular(double sz, {PdfColor color = slate700}) =>
        pw.TextStyle(fontSize: sz, color: color);

    // Table header cell
    pw.Widget th(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: navyColor,
          child: pw.Text(text,
              textAlign: align,
              style: bold(9, color: PdfColors.white)),
        );

    // Table data cell
    pw.Widget td(
      String text, {
      pw.TextAlign align = pw.TextAlign.left,
      PdfColor color = slate700,
      bool isBold = false,
      bool isAlt = false,
    }) =>
        pw.Container(
          color: isAlt ? slate100 : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(text,
              textAlign: align,
              style: isBold ? bold(9, color: color) : regular(9, color: color)),
        );

    // Summary row inside dark card
    pw.Widget summaryRow(
      String label,
      String value, {
      bool isDeduction = false,
      bool isTotal = false,
    }) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: isTotal
                      ? bold(10, color: PdfColors.white)
                      : regular(9, color: PdfColor.fromInt(0xFFCBD5E1))),
              pw.Text(value,
                  style: isTotal
                      ? bold(12, color: limeColor)
                      : bold(10,
                          color: isDeduction
                              ? PdfColor.fromInt(0xFFFCA5A5)
                              : PdfColors.white)),
            ],
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // ── Header banner
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: navyColor,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SLIP GAJI KARYAWAN',
                        style: bold(15, color: PdfColors.white)),
                    pw.SizedBox(height: 4),
                    pw.Text(slip.period,
                        style: bold(10, color: limeColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(user.name, style: bold(11, color: PdfColors.white)),
                    pw.SizedBox(height: 3),
                    pw.Text(user.position.name,
                        style: regular(9,
                            color: PdfColor.fromInt(0xFFCBD5E1))),
                    pw.SizedBox(height: 3),
                    pw.Text('NIK: ${user.nik}',
                        style: regular(9,
                            color: PdfColor.fromInt(0xFF94A3B8))),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── Kehadiran info row
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: slate100,
              border: pw.Border.all(color: borderColor, width: 0.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text('${slip.workDays} hari',
                      style: bold(11, color: navyColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('Hari Kerja', style: regular(8, color: slate500)),
                ]),
                pw.Column(children: [
                  pw.Text('${slip.presentDays} hari',
                      style: bold(11, color: PdfColor.fromInt(0xFF16A34A))),
                  pw.SizedBox(height: 2),
                  pw.Text('Hadir', style: regular(8, color: slate500)),
                ]),
                pw.Column(children: [
                  pw.Text('${slip.absentDays} hari',
                      style: bold(11, color: dangerColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('Tidak Hadir', style: regular(8, color: slate500)),
                ]),
                pw.Column(children: [
                  pw.Text(
                    '${DateFormat("dd/MM").format(slip.periodStart)} – ${DateFormat("dd/MM/yy").format(slip.periodEnd)}',
                    style: bold(10, color: slate700),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('Periode', style: regular(8, color: slate500)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // ── Pendapatan table
          pw.Text('Rincian Pendapatan', style: bold(11)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(4),
              2: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(children: [
                th('Komponen'),
                th('Keterangan'),
                th('Jumlah', align: pw.TextAlign.right),
              ]),
              ...income.asMap().entries.map((e) => pw.TableRow(children: [
                    td(e.value.label,
                        isBold: true, isAlt: e.key.isOdd),
                    td(e.value.note,
                        color: slate500, isAlt: e.key.isOdd),
                    td(_fmt(e.value.amount),
                        align: pw.TextAlign.right,
                        isBold: true,
                        isAlt: e.key.isOdd),
                  ])),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Potongan table
          pw.Text('Rincian Potongan', style: bold(11)),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(4),
              2: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(children: [
                th('Komponen'),
                th('Keterangan'),
                th('Jumlah', align: pw.TextAlign.right),
              ]),
              ...deductions.asMap().entries.map((e) => pw.TableRow(children: [
                    td(e.value.label,
                        isBold: true, isAlt: e.key.isOdd),
                    td(e.value.note,
                        color: slate500, isAlt: e.key.isOdd),
                    td('- ${_fmt(e.value.amount)}',
                        align: pw.TextAlign.right,
                        color: dangerColor,
                        isBold: true,
                        isAlt: e.key.isOdd),
                  ])),
            ],
          ),
          pw.SizedBox(height: 18),

          // ── Summary card
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: navyColor,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              children: [
                summaryRow('Total Pendapatan', _fmt(slip.totalIncome)),
                pw.Divider(
                    color: PdfColor.fromInt(0x33FFFFFF), thickness: 0.5),
                summaryRow('Total Potongan', '- ${_fmt(slip.totalDeduction)}',
                    isDeduction: true),
                pw.Divider(
                    color: PdfColor.fromInt(0x33FFFFFF), thickness: 0.5),
                summaryRow(
                    'Gaji Bersih (Take Home Pay)', _fmt(slip.netSalary),
                    isTotal: true),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── Footer
          pw.Center(
            child: pw.Text(
              'Dicetak pada ${DateFormat("dd MMMM yyyy, HH:mm").format(DateTime.now())} — Dokumen ini digenerate otomatis oleh sistem.',
              style: regular(8, color: PdfColor.fromInt(0xFF94A3B8)),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'slip_gaji_${slip.period.replaceAll(' ', '_').replaceAll('/', '-')}.pdf',
    );
  }

  // ─── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final income = slip.components.where((c) => !c.isDeduction).toList();
    final deductions = slip.components.where((c) => c.isDeduction).toList();

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──────────────────────────────────────
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(4, 16, 20, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.brandNavy, size: 20),
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
                              color: AppColors.brandNavy,
                              letterSpacing: 1.2,
                            )),
                        Text('Detail Salary',
                            style: AppText.headline2
                                .copyWith(color: AppColors.slate900)),
                      ],
                    ),
                  ),
                  // ── Download PDF Button ──────────────────
                  GestureDetector(
                    onTap: () => _downloadPdf(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.brandNavy,
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
                          const Icon(Icons.download_rounded,
                              color: Colors.white, size: 16),
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
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  _buildAttendanceInfo(),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                      Icons.trending_up_rounded, 'Rincian Pendapatan'),
                  const SizedBox(height: 8),
                  _buildSalaryTable(income, isDeduction: false),
                  const SizedBox(height: 20),
                  _buildSectionTitle(
                      Icons.trending_down_rounded, 'Rincian Potongan'),
                  const SizedBox(height: 8),
                  _buildSalaryTable(deductions, isDeduction: true),
                  const SizedBox(height: 20),
                  _buildSummaryCard(),
                ],
              ),
            ),
          ],
        ),
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
          Text('Gaji Bersih (Take Home Pay)',
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white.withOpacity(0.7))),
          const SizedBox(height: 6),
          Text(_fmt(slip.netSalary),
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

  // ── Attendance Info ──────────────────────────────────────────
  Widget _buildAttendanceInfo() {
    final items = [
      (
        Icons.calendar_month_rounded,
        'Hari Kerja',
        '${slip.workDays} hari',
        AppColors.brandNavy
      ),
      (
        Icons.check_circle_rounded,
        'Hadir',
        '${slip.presentDays} hari',
        const Color(0xFF16A34A)
      ),
      (
        Icons.cancel_rounded,
        'Tidak Hadir',
        '${slip.absentDays} hari',
        AppColors.danger
      ),
      (
        Icons.star_rounded,
        'Bonus',
        slip.presentDays == slip.workDays ? 'Full' : 'Parsial',
        AppColors.brandLimeDark
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
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
    );
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
            2: FlexColumnWidth(3),
          },
          children: [
            // ── Header Row ──────────────────────────────
            TableRow(
              decoration: const BoxDecoration(color: AppColors.brandNavy),
              children: [
                _th('Komponen'),
                _th('Keterangan'),
                _th('Jumlah', align: TextAlign.right),
              ],
            ),
            // ── Data Rows ──────────────────────────────
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
                  _td(comp.note, isMuted: true),
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
        children: [
          _summaryRow('Total Pendapatan', _fmt(slip.totalIncome),
              isDeduction: false),
          _divider(),
          _summaryRow('Total Potongan', '- ${_fmt(slip.totalDeduction)}',
              isDeduction: true),
          _divider(),
          _summaryRow(
              'Gaji Bersih (Take Home Pay)', _fmt(slip.netSalary),
              isTotal: true),
        ],
      ),
    );
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
              color: isTotal ? Colors.white : Colors.white.withOpacity(0.7),
            )),
        Text(amount,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.w800,
              color: isDeduction
                  ? const Color(0xFFFCA5A5)
                  : isTotal
                      ? AppColors.brandLime
                      : Colors.white,
            )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS (unchanged from original)
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