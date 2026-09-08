/// Petunjuk MENU untuk setiap notifikasi.
///
/// Masalah yang diperbaiki: notifikasi backend hanya menyebut APA yang
/// terjadi ("Dokumen KTP Anda ditolak: fotonya buram. Silakan upload ulang
/// dokumen yang benar."), tapi tidak pernah menyebut DI MANA staff harus
/// menindaklanjutinya. Staff lalu menebak-nebak sendiri lewat tab mana
/// dokumen bisa diunggah ulang.
///
/// Pemetaannya ditaruh di app — bukan di teks yang dikirim backend — karena
/// nama menu adalah milik UI app ini (tab "Akun", halaman "Dokumen Saya");
/// backend tidak tahu, dan tidak seharusnya tahu, susunan menu mobile.
/// Kalau menu berubah, cukup file ini yang ikut berubah.
class NotificationMenuHints {
  const NotificationMenuHints._();

  /// Jalur menu per `type` notifikasi backend (lihat `notification.create`
  /// di repo `hadir-in-api-backend-express-js`).
  static const _byType = <String, String>{
    // Dokumen onboarding (pas foto/KTP/BPJS/NPWP).
    'document_rejected': 'Akun > Dokumen Saya',
    'document_approved': 'Akun > Dokumen Saya',
    'document_submitted': 'Akun > Dokumen Saya',

    // Cuti & izin.
    'leave_approved': 'Cuti & Izin > Riwayat Pengajuan',
    'leave_rejected': 'Cuti & Izin > Riwayat Pengajuan',
    'leave_request_submitted': 'Cuti & Izin > Riwayat Pengajuan',

    // Lembur.
    'lembur_request_submitted': 'Cuti & Izin > Lembur',
    'lembur_approved': 'Cuti & Izin > Lembur',
    'lembur_rejected': 'Cuti & Izin > Lembur',

    // Log staff (popup naik jabatan / SP) — arsipnya di info akun.
    'promotion': 'Akun > Informasi Akun',
    'surat_peringatan': 'Akun > Informasi Akun',

    // Pindah lokasi & verifikasi nomor.
    'location_transfer_approved': 'Akun > Informasi Akun',
    'location_transfer_rejected': 'Akun > Informasi Akun',
    'staff_phone_changed': 'Akun > Informasi Akun',
    'phone_verification': 'Akun > Informasi Akun',

    // Absensi (dibangkitkan app maupun server).
    'attendance_reminder': 'Home > Aktivitas Hari Ini',
    'attendance_auto_checkout': 'Home > Aktivitas Hari Ini',
    'attendance_overtime_limit': 'Home > Aktivitas Hari Ini',
    'attendance_missing_checkout': 'Home > Aktivitas Hari Ini',
    'break_reminder': 'Home > Aktivitas Hari Ini',
  };

  /// Tebakan berdasarkan kata kunci — jaring pengaman untuk `type` baru yang
  /// ditambahkan backend setelah file ini ditulis, supaya notifikasinya tetap
  /// mendapat petunjuk menu alih-alih kosong.
  static const _byKeyword = <String, String>{
    'document': 'Akun > Dokumen Saya',
    'dokumen': 'Akun > Dokumen Saya',
    'leave': 'Cuti & Izin > Riwayat Pengajuan',
    'cuti': 'Cuti & Izin > Riwayat Pengajuan',
    'izin': 'Cuti & Izin > Riwayat Pengajuan',
    'lembur': 'Cuti & Izin > Lembur',
    'overtime': 'Cuti & Izin > Lembur',
    'gaji': 'Gaji > Slip Gaji',
    'slip': 'Gaji > Slip Gaji',
    'payroll': 'Gaji > Slip Gaji',
    'attendance': 'Home > Aktivitas Hari Ini',
    'absensi': 'Home > Aktivitas Hari Ini',
    'break': 'Home > Aktivitas Hari Ini',
    'phone': 'Akun > Informasi Akun',
    'promotion': 'Akun > Informasi Akun',
    'peringatan': 'Akun > Informasi Akun',
  };

  /// Jalur menu untuk notifikasi ini, atau null bila tidak ada menu yang
  /// relevan (notifikasi murni informatif).
  static String? menuPath(String? type, {String? title}) {
    final t = (type ?? '').trim().toLowerCase();
    final direct = _byType[t];
    if (direct != null) return direct;

    final haystack = '$t ${(title ?? '').toLowerCase()}';
    for (final entry in _byKeyword.entries) {
      if (haystack.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Kalimat petunjuk siap tempel, mis. "Buka menu Akun > Dokumen Saya untuk
  /// mengunggah ulang." Null bila tidak ada menu yang relevan.
  static String? hintSentence(String? type, {String? title}) {
    final path = menuPath(type, title: title);
    if (path == null) return null;
    final action = _actionFor((type ?? '').trim().toLowerCase());
    return 'Buka menu $path$action.';
  }

  /// Pesan notifikasi + kalimat petunjuk menu di belakangnya. Bila pesan
  /// aslinya sudah menyebut menu yang sama, petunjuknya tidak ditempel dua
  /// kali.
  static String withHint(String message, String? type, {String? title}) {
    final hint = hintSentence(type, title: title);
    if (hint == null) return message;

    final path = menuPath(type, title: title)!;
    if (message.toLowerCase().contains(path.toLowerCase())) return message;

    final trimmed = message.trim();
    if (trimmed.isEmpty) return hint;
    final separator =
        trimmed.endsWith('.') || trimmed.endsWith('!') || trimmed.endsWith('?')
            ? ' '
            : '. ';
    return '$trimmed$separator$hint';
  }

  /// Kata kerja spesifik per jenis notifikasi. Sengaja pendek: kalimatnya
  /// menempel di belakang pesan yang sudah menjelaskan duduk perkaranya.
  static String _actionFor(String type) {
    switch (type) {
      case 'document_rejected':
        return ' untuk mengunggah ulang dokumen';
      case 'document_approved':
      case 'document_submitted':
        return ' untuk melihat status dokumen';
      case 'leave_approved':
      case 'leave_rejected':
      case 'leave_request_submitted':
        return ' untuk melihat detail pengajuan';
      case 'lembur_request_submitted':
      case 'lembur_approved':
      case 'lembur_rejected':
        return ' untuk melihat pengajuan lembur';
      case 'attendance_missing_checkout':
      case 'attendance_auto_checkout':
        return ' untuk memeriksa absensi Anda';
      case 'attendance_overtime_limit':
        return ' untuk check-out sekarang';
      default:
        return '';
    }
  }
}
