import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/aturan_lampiran.dart';
import '../theme/app_theme.dart';

/// Kolom "Foto Bukti" bersama untuk form Izin/Dinas dan Cuti. Daftar foto
/// dimiliki pemanggil (supaya `_canSubmit` bisa membacanya); widget ini hanya
/// menampilkan judul sesuai aturan, thumbnail, dan tombol tambah/hapus.
/// Aturan [AturanLampiranJenis.tidakPerlu] -> tidak menampilkan apa pun.
class LeavePhotoField extends StatefulWidget {
  final AturanLampiranJenis rule;
  final List<File> photos;
  final int maxLampiran;
  final bool busy;
  final String hint;

  /// Dipanggil setelah [photos] diubah (tambah/hapus); pemanggil `setState`.
  final VoidCallback onChanged;

  const LeavePhotoField({
    super.key,
    required this.rule,
    required this.photos,
    required this.onChanged,
    this.maxLampiran = 3,
    this.busy = false,
    this.hint = 'Mis. surat dokter atau undangan.',
  });

  @override
  State<LeavePhotoField> createState() => _LeavePhotoFieldState();
}

class _LeavePhotoFieldState extends State<LeavePhotoField> {
  final _picker = ImagePicker();

  Future<void> _addPhoto() async {
    if (widget.photos.length >= widget.maxLampiran) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
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
                  color: AppColors.brandCyanDark),
              title: Text('Ambil Foto', style: AppText.body1),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.brandCyanDark),
              title: Text('Pilih dari Galeri', style: AppText.body1),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        // Ditekan supaya 3 foto sekaligus tetap jauh di bawah batas body
        // JSON backend (12 MB) setelah di-base64.
        imageQuality: 75,
        maxWidth: 1600,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka kamera/galeri. Periksa izin aplikasi.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (picked == null || !mounted) return;
    widget.photos.add(File(picked.path));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.rule.tampil) return const SizedBox.shrink();
    final photos = widget.photos;
    final canAdd = photos.length < widget.maxLampiran && !widget.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.rule.judul, style: AppText.label),
        const SizedBox(height: 2),
        Text(
          '${widget.hint} Maks. ${widget.maxLampiran} foto.',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < photos.length; i++)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      photos[i],
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 76,
                        height: 76,
                        color: AppColors.slate100,
                        child: const Icon(Icons.broken_image_rounded,
                            color: AppColors.slate400),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: widget.busy
                          ? null
                          : () {
                              photos.removeAt(i);
                              widget.onChanged();
                            },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                            color: AppColors.danger, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (canAdd)
              GestureDetector(
                key: const Key('leave_photo_add'),
                onTap: _addPhoto,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_rounded,
                          size: 22, color: AppColors.brandCyanDark),
                      const SizedBox(height: 4),
                      Text('Tambah',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandCyanDark)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
