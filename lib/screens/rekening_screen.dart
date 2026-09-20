import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/rekening_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Staff mengisi/mengubah rekening gaji sendiri (meeting klien 2026-09-20).
/// Menutup dengan `true` bila rekening berhasil disimpan.
class RekeningScreen extends StatefulWidget {
  const RekeningScreen({super.key});

  @override
  State<RekeningScreen> createState() => _RekeningScreenState();
}

class _RekeningScreenState extends State<RekeningScreen> {
  static const _bankUmum = [
    'BCA', 'BRI', 'BNI', 'Mandiri', 'BSI', 'CIMB Niaga', 'Permata', 'Danamon',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bankCtrl;
  late final TextEditingController _nomorCtrl;
  late final TextEditingController _pemilikCtrl;
  bool _saving = false;

  StaffProfile? get _staff => AppSession.staff;
  bool get _sudahAda => _staff?.rekeningLengkap ?? false;

  @override
  void initState() {
    super.initState();
    final s = _staff;
    _bankCtrl = TextEditingController(text: s?.namaBank ?? '');
    _nomorCtrl = TextEditingController(text: s?.nomorRekening ?? '');
    // Nama pemilik default ke nama staff: kasus umum, dan tetap bisa diubah
    // (rekening atas nama pasangan/orang tua, dsb.).
    _pemilikCtrl = TextEditingController(
        text: (s?.namaPemilikRekening.isNotEmpty ?? false)
            ? s!.namaPemilikRekening
            : (s?.nama ?? ''));
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _nomorCtrl.dispose();
    _pemilikCtrl.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmReplace() async {
    if (!_sudahAda) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti rekening gaji?'),
        content: const Text(
            'Gaji berikutnya akan ditransfer ke rekening yang baru. '
            'HRD akan menerima pemberitahuan penggantian ini.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, ganti')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bankBerubah = _bankCtrl.text.trim() != (_staff?.namaBank ?? '');
    final nomorBerubah = RekeningValidator.normalizeNomor(_nomorCtrl.text) !=
        (_staff?.nomorRekening ?? '');
    // Peringatan hanya bila tujuan transfernya benar-benar berubah.
    if (_sudahAda && (bankBerubah || nomorBerubah) && !await _confirmReplace()) {
      return;
    }

    setState(() => _saving = true);
    try {
      await RekeningService.save(
        namaBank: _bankCtrl.text,
        nomorRekening: _nomorCtrl.text,
        namaPemilikRekening: _pemilikCtrl.text,
      );
      if (!mounted) return;
      _snack('Rekening disimpan.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: const StaffAppBar(title: 'Rekening Gaji'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 18, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Gaji Anda ditransfer ke rekening ini. Pastikan nomor dan '
                          'nama pemilik sesuai buku tabungan/aplikasi bank Anda.',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              height: 1.45,
                              color: const Color(0xFF1D4ED8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nama Bank', style: AppText.label),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _bankCtrl,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        validator: RekeningValidator.bank,
                        decoration: const InputDecoration(
                          hintText: 'mis. BCA',
                          counterText: '',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final bank in _bankUmum)
                            ActionChip(
                              label: Text(bank,
                                  style: GoogleFonts.inter(fontSize: 11.5)),
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _bankCtrl.text = bank),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Nomor Rekening', style: AppText.label),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nomorCtrl,
                        keyboardType: TextInputType.number,
                        // Spasi/strip yang terlanjur dipaste dibuang server-side
                        // dan di sini; yang boleh diketik hanya angka.
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9\s-]')),
                          LengthLimitingTextInputFormatter(30),
                        ],
                        validator: RekeningValidator.nomor,
                        decoration: const InputDecoration(
                          hintText: 'Hanya angka, 5-20 digit',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Nama Pemilik Rekening', style: AppText.label),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pemilikCtrl,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 150,
                        validator: RekeningValidator.pemilik,
                        decoration: const InputDecoration(
                          hintText: 'Sesuai buku tabungan',
                          counterText: '',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: 'Simpan Rekening',
                  isLoading: _saving,
                  onTap: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
