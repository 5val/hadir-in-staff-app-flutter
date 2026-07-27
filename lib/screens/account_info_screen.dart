import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import 'otp_verification_screen.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: AppSession.currentUser.email);
    _phoneCtrl =
        TextEditingController(text: AppSession.currentUser.phoneNumber);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final newPhone = _phoneCtrl.text.trim();
    final newEmail = _emailCtrl.text.trim();
    final currentPhone = AppSession.currentUser.phoneNumber;

    // Check if phone number is already used by someone else
    final existingUser = AppSession.findUserByPhone(newPhone);
    if (existingUser != null && existingUser.id != AppSession.currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon sudah terpakai!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Simulate saving delay for polished UX
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    if (newPhone != currentPhone) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            newPhone: newPhone,
            newEmail: newEmail,
          ),
        ),
      );
    } else {
      AppSession.updateEmail(newEmail);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: AppColors.brandNavy,
        ),
      );
      Navigator.pop(context);
    }
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
                            user.name
                                .split(' ')
                                .map((w) => w[0])
                                .take(2)
                                .join(),
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
                      const SizedBox(
                          width: 16), // Jarak antara nama dan barcode

                      // ── Dummy Barcode / QR Code ──
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.slate200),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandNavy.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons
                              .qr_code_2_rounded, // Icon QR sebagai dummy barcode
                          size: 42,
                          color: AppColors.slate800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Editable Fields Section
                Text(
                  'Pengaturan Kontak',
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
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(v.trim())) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Text('Nomor Telepon (WhatsApp)', style: AppText.label),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppColors.slate900),
                        decoration: const InputDecoration(
                          hintText: 'Masukkan nomor telepon',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Nomor telepon wajib diisi';
                          }
                          if (v.trim().length < 9) {
                            return 'Nomor telepon tidak valid';
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: InfoTile(
                          icon: Icons.badge_outlined,
                          label: 'ID Karyawan',
                          value: user.employeeId,
                        ),
                      ),
                      const AppDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: InfoTile(
                          icon: Icons.assignment_ind_outlined,
                          label: 'NIK',
                          value: user.nik,
                        ),
                      ),
                      const AppDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: InfoTile(
                          icon: Icons.business_outlined,
                          label: 'Divisi',
                          value: AppSession.staff?.divisiNama ?? user.divisionId,
                        ),
                      ),
                      if (user.role != UserRole.admin) ...[
                        const AppDivider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          child: InfoTile(
                            icon: Icons.schedule_outlined,
                            label: 'Shift Kerja',
                            value:
                                '${user.currentShift.name} (${user.currentShift.startTimeStr}–${user.currentShift.endTimeStr})',
                          ),
                        ),
                      ],
                      const AppDivider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
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
                  onTap: _saveChanges,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
