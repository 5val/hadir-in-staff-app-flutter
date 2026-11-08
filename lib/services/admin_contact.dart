/// Kontak admin kantor (F8). Satu sumber untuk kartu "Hubungi Admin" di tab
/// Akun dan tombol SOS di Home: `office.kontakAdminPhone` dari profil staff.
class AdminContact {
  const AdminContact._();

  /// Nomor lokal/internasional -> format wa.me (62xxxxxxxx).
  static String normalizeToWa(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('62')) return digits;
    if (digits.startsWith('0')) return '62${digits.substring(1)}';
    return '62$digits';
  }

  static Uri waUri(String phone) =>
      Uri.parse('https://wa.me/${normalizeToWa(phone)}');
}
