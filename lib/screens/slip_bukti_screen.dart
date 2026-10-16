import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/api_client.dart';
import '../services/salary_service.dart';
import '../theme/app_theme.dart';

/// Penampil bukti pembayaran slip gaji. Gambar -> [InteractiveViewer] (zoom
/// cubit/geser); PDF -> `PdfPreview` dari paket `printing` yang sudah dipakai
/// app untuk slip (tanpa dependensi baru).
///
/// [loader] mengambil byte berkas (`GET .../gaji/slip/:id/bukti`); jenisnya
/// dikenali dari byte awal (`%PDF`).
class SlipBuktiScreen extends StatefulWidget {
  const SlipBuktiScreen({super.key, required this.title, required this.loader});

  final String title;
  final Future<BuktiFile> Function() loader;

  @override
  State<SlipBuktiScreen> createState() => _SlipBuktiScreenState();
}

class _SlipBuktiScreenState extends State<SlipBuktiScreen> {
  BuktiFile? _file;
  String? _error;
  bool _loading = true;

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
      final b = await widget.loader();
      if (!mounted) return;
      setState(() {
        _file = b;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat bukti pembayaran.';
        _loading = false;
      });
    }
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.brandNavy));
    }
    if (_error != null || _file == null || _file!.bytes.isEmpty) {
      return _errorView(_error ?? 'Bukti pembayaran tidak tersedia.');
    }
    return _content();
  }

  static const _unsupported = 'Bukti tidak bisa ditampilkan';

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                key: const Key('bukti-error'),
                textAlign: TextAlign.center,
                style: AppText.body2),
            const SizedBox(height: 12),
            TextButton.icon(
              key: const Key('bukti-retry'),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final bytes = _file!.bytes;
    if (_file!.isPdf) {
      return PdfPreview(
        key: const Key('bukti-pdf'),
        build: (_) async => bytes,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: false,
      );
    }
    return InteractiveViewer(
      key: const Key('bukti-image'),
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          // Bukan gambar yang bisa didekode dan bukan PDF.
          errorBuilder: (_, __, ___) => _errorView(_unsupported),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.brandNavy,
        foregroundColor: AppColors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 15)),
      ),
      body: _body(),
    );
  }
}
