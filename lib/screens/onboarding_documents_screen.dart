import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../services/api_client.dart';
import '../services/document_service.dart';
import '../services/session_service.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import '../widgets/uploaded_file_image.dart';

/// Gerbang onboarding — Fase 8.
///
/// Setelah staff membuat passcode untuk pertama kali, ia WAJIB mengunggah
/// dokumen identitas sebelum bisa memakai app. Daftar dokumen wajibnya
/// DINAMIS dan datang dari server (`GET /onboarding-status`): pas foto & KTP
/// selalu wajib, sedangkan BPJS & NPWP hanya wajib bila BPJS staff tersebut
/// aktif — itulah sebabnya layar ini tidak pernah meng-hardcode "4 dokumen".
///
/// Gerbangnya adalah PENGUNGGAHAN, bukan persetujuan: begitu setiap dokumen
/// wajib pernah dikirim, staff boleh masuk. Penolakan oleh HRD kemudian
/// hanya memunculkan notifikasi untuk mengunggah ulang, tidak mengunci app
/// lagi (aturan yang sudah ditetapkan backend, bukan diputuskan di sini).
///
/// PERBAIKAN: layar ini dulu hanya merender `requiredDocuments`, sehingga
/// staff yang BPJS-nya tidak aktif hanya pernah melihat 2 kartu (pas foto &
/// KTP) dan TIDAK PUNYA JALAN untuk mengunggah BPJS/NPWP sama sekali —
/// begitu dua dokumen wajib itu terkirim, `completed` langsung true dan layar
/// melompat ke app. Sekarang keempat dokumen selalu ditampilkan; yang tidak
/// diwajibkan server diberi label OPSIONAL dan tidak memblokir tombol masuk.
class OnboardingDocumentsScreen extends StatefulWidget {
  /// Mode kelola: dibuka dari menu Akun untuk melengkapi/mengganti dokumen
  /// setelah staff berada di dalam app. Bedanya hanya navigasi — layar tidak
  /// lagi menjadi "gerbang", jadi tombolnya menutup halaman, bukan
  /// mendorong MainScreen baru.
  final bool manageMode;

  const OnboardingDocumentsScreen({super.key, this.manageMode = false});

  @override
  State<OnboardingDocumentsScreen> createState() =>
      _OnboardingDocumentsScreenState();
}

class _OnboardingDocumentsScreenState extends State<OnboardingDocumentsScreen> {
  final _picker = ImagePicker();

  OnboardingStatus? _status;
  bool _loading = true;
  String? _error;

  /// Jenis dokumen yang sedang diunggah (untuk spinner per kartu).
  String? _uploading;

  /// Dokumen lama yang sudah pernah DISETUJUI, dipetakan per jenis. Hanya
  /// terisi saat gerbang ini dibuka ulang (staff baru mengganti nomor HP) --
  /// itulah satu-satunya keadaan di mana "pakai yang lama" masuk akal.
  Map<String, ReusableDocument> _reusable = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await DocumentService.onboardingStatus();

