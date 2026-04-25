import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key, required this.isFromAccount});
  final bool isFromAccount;
  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  final user  = SampleData.currentUser;
  final slips = SampleData.salaryHistory;
  int _idx    = 0;

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
                  if(widget.isFromAccount)
                    // Back button
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
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppColors.brandNavy, letterSpacing: 1.2,
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
                  // ── Month selector (selectbox) ─────────
                  _buildMonthSelector(),
                  const SizedBox(height: 16),

                  // ── Salary Card (clickable → detail) ──
                  _buildSalaryCard(),
                  const SizedBox(height: 20),

                  // ── Salary Setting ────────────────────
                  _buildSalarySetting(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Month Selector — Dropdown / Selectbox ──────────────────
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
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.brandNavy,
                size: 22,
              ),
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
                          fontWeight: i == _idx
                              ? FontWeight.w700
                              : FontWeight.w500,
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

  Widget _buildSalaryCard() {
    return GestureDetector(
      onTap: () => WidgetsBinding.instance.addPostFrameCallback(() {
          _showSalaryDetail();
        } as FrameCallback),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.brandNavy,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandNavy.withOpacity(0.3),
              blurRadius: 20, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_slip.period,
                      style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      )),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.brandLime.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text('Lihat Detail',
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppColors.brandLime,
                          )),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 10, color: AppColors.brandLime),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: 52, height: 52,
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
                  fontSize: 12, color: Colors.white.withOpacity(0.75),
                )),
            const SizedBox(height: 6),
            Text(
              _fmtCurrency(_slip.netSalary),
              style: GoogleFonts.inter(
                fontSize: 28, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
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
                  'Ditransfer ${DateFormat("dd MMM yyyy").format(_slip.periodEnd)}',
                  style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Salary Detail Bottom Sheet ─────────────────────────────
  void _showSalaryDetail() {
    final income     = _slip.components.where((c) => !c.isDeduction).toList();
    final deductions = _slip.components.where((c) => c.isDeduction).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: ListView(
            controller: ctrl,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detail Gaji',
                          style: AppText.headline2
                              .copyWith(color: AppColors.slate900)),
                      Text(_slip.period, style: AppText.body2),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mengunduh PDF...')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.brandNavy.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.download_rounded,
                              color: AppColors.brandNavy, size: 16),
                          const SizedBox(width: 5),
                          Text('Download PDF',
                              style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: AppColors.brandNavy,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Net salary hero
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.brandNavy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('Gaji Bersih (Take Home Pay)',
                        style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white.withOpacity(0.75),
                        )),
                    const SizedBox(height: 6),
                    Text(_fmtCurrency(_slip.netSalary),
                        style: GoogleFonts.inter(
                          fontSize: 24, fontWeight: FontWeight.w900,
                          color: Colors.white,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Income
              Text('Pendapatan',
                  style: AppText.headline3.copyWith(color: AppColors.slate900)),
              const SizedBox(height: 8),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: income.map((c) => _EarningsRow(
                    label: c.label,
                    amount: _fmtCurrency(c.amount),
                    isDeduction: false,
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Deductions
              Text('Potongan',
                  style: AppText.headline3.copyWith(color: AppColors.slate900)),
              const SizedBox(height: 8),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: deductions.map((c) => _EarningsRow(
                    label: c.label,
                    amount: _fmtCurrency(c.amount),
                    isDeduction: true,
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Summary
              SectionCard(
                color: AppColors.brandNavy.withOpacity(0.04),
                child: Column(
                  children: [
                    _SummaryRow('Total Pendapatan',
                        _fmtCurrency(_slip.totalIncome), false),
                    const AppDivider(),
                    _SummaryRow('Total Potongan',
                        _fmtCurrency(_slip.totalDeduction), true),
                    const AppDivider(),
                    _SummaryRow('Gaji Bersih',
                        _fmtCurrency(_slip.netSalary), false, bold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Salary Setting ─────────────────────────────────────────
  Widget _buildSalarySetting() {
    final settings = [
      (Icons.account_balance_wallet_rounded, 'Gaji Pokok',
          _fmtCurrencyShort(user.position.baseSalary),
          'Berdasarkan jabatan ${user.position.name}',
          AppColors.brandNavy),
      (Icons.star_rounded, 'Bonus Harian',
          _fmtCurrencyShort(user.position.dailyBonus),
          'Per hari kerja hadir tepat waktu',
          AppColors.brandLimeDark),
      (Icons.favorite_rounded, 'Tunjangan Kesehatan',
          _fmtCurrencyShort(user.position.healthAllowance),
          'Dibayarkan per bulan',
          AppColors.danger),
      (Icons.directions_car_rounded, 'Tunjangan Transport',
          _fmtCurrencyShort(user.position.transportAllowance),
          'Dibayarkan per bulan',
          const Color(0xFF374151)),
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
                      color: s.$5.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(s.$1, color: s.$5, size: 18),
                  ),
                  const Spacer(),
                  Text(s.$2,
                      style: GoogleFonts.inter(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppColors.slate700,
                      ),
                      maxLines: 2),
                  const SizedBox(height: 2),
                  Text(s.$3,
                      style: GoogleFonts.inter(
                        fontSize: 17, fontWeight: FontWeight.w800,
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

class _EarningsRow extends StatelessWidget {
  final String label, amount;
  final bool isDeduction;
  const _EarningsRow({
    required this.label, required this.amount, required this.isDeduction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 3, height: 32,
            decoration: BoxDecoration(
              color: isDeduction ? AppColors.danger : AppColors.brandLimeDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.slate900)),
          ),
          Text(
            isDeduction ? '- $amount' : amount,
            style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700,
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
  const _SummaryRow(this.label, this.amount, this.isDeduction, {this.bold = false});

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