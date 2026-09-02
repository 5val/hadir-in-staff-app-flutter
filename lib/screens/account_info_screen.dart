import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/phone_change_service.dart';
import '../services/session_service.dart';
import 'onboarding_documents_screen.dart';
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

  // ============================================================
  // GANTI NOMOR HP (2026-08-29)
  // ============================================================
  //
  // Membalik keputusan Sprint 2 "nomor HP hanya bisa diubah admin office".
  // Staff kini menggantinya sendiri, dibuktikan OTP yang dikirim ke EMAIL —
  // bukan ke nomor barunya, karena mengirim ke nomor tujuan akan sirkular.
  //
  // Email sendiri justru menjadi TIDAK bisa diubah dari layar ini: ia adalah
  // kanal pembuktian untuk segala hal lain (OTP login, pemulihan passcode,
  // dan penggantian nomor ini). Membiarkan keduanya bisa diubah dari satu
  // layar yang sama berarti siapa pun yang sempat memegang HP staff yang
  // sedang login bisa memindahkan SELURUH jalur pemulihan akun ke dirinya
  // sendiri dalam satu duduk.
  //
  // Sebelumnya tombol "Simpan Perubahan" di layar ini hanya memanggil
  // `Future.delayed` lalu memperbarui email di memori — tidak pernah ada
  // request ke server sama sekali. Tombol itu dihapus, bukan dibiarkan
  // berpura-pura menyimpan.

  /// Tahap 1: minta nomor barunya.
  ///
  /// Tahap 2 (verifikasi OTP) sengaja BUKAN di dalam sheet ini, melainkan
  /// [OtpVerificationScreen] — halaman yang bentuknya sama persis dengan
  /// langkah OTP saat pertama kali login. Buat staff, kedua kejadian itu
  /// identik ("buktikan diri Anda dengan kode dari email"), jadi tampilannya
  /// tidak sepantasnya berbeda.
  Future<void> _showChangePhoneSheet() async {
    // Sheet ini hanya MENGEMBALIKAN hasilnya; yang membuka halaman OTP adalah
    // pemanggil, setelah sheet benar-benar tertutup. Mem-`pop` sheet lalu
    // langsung `push` halaman lain di microtask yang sama membuat satu route
    // dicabut sementara route lain disisipkan ke Overlay yang sama dalam satu
    // frame, dan Flutter menolaknya.
    final pending = await showModalBottomSheet<_PendingPhoneChange>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ChangePhoneSheet(),
    );

    if (pending == null || !mounted) return;
    await _openOtpScreen(newPhone: pending.phone, email: pending.email);
  }

  /// Tahap 2: halaman OTP yang sama dengan alur login.
  Future<void> _openOtpScreen({
    required String newPhone,
    required String email,
  }) async {
    if (!mounted) return;
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          appBarTitle: 'Verifikasi Identitas',
          email: email,
          footnote:
              'Setelah nomor berganti, dokumen identitas perlu diajukan ulang. '
              'Dokumen yang sudah pernah disetujui bisa dipakai lagi tanpa '
              'memotret ulang.',
          onVerify: (code) => PhoneChangeService.verify(code),
          onResend: () => PhoneChangeService.requestOtp(newPhone),
        ),
      ),
    );

    if (verified == true) {
      await _onPhoneChanged(newPhone);
      return;
    }

    // Staff mundur dari layar OTP -> batalkan permintaan yang tertunda supaya
    // `pendingPhone` tidak menggantung di server. Best-effort: kegagalan di
    // sini tidak berdampak apa pun (nomor lama tetap berlaku).
    try {
      await PhoneChangeService.cancel();
    } catch (_) {}
  }

  /// Nomor sudah benar-benar berganti di server. Dua hal harus terjadi:
  /// tampilan lokal ikut berubah, dan staff diarahkan ke pengajuan ulang
  /// dokumen — gerbangnya sudah dibuka ulang oleh backend, jadi membiarkan
  /// staff di layar ini hanya menunda kebingungannya.
  Future<void> _onPhoneChanged(String newPhone) async {
    if (!mounted) return;
    setState(() => _phoneCtrl.text = newPhone);
    await SessionService.savePhone(newPhone);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Nomor HP berhasil diganti'),
        content: Text(
          'Mulai sekarang gunakan $newPhone untuk login.\n\n'
          'Karena identitas login Anda berpindah, dokumen identitas perlu '
          'diajukan ulang sebelum app bisa dipakai kembali.',
          style: AppText.body2,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ajukan Dokumen'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingDocumentsScreen()),
      (r) => false,
    );
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
                      // Email TIDAK bisa diubah dari sini. Ia adalah kanal
                      // pembuktian untuk semua hal lain — OTP login, pemulihan
                      // passcode, dan penggantian nomor HP di bawah. Kalau
                      // keduanya bisa diubah dari satu layar yang sama, siapa
                      // pun yang sempat memegang HP staff yang sedang login
                      // bisa memindahkan SELURUH jalur pemulihan akun ke
                      // dirinya sendiri dalam satu duduk.
                      TextFormField(
                        controller: _emailCtrl,
                        readOnly: true,
                        enabled: false,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.slate600),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.email_outlined),
                          suffixIcon: Icon(Icons.lock_outline_rounded,
                              size: 16, color: AppColors.slate400),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Email tidak bisa diubah — hubungi admin kantor Anda bila perlu diganti.',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.slate400),
                      ),
                      const SizedBox(height: 16),
                      Text('Nomor Telepon (WhatsApp)', style: AppText.label),
                      const SizedBox(height: 6),
                      // Sprint 2 OTP/auth overhaul: staff tidak lagi bisa
                      // ganti nomor HP terverifikasi sendiri — field ini
                      // read-only, hubungi admin office bila perlu diubah
                      // (lihat kartu "Hubungi Admin" di tab Akun).
                      TextFormField(
                        controller: _phoneCtrl,
                        readOnly: true,
                        enabled: false,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppColors.slate600),
                        decoration: const InputDecoration(
                          hintText: 'Masukkan nomor telepon',
                          prefixIcon: Icon(Icons.phone_android_outlined),
                          suffixIcon: Icon(Icons.lock_outline_rounded,
                              size: 16, color: AppColors.slate400),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showChangePhoneSheet,
                          icon: const Icon(Icons.sync_alt_rounded, size: 16),
                          label: const Text('Ubah Nomor HP'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandNavy,
                            side: const BorderSide(color: AppColors.slate300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nomor HP adalah identitas login Anda. Menggantinya perlu '
                        'verifikasi OTP lewat email, dan dokumen identitas harus '
                        'diajukan ulang setelahnya.',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.slate400),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hasil tahap 1 penggantian nomor HP: nomor yang diminta staff, plus email
/// tujuan OTP yang dikonfirmasi server. Dipakai sebagai nilai balik
/// `showModalBottomSheet` supaya perpindahan ke halaman OTP terjadi SETELAH
/// sheet-nya tertutup, bukan di tengah-tengah.
class _PendingPhoneChange {
  final String phone;
  final String email;

  const _PendingPhoneChange({required this.phone, required this.email});
}

/// Isi bottom sheet "Ubah Nomor HP".
///
/// StatefulWidget tersendiri, BUKAN `StatefulBuilder` dengan controller milik
/// pemanggil. Bedanya penting: `showModalBottomSheet` menyelesaikan future-nya
/// begitu route-nya di-`pop`, TAPI widget sheet masih hidup sepanjang animasi
/// menutupnya. Versi sebelumnya mem-`dispose()` `TextEditingController` tepat
/// setelah future itu selesai, sehingga `TextField` yang masih terpasang
/// memegang controller yang sudah mati — dan begitu sheet dibangun ulang di
/// jendela waktu itu (dismiss keyboard mengubah `viewInsets`, yang memang
/// dibaca sheet ini) build-nya melempar. Kegagalan di tengah build merembet
/// jadi error framework yang membingungkan: `children.contains(child)` di
/// `forgetChild`, dan `LateInitializationError: _children`.
///
/// Dengan State sendiri, controller dilepas di `dispose()` — yang jalan tepat
/// saat sheet benar-benar dicabut dari pohon, bukan lebih awal.
class _ChangePhoneSheet extends StatefulWidget {
  const _ChangePhoneSheet();

  @override
  State<_ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends State<_ChangePhoneSheet> {
  final _phoneCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 9) {
      setState(() => _error = 'Nomor HP tidak valid');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await PhoneChangeService.requestOtp(phone);
      if (!mounted) return;
      Navigator.pop(
        context,
        _PendingPhoneChange(phone: phone, email: result.email),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Ubah Nomor HP',
              style: AppText.headline3.copyWith(color: AppColors.slate900)),
          const SizedBox(height: 6),
          Text(
            'Nomor HP adalah identitas login Anda. Kami akan mengirim kode '
            'OTP ke email terdaftar untuk memastikan ini benar-benar Anda.',
            style: AppText.body2,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nomor HP baru, mis. 08123456789',
              prefixIcon: Icon(Icons.phone_android_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Setelah nomor berganti, Anda perlu mengajukan ulang dokumen '
              '(pas foto, KTP, BPJS, NPWP). Dokumen yang sudah pernah '
              'disetujui bisa dipakai lagi tanpa memotret ulang.',
              style: AppText.caption.copyWith(color: AppColors.slate700),
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Kirim Kode OTP',
            isLoading: _busy,
            onTap: _busy ? null : _requestOtp,
          ),
        ],
      ),
    );
  }
}