      // Hanya relevan saat pengajuan ULANG. Best-effort: gagal memuat daftar
      // dokumen lama tidak boleh menghalangi staff mengunggah yang baru.
      Map<String, ReusableDocument> reusable = const {};
      if (status.isResubmission) {
        try {
          final previous = await DocumentService.previousDocuments();
          reusable = {for (final d in previous) d.jenis: d};
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _status = status;
        _reusable = reusable;
        _loading = false;
      });
      // Lompat otomatis HANYA bila benar-benar tidak ada lagi yang bisa
      // diunggah. Dulu syaratnya `status.completed` (dokumen WAJIB saja),
      // sehingga kartu BPJS & NPWP tidak pernah sempat terlihat.
      if (!widget.manageMode && status.allSubmitted) _goToApp();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _goToApp() {
    if (widget.manageMode) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (r) => false,
    );
  }

  /// Ajukan ulang berkas lama yang sudah disetujui, tanpa memotret apa pun.
  ///
  /// Server membuat pengajuan BARU yang menunjuk berkas yang sama, jadi
  /// riwayatnya tetap utuh dan HRD tetap melihatnya sebagai kejadian baru.
  Future<void> _reusePrevious(OnboardingDocument doc) async {
    setState(() => _uploading = doc.jenis);
    try {
      await DocumentService.reusePrevious(doc.jenis);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${doc.label} diajukan ulang memakai berkas sebelumnya'),
          backgroundColor: AppColors.brandNavy,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _pickAndUpload(OnboardingDocument doc) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.brandNavy),
              title: Text('Ambil Foto', style: AppText.body1),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.brandNavy),
              title: Text('Pilih dari Galeri', style: AppText.body1),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      // Ditekan agar unggahan tetap di bawah batas 8 MB backend, tanpa
      // membuat KTP jadi tidak terbaca.
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (picked == null) return;

    // ClickUp 86eyh8avk: kumpulkan `catatanStaff` opsional di sini —
    // staff bisa memberi tahu HRD kalau ada data yang diisi admin ternyata
    // salah (mis. nama), sebelum dokumen ini masuk antrean review admin.
    // Backend & tampilan admin (staff/page.tsx "Catatan staff: ...") sudah
    // siap menampung field ini, layar ini dulu tidak pernah mengumpulkannya.
    if (!mounted) return;
    final catatanStaff = await _promptCatatanStaff(doc);
    if (!mounted) return;

    setState(() => _uploading = doc.jenis);
    try {
      await DocumentService.upload(
        jenis: doc.jenis,
        file: File(picked.path),
        catatanStaff: catatanStaff,
      );
      if (!mounted) return;
      setState(() => _uploading = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${doc.label} berhasil diunggah'),
          backgroundColor: AppColors.brandLimeDark,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploading = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    }
  }

  /// Bottom sheet opsional: minta `catatanStaff` sebelum dokumen dikirim.
  /// "Lewati" maupun menutup sheet sama-sama lanjut mengunggah tanpa
  /// catatan — langkah ini murni buat menambahkan keterangan, bukan buat
  /// membatalkan unggahan (file sudah dipilih di langkah sebelumnya).
  Future<String?> _promptCatatanStaff(OnboardingDocument doc) async {
    final ctrl = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Catatan untuk ${doc.label} (opsional)',
                style:
                    AppText.body1.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Ada yang perlu dijelaskan ke HRD? Misalnya kalau ada data '
              'diri yang diisi admin ternyata salah.',
              style: AppText.caption,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.slate900),
              decoration: const InputDecoration(
                hintText: 'Contoh: Nama saya salah, seharusnya Budi Santoso',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Lewati'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                    child: const Text('Unggah'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _logout() async {
    await SessionService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(destination: LoginDestination.landing),
      ),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keempat dokumen yang dilacak backend, bukan hanya yang wajib.
    final docs = _status?.allDocuments ?? const <OnboardingDocument>[];
    final done = docs.where((d) => d.submitted).length;

    // Gerbang masuk app tetap milik server: hanya dokumen WAJIB yang
    // menentukan. BPJS/NPWP opsional boleh dilewati.
    final requiredDocs =
        _status?.requiredDocuments ?? const <OnboardingDocument>[];
    final canEnter = requiredDocs.isNotEmpty &&
        requiredDocs.every((d) => d.submitted);

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        automaticallyImplyLeading: widget.manageMode,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: Text(widget.manageMode ? 'Dokumen Saya' : 'Lengkapi Data Diri',
            style: AppText.headline3.copyWith(color: AppColors.white)),
        actions: [
          if (!widget.manageMode)
            TextButton(
              onPressed: _logout,
              child: Text('Keluar',
                  style: GoogleFonts.inter(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _buildIntro(done, docs.length),
                      const SizedBox(height: 20),
                      ...docs.map(_buildDocCard),
                      const SizedBox(height: 24),
                      // Tombol masuk aktif begitu dokumen WAJIB terkirim —
                      // BPJS/NPWP yang opsional boleh menyusul lewat menu
                      // Akun → Dokumen Saya.
                      if (canEnter)
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _goToApp,
                            child: Text(widget.manageMode
                                ? 'Selesai'
                                : (done >= docs.length
                                    ? 'Masuk ke Aplikasi'
                                    : 'Lanjut ke Aplikasi (lengkapi nanti)')),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.slate400),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: AppText.body2),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );

  Widget _buildIntro(int done, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gerbang ini bisa muncul karena DUA sebab berbeda: onboarding
          // pertama kali, atau nomor HP yang baru saja diganti. Tanpa
          // penjelasan ini, staff yang sudah lama bekerja tiba-tiba diminta
          // dokumen lagi tanpa tahu kenapa.
          if (_status?.isResubmission == true) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nomor HP Anda baru saja diganti. Karena nomor HP adalah '
                      'identitas login, dokumen identitas perlu diajukan ulang. '
                      'Dokumen yang sudah pernah disetujui bisa dipakai lagi '
                      'tanpa memotret ulang.',
                      style: AppText.caption
                          .copyWith(color: AppColors.slate700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandNavy.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_rounded,
                    color: AppColors.brandNavy, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Satu langkah lagi',
                        style: AppText.headline3
                            .copyWith(color: AppColors.slate900)),
                    const SizedBox(height: 2),
                    Text('$done dari $total dokumen terkirim',
                        style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Unggah dokumen berikut untuk mengaktifkan akun Anda. '
            'Dokumen akan diperiksa HRD, tapi Anda sudah bisa memakai aplikasi '
            'segera setelah dokumen wajib terkirim. Dokumen bertanda OPSIONAL '
            'tetap boleh diunggah dan bisa dilengkapi kapan saja lewat menu '
            'Akun → Dokumen Saya.',
            style: AppText.body2,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              backgroundColor: AppColors.slate100,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.brandLimeDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilkan berkas terunggah satu layar penuh.
  ///
  /// Halaman gelap penuh, bukan `Dialog` kecil seperti versi pertama: yang
  /// paling sering perlu dipastikan staff adalah apakah tulisan di KTP/NPWP-nya
  /// benar-benar terbaca, dan itu butuh seluruh layar plus cubit-zoom
  /// ([InteractiveViewer]) — mustahil dinilai dari kotak kecil.
  void _showFullPreview(OnboardingDocument doc) => _openFullPreview(
        label: doc.label,
        fileUrl: doc.fileUrl,
        statusText: doc.latestStatus == 'approved'
            ? 'Disetujui'
            : doc.isRejected
                ? 'Ditolak'
                : 'Menunggu review',
      );

  void _openFullPreview({
    required String label,
    required String fileUrl,
    required String statusText,
  }) {
    // Route BIASA yang opaque, bukan `PageRouteBuilder(opaque: false)`.
    // Route transparan membiarkan halaman di bawahnya tetap terpasang dan
    // ikut dibangun ulang di belakang layar penuh ini — tidak ada gunanya di
    // sini (latarnya toh hitam pekat), sekadar menambah kerumitan Overlay.
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(statusText,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: UploadedFileImage(
                      localPath: null,
                      remoteUrl: fileUrl,
                      fit: BoxFit.contain,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text(
                  'Cubit untuk memperbesar. Pastikan seluruh tulisan terbaca '
                  'jelas — berkas yang buram biasanya ditolak HRD.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.white54, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocCard(OnboardingDocument doc) {
    final isUploading = _uploading == doc.jenis;
    final submitted = doc.submitted;

    Color statusColor;
    String statusLabel;
    if (doc.isRejected) {
      statusColor = AppColors.danger;
      statusLabel = 'DITOLAK';
    } else if (doc.latestStatus == 'approved') {
      statusColor = AppColors.brandLimeDark;
      statusLabel = 'DISETUJUI';
    } else if (submitted) {
      statusColor = AppColors.warning;
      statusLabel = 'MENUNGGU REVIEW';
    } else {
      statusColor = AppColors.slate400;
      statusLabel = 'BELUM DIUNGGAH';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: doc.isRejected ? AppColors.danger : AppColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                submitted && !doc.isRejected
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: statusColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(doc.label,
                              style: AppText.body1
                                  .copyWith(fontWeight: FontWeight.w700)),
                        ),
                        // Penanda dokumen yang tidak diwajibkan server untuk
                        // staff ini (mis. BPJS/NPWP saat BPJS-nya tidak aktif).
                        if (!doc.required) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('OPSIONAL',
                                style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.slate700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(doc.description, style: AppText.caption),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: statusColor),
                ),
              ),
            ],
          ),
          // Jalan pintas saat gerbang dibuka ulang: berkas yang sudah pernah
          // diunggah boleh diajukan lagi apa adanya, jadi ganti nomor HP tidak
          // berarti staff harus memotret ulang KTP/BPJS/NPWP-nya.
          //
          // Pratinjaunya sengaja sebesar kartu unggahan biasa dan bisa diketuk
          // untuk diperbesar: staff perlu MEMASTIKAN berkas lama itu memang
          // yang benar sebelum mengajukannya ulang -- versi pertama fitur ini
          // hanya menampilkan thumbnail 40 piksel yang tidak bisa diapa-apakan.
          if (!submitted && _reusable.containsKey(doc.jenis)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandCyan.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brandCyan.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 15, color: AppColors.brandCyanDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Anda sudah pernah mengunggah ${doc.label}',
                          style: AppText.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _reusable[doc.jenis]!.isApproved
                              ? AppColors.brandLime.withOpacity(0.25)
                              : AppColors.warning.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _reusable[doc.jenis]!.statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: _reusable[doc.jenis]!.isApproved
                                ? AppColors.brandLimeDark
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openFullPreview(
                      label: doc.label,
                      fileUrl: _reusable[doc.jenis]!.fileUrl,
                      statusText: _reusable[doc.jenis]!.statusLabel,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 3 / 2,
                            child: Container(
                              color: AppColors.slate100,
                              width: double.infinity,
                              child: UploadedFileImage(
                                localPath: null,
                                remoteUrl: _reusable[doc.jenis]!.fileUrl,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.zoom_out_map_rounded,
                                      size: 11, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('Perbesar',
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          isUploading ? null : () => _reusePrevious(doc),
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(
                        'Ajukan Ulang Berkas Ini',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandCyanDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atau unggah berkas baru lewat tombol di bawah.',
                    style: AppText.caption.copyWith(color: AppColors.slate400),
                  ),
                ],
              ),
            ),
          ],
          // Pratinjau berkas yang SUDAH terunggah. Sebelum ini layar onboarding
          // cuma memberi tahu SUDAH/BELUM diunggah, sehingga staff tidak punya
          // cara memastikan berkas yang benar yang terkirim (mis. KTP tertukar
          // dengan BPJS) selain menunggu HRD menolaknya berhari-hari kemudian.
          if (doc.hasPreview) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showFullPreview(doc),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Rasio 3:2 -- KTP/BPJS/NPWP semuanya kartu mendatar, jadi
                    // bingkai lebar memperlihatkan isinya, bukan memotongnya
                    // jadi kotak kecil seperti thumbnail 54px sebelumnya.
                    AspectRatio(
                      aspectRatio: 3 / 2,
                      child: Container(
                        color: AppColors.slate100,
                        width: double.infinity,
                        child: UploadedFileImage(
                          localPath: null,
                          remoteUrl: doc.fileUrl,
                        ),
                      ),
                    ),
                    // Gradien gelap di bawah supaya teks tetap terbaca di atas
                    // foto seterang apa pun.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.65),
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Berkas ${doc.label} yang terunggah',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.zoom_out_map_rounded,
                                      size: 11, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('Perbesar',
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (doc.isRejected && (doc.catatanAdmin ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Catatan HRD: ${doc.catatanAdmin}',
                  style: AppText.caption.copyWith(color: AppColors.danger)),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: isUploading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _pickAndUpload(doc),
                    icon: const Icon(Icons.file_upload_outlined, size: 18),
                    label: Text(
                      submitted ? 'Unggah Ulang' : 'Unggah ${doc.label}',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
