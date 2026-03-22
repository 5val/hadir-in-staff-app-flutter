import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen>
    with SingleTickerProviderStateMixin {
  final UserProfile user = SampleData.currentUser;
  final List<SalarySlip> _slips = SampleData.salaryHistory;

  int  _selectedIndex = 0;
  bool _showEarlyMonth = false;

  late AnimationController _slideCtrl;
  late Animation<Offset>   _slide;

  SalarySlip get _current => _slips[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0.1, 0), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  String _fmtCurrency(int amount) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
          .format(amount);

  void _changePeriod(int i) {
    setState(() => _selectedIndex = i);
    _slideCtrl
      ..reset()
      ..forward();
  }

  String _payrollLabel(PayrollType t) {
    switch (t) {
      case PayrollType.weekly:    return 'Mingguan (7 hari)';
      case PayrollType.biweekly:  return '2 Mingguan (14 hari)';
      case PayrollType.monthly:   return 'Bulanan (30 hari)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final slip      = _current;
    final isMonthly = user.position.payrollType == PayrollType.monthly;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Slip Gaji', style: AppText.headline3),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: AppColors.brandNavy),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download PDF slip gaji...')),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.slate200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SlideTransition(
          position: _slide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Payroll type info ───────────────────────
              SectionCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandNavy.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business_center_rounded,
                          color: AppColors.brandNavy, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sistem Penggajian: ${_payrollLabel(user.position.payrollType)}',
                            style: AppText.body2.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Dihitung per ${user.position.payrollPeriodDays} hari kerja',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    if (isMonthly)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Akhir Bulan', style: AppText.caption),
                          Switch.adaptive(
                            value: _showEarlyMonth
                                ? !user.position.payrollEndMonth
                                : user.position.payrollEndMonth,
                            onChanged: (v) =>
                                setState(() => _showEarlyMonth = !v),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Period selector ─────────────────────────
              Text('Pilih Periode', style: AppText.label),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _slips.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _changePeriod(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: i == _selectedIndex
                              ? AppColors.brandNavy
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: i == _selectedIndex
                                ? AppColors.brandNavy
                                : AppColors.slate200,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _slips[i].period,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: i == _selectedIndex
                                ? Colors.white
                                : AppColors.slate600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Net salary hero ─────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.brandNavy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brandNavy.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(user.name,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9))),
                        const Spacer(),
                        Text(slip.period,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.75))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(user.position.name,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.65))),
                    const SizedBox(height: 16),
                    Text('Gaji Bersih',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8))),
                    const SizedBox(height: 2),
                    Text(
                      _fmtCurrency(slip.netSalary),
                      style: GoogleFonts.inter(
                        fontSize: 28, fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(height: 1, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroStat(
                            label: 'Pendapatan',
                            value: _fmtCurrency(slip.totalIncome),
                          ),
                        ),
                        Container(
                          width: 1, height: 28,
                          color: Colors.white.withOpacity(0.25),
                        ),
                        Expanded(
                          child: _HeroStat(
                            label: 'Potongan',
                            value: _fmtCurrency(slip.totalDeduction),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Attendance summary ──────────────────────
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ringkasan Kehadiran', style: AppText.label),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _AttendStat(
                            label: 'Hari Kerja',
                            value: '${slip.workingDays}',
                            color: AppColors.brandNavy)),
                        Expanded(child: _AttendStat(
                            label: 'Hadir',
                            value: '${slip.presentDays}',
                            color: AppColors.success)),
                        Expanded(child: _AttendStat(
                            label: 'Terlambat',
                            value: '${slip.lateDays}x',
                            color: AppColors.warning)),
                        Expanded(child: _AttendStat(
                            label: 'Lembur',
                            value: '${slip.overtimeHours}j',
                            color: AppColors.brandCyan)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Income ──────────────────────────────────
              Text('Pendapatan', style: AppText.label),
              const SizedBox(height: 8),
              SectionCard(
                child: Column(
                  children: [
                    ...slip.components
                        .where((c) => !c.isDeduction)
                        .map((c) => _SalaryRow(
                              label: c.label,
                              amount: _fmtCurrency(c.amount),
                              isDeduction: false)),
                    const AppDivider(),
                    const SizedBox(height: 8),
                    _SalaryRow(
                      label: 'Total Pendapatan',
                      amount: _fmtCurrency(slip.totalIncome),
                      isDeduction: false,
                      isTotal: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Deductions ──────────────────────────────
              Text('Potongan', style: AppText.label),
              const SizedBox(height: 8),
              SectionCard(
                child: Column(
                  children: [
                    ...slip.components
                        .where((c) => c.isDeduction)
                        .map((c) => _SalaryRow(
                              label: c.label,
                              amount: _fmtCurrency(c.amount),
                              isDeduction: true)),
                    const AppDivider(),
                    const SizedBox(height: 8),
                    _SalaryRow(
                      label: 'Total Potongan',
                      amount: _fmtCurrency(slip.totalDeduction),
                      isDeduction: true,
                      isTotal: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Net total row ────────────────────────────
              SectionCard(
                borderColor: AppColors.brandNavy.withOpacity(0.4),
                color: AppColors.brandNavy.withOpacity(0.08),
                child: Row(
                  children: [
                    Text('Gaji Bersih',
                        style: AppText.body1
                            .copyWith(fontWeight: FontWeight.w700,
                                color: AppColors.brandNavy)),
                    const Spacer(),
                    Text(
                      _fmtCurrency(slip.netSalary),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandNavy,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              GradientButton(
                label: 'Download Slip Gaji PDF',
                color: AppColors.brandNavy,
                icon: Icons.picture_as_pdf_rounded,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mengunduh slip gaji PDF...')),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero Stat ─────────────────────────────────────────────────
class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: Colors.white.withOpacity(0.75)),
            textAlign: TextAlign.center),
        const SizedBox(height: 3),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// ── Attendance Stat ───────────────────────────────────────────
class _AttendStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AttendStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: AppText.caption),
      ],
    );
  }
}

// ── Salary Row ────────────────────────────────────────────────
class _SalaryRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool isDeduction;
  final bool isTotal;

  const _SalaryRow({
    required this.label,
    required this.amount,
    required this.isDeduction,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (!isTotal)
            Container(
              width: 6, height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isDeduction ? AppColors.danger : AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Text(label,
                style: isTotal
                    ? AppText.body1.copyWith(fontWeight: FontWeight.w700)
                    : AppText.body2),
          ),
          Text(
            isDeduction && !isTotal ? '- $amount' : amount,
            style: GoogleFonts.inter(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal
                  ? (isDeduction ? AppColors.danger : AppColors.success)
                  : isDeduction
                      ? AppColors.danger
                      : AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}