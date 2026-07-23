import '../models/models.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Mengambil profil staff yang sedang login dari backend.
class ProfileService {
  const ProfileService._();

  /// GET /api/mobile/staff/:id/profile — mengembalikan [StaffProfile].
  /// Melempar [ApiException] bila gagal (mis. token invalid, jaringan mati).
  static Future<StaffProfile> fetchMyProfile() async {
    final staffId = await SessionService.getStaffId();
    if (staffId == null || staffId.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    final res = await ApiClient.instance.get('/mobile/staff/$staffId/profile');
    return StaffProfile.fromJson(res.asMap);
  }

  /// Ambil profil lalu simpan ke [AppSession] (hidrasi currentUser).
  static Future<StaffProfile> loadAndCache() async {
    final profile = await fetchMyProfile();
    AppSession.setStaff(profile);
    return profile;
  }
}
