import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: AppSession.currentUser.email);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _saveEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    // Simulate saving delay for polished UX
    await Future.delayed(const Duration(milliseconds: 600));

    AppSession.updateEmail(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email berhasil diperbarui!'),
        backgroundColor: AppColors.brandNavy,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: const StaffAppBar(
        title: 'Informasi Akun',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Avatar Header card
                SectionCard(
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: AppColors.brandNavy,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user.name.split(' ').map((w) => w[0]).take(2).join(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: AppText.headline3.copyWith(
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.position.name,
                              style: AppText.body2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Editable Fields Section
                Text(
                  'Pengaturan Email',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alamat Email', style: AppText.label),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.slate900),
                        decoration: const InputDecoration(
                          hintText: 'Masukkan email baru',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          // Simple regex validation
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Read-only Information Section
                Text(
                  'Detail Karyawan',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandNavy,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: InfoTile(
                          icon: Icons.badge_outlined,
                          label: 'ID Karyawan',
                          value: user.employeeId,
                        ),
                      ),
                      const AppDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: InfoTile(
                          icon: Icons.assignment_ind_outlined,
                          label: 'NIK',
                          value: user.nik,
                        ),
                      ),
                      const AppDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: InfoTile(
                          icon: Icons.business_outlined,
                          label: 'Divisi',
                          value: user.divisionId == 'D002' ? 'IT' : 'Marketing',
                        ),
                      ),
                      const AppDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: InfoTile(
                          icon: Icons.schedule_outlined,
                          label: 'Shift Kerja',
                          value: '${user.currentShift.name} (${user.currentShift.startTimeStr}–${user.currentShift.endTimeStr})',
                        ),
                      ),
                      const AppDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: InfoTile(
                          icon: Icons.work_outline_rounded,
                          label: 'Jabatan',
                          value: user.position.name,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save button
                GradientButton(
                  label: 'Simpan Perubahan',
                  isLoading: _isSaving,
                  onTap: _saveEmail,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
