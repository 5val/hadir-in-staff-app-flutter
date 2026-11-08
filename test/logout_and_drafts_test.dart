import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/document_draft_service.dart';
import 'package:hadirin_staff_app/services/push_notification_service.dart';
import 'package:hadirin_staff_app/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F2: satu rutin logout (`SessionService.clearSession`) harus membersihkan
/// draft dokumen + penanda notifikasi + kredensial, dan draft terikat staffId.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> loginAs(String staffId) async {
    await SessionService.saveToken('jwt-$staffId');
    await SessionService.saveStaffId(staffId);
  }

  test('draft staff A tidak pernah muncul untuk staff B di HP yang sama', () async {
    await loginAs('staff-a');
    await DocumentDraftService.putReuse(jenis: 'ktp', fileUrl: 'https://x/ktp.jpg');
    expect((await DocumentDraftService.all()).keys, ['ktp']);

    // Tanpa logout (mis. kunci lama bocor) -- ganti identitas saja.
    await loginAs('staff-b');
    expect(await DocumentDraftService.all(), isEmpty);

    await loginAs('staff-a');
    expect((await DocumentDraftService.all()).keys, ['ktp']);
  });

  test('clearSession membersihkan draft, penanda notifikasi, dan kredensial', () async {
    await loginAs('staff-a');
    await SessionService.saveSessionWithPhone(phone: '0812', employeeId: 'e1');
    await DocumentDraftService.putReuse(jenis: 'ktp', fileUrl: 'https://x/ktp.jpg');
    await NotificationCenter.markShown('notif-1');
    expect(await NotificationCenter.isShown('notif-1'), isTrue);

    await SessionService.clearSession();

    expect(await SessionService.getToken(), isNull);
    expect(await SessionService.getStaffId(), isNull);
    expect(await SessionService.isLoggedIn(), isFalse);
    expect(await NotificationCenter.isShown('notif-1'), isFalse);

    // Login ulang sebagai staff yang sama: draft lama tidak boleh kembali.
    await loginAs('staff-a');
    expect(await DocumentDraftService.all(), isEmpty);
    // Nomor HP terakhir sengaja bertahan (kenyamanan login).
    expect(await SessionService.getSavedPhone(), '0812');
  });
}
