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

class _SalaryScreenState extends State<SalaryScreen> {
  final user   = SampleData.currentUser;
  final slips  = SampleData.salaryHistory;
  int _idx     = 0;

  SalarySlip get _slip => slips[_idx];

  String _fmtCurrency(int amount) =>
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0)
          .format(amount);

  String _fmtCurrencyShort(int amount) {
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return _fmtCurrency(amount);
  }

  @override
  Widget build(BuildContext context) {
    final income = _slip.components.where((c) => !c.isDeduction).toList();
    final deductions = _slip.components.where((c) => c.isDeduction).toList();

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ────────────────────────────────────
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FINANCIAL STATEMENT',
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppColors.brandNavy, letterSpacing: 1.2,
                          )),
                      Text('Salary Slip',
                          style: AppText.headline2.copyWith(
                              color: AppColors.slate900)),
                    ],
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.slate200),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Period selector ───────────────────
                  _buildPeriodDropdown(),
                  const SizedBox(height: 16),

                  // ── Hero card ─────────────────────────
                  _buildHeroCard(),
                  const SizedBox(height: 16),

                  // ── 4 stat cards grid ─────────────────
                  _buildStatGrid(income),
                  const SizedBox(height: 20),

                  // ── Earnings detail ───────────────────
                  _buildEarningsDetail(income, deductions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _slip.periodStart.day <= 15
                  ? 'Start of Month - ${_slip.period}'
                  : 'End of Month - ${_slip.period}',
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.slate900),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _idx,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.slate600, size: 20),
              isDense: true,
              items: slips.asMap().entries.map((e) =>
                DropdownMenuItem(value: e.key, child: Text(e.value.period))).toList(),
              onChanged: (v) { if (v != null) setState(() => _idx = v); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.brandNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text('Total Take Home Pay',
              style: GoogleFonts.inter(
                fontSize: 13, color: Colors.white.withOpacity(0.75),
              )),
          const SizedBox(height: 6),
          Text(
            'IDR ${_fmtCurrency(_slip.netSalary).replaceAll(',', '.')}',
            style: GoogleFonts.inter(
              fontSize: 30, fontWeight: FontWeight.w900,
              color: Colors.white, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: AppColors.brandLime, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                'Transferred on ${DateFormat("MMM dd, yyyy").format(_slip.periodEnd)}',
                style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(List<SalaryComponent> income) {
    // Pick up to 4 income components for the grid
    final display = income.take(4).toList();
    final icons   = [
      Icons.account_balance_wallet_outlined,
      Icons.timer_outlined,
      Icons.favorite_border_rounded,
      Icons.directions_car_outlined,
    ];
    final colors = [
      AppColors.brandNavy,
      AppColors.brandCyanDark,
      AppColors.danger,
      const Color(0xFF374151),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: display.length,
      itemBuilder: (_, i) {
        final c = display[i];
        final color = colors[i % colors.length];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandNavy.withOpacity(0.04),
                blurRadius: 8, offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icons[i % icons.length], color: color, size: 18),
              ),
              const Spacer(),
              Text(
                c.label.toUpperCase().replaceAll(' ', '\n'),
                style: GoogleFonts.inter(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppColors.slate400, letterSpacing: 0.6,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 3),
              Text(
                _fmtCurrencyShort(c.amount),
                style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
                width: (c.amount / _slip.totalIncome) * 100,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarningsDetail(
      List<SalaryComponent> income, List<SalaryComponent> deductions) {
    final allItems = [...income, ...deductions];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Earnings Detail',
                style: AppText.headline3.copyWith(color: AppColors.slate900)),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mengunduh PDF...')),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download_outlined,
                      color: AppColors.brandNavy, size: 16),
                  const SizedBox(width: 4),
                  Text('PDF EXPORT',
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.brandNavy, letterSpacing: 0.5,
                      )),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ...allItems.map((c) => _EarningsRow(
                    label: c.label,
                    subLabel: _getSubLabel(c),
                    amount: _fmtCurrency(c.amount),
                    isDeduction: c.isDeduction,
                    accentColor: c.isDeduction ? AppColors.danger : _getAccentColor(c),
                  )),
              const AppDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: AppColors.slate400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'After tax and mandatory pension deductions.',
                        style: AppText.caption,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('GROSS:',
                            style: AppText.caption.copyWith(letterSpacing: 0.5)),
                        Text(_fmtCurrencyShort(_slip.totalIncome),
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w800,
                                color: AppColors.slate900)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  String _getSubLabel(SalaryComponent c) {
    if (c.label.contains('Pokok')) return 'Level ${SampleData.currentUser.position.name}';
    if (c.label.contains('Lembur')) return '${_slip.overtimeHours * 5.3} Hours total';
    if (c.label.contains('Kesehatan')) return 'Insurance Tier 1';
    if (c.label.contains('Transport')) return 'Reimbursement';
    if (c.label.contains('Makan')) return 'Daily Allowance';
    if (c.label.contains('BPJS')) return 'Mandatory';
    if (c.label.contains('Keterlambatan')) return 'Deduction';
    return '';
  }

  Color _getAccentColor(SalaryComponent c) {
    if (c.label.contains('Pokok')) return AppColors.brandNavy;
    if (c.label.contains('Lembur')) return AppColors.brandCyanDark;
    if (c.label.contains('Kesehatan')) return AppColors.danger;
    return const Color(0xFF374151);
  }
}

class _EarningsRow extends StatelessWidget {
  final String label, subLabel, amount;
  final bool isDeduction;
  final Color accentColor;

  const _EarningsRow({
    required this.label, required this.subLabel, required this.amount,
    required this.isDeduction, required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.slate900)),
                if (subLabel.isNotEmpty)
                  Text(subLabel, style: AppText.body2.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(
            isDeduction ? '- ${amount.trim()}' : amount.trim(),
            style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: isDeduction ? AppColors.danger : AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}