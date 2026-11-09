import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/auth_service.dart';
import 'package:hadirin_staff_app/services/session_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// set-passcode saat mengganti passcode me-revoke token lama; token baru dari
/// respons harus menggantikan token tersimpan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await SessionService.saveToken('jwt-lama');
  });

  Future<void> run(String body) => http.runWithClient(
        () => AuthService.setPasscode(passcode: '123456', passcodeLama: '654321'),
        () => MockClient((_) async => http.Response(body, 200)),
      );

  test('respons berisi token -> token tersimpan diganti', () async {
    await run('{"data":{"hasPasscode":true,"token":"jwt-baru"}}');
    expect(await SessionService.getToken(), 'jwt-baru');
  });

  test('respons tanpa token -> token lama tetap', () async {
    await run('{"data":{"hasPasscode":true}}');
    expect(await SessionService.getToken(), 'jwt-lama');
  });

  test('token kosong -> token lama tetap', () async {
    await run('{"data":{"hasPasscode":true,"token":""}}');
    expect(await SessionService.getToken(), 'jwt-lama');
  });
}
