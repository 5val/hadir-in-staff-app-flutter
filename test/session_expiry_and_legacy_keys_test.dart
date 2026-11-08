import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/api_client.dart';
import 'package:hadirin_staff_app/services/auth_service.dart';
import 'package:hadirin_staff_app/services/session_expiry.dart';
import 'package:hadirin_staff_app/services/session_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F1 (handler 401 global) dan F4 (pembersihan key kredensial lama).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int logoutCalls;
  late int navCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await SessionService.saveToken('jwt-aktif');
    logoutCalls = 0;
    navCalls = 0;
    SessionExpiry.logout = () async {
      logoutCalls++;
      await SessionService.clearSession();
    };
    SessionExpiry.navigateToLogin = () => navCalls++;
  });

  tearDown(() {
    SessionExpiry.logout = SessionService.clearSession;
    SessionExpiry.navigateToLogin = () {};
  });

  Future<Object?> call(int status, Future<ApiResponse> Function() fn) {
    final client = MockClient((_) async => http.Response('{"error":"x"}', status));
    return http.runWithClient(() async {
      try {
        await fn();
        return null;
      } on ApiException catch (e) {
        return e;
      }
    }, () => client);
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  group('401 global', () {
    test('401 request ber-auth -> logout + navigasi sekali', () async {
      final err = await call(401, () => ApiClient.instance.get('/mobile/x'));
      await settle();
      expect((err as ApiException).statusCode, 401);
      expect(logoutCalls, 1);
      expect(navCalls, 1);
      expect(await SessionService.getToken(), isNull);
    });

    test('401 pada auth:false (mis. passcode salah) -> TIDAK logout', () async {
      await call(401, () => ApiClient.instance.post('/mobile/login', auth: false));
      await settle();
      expect(logoutCalls, 0);
      expect(navCalls, 0);
      expect(await SessionService.getToken(), 'jwt-aktif');
    });

    test('setPasscode 401 "Passcode lama salah" -> tidak logout, pesan muncul',
        () async {
      final client = MockClient((_) async =>
          http.Response('{"success":false,"error":"Passcode lama salah"}', 401));
      final err = await http.runWithClient(() async {
        try {
          await AuthService.setPasscode(passcode: '654321', passcodeLama: '111111');
          return null;
        } on ApiException catch (e) {
          return e;
        }
      }, () => client);
      await settle();
      expect(err!.message, 'Passcode lama salah');
      expect(err.statusCode, 401);
      expect(logoutCalls, 0);
      expect(navCalls, 0);
      expect(await SessionService.getToken(), 'jwt-aktif');
    });

    test('403 -> TIDAK logout', () async {
      await call(403, () => ApiClient.instance.get('/mobile/x'));
      await settle();
      expect(logoutCalls, 0);
      expect(navCalls, 0);
    });

    test('401 bersamaan -> logout & navigasi hanya sekali', () async {
      final client =
          MockClient((_) async => http.Response('{"error":"x"}', 401));
      await http.runWithClient(() async {
        await Future.wait([
          for (var i = 0; i < 5; i++)
            ApiClient.instance.get('/mobile/x').then((_) {}, onError: (_) {}),
        ]);
      }, () => client);
      await settle();
      expect(logoutCalls, 1);
      expect(navCalls, 1);
    });

    test('401 dari dalam logout (unregister FCM) tidak berulang', () async {
      final client =
          MockClient((_) async => http.Response('{"error":"x"}', 401));
      SessionExpiry.logout = () async {
        logoutCalls++;
        // meniru FcmService.unregisterFromBackend yang ikut 401
        await ApiClient.instance.delete('/mobile/staff/s/fcm-token').then((_) {},
            onError: (_) {});
        await SessionService.clearSession();
      };
      await http.runWithClient(() async {
        await ApiClient.instance.get('/mobile/x').then((_) {}, onError: (_) {});
        await settle();
      }, () => client);
      expect(logoutCalls, 1);
      expect(navCalls, 1);
    });

    test('logout melempar error -> tetap navigasi, tidak crash', () async {
      SessionExpiry.logout = () async {
        logoutCalls++;
        throw Exception('boom');
      };
      await call(401, () => ApiClient.instance.get('/mobile/x'));
      await settle();
      expect(logoutCalls, 1);
      expect(navCalls, 1);
    });
  });

  group('key kredensial lama (F4)', () {
    const legacy = {
      'hadir_in_token': 'jwt-lama',
      'hadir_in_staff_id': 'staff-lama',
      'hadir_in_passcode': '123456',
      'hadir_in_username': 'budi',
    };

    test('purgeLegacyCredentials menghapus key lama, secure storage utuh', () async {
      SharedPreferences.setMockInitialValues({
        ...legacy,
        'hadir_in_phone': '0812',
      });
      await SessionService.saveStaffId('staff-baru');

      await SessionService.purgeLegacyCredentials();
      await SessionService.purgeLegacyCredentials(); // idempoten

      final prefs = await SharedPreferences.getInstance();
      for (final k in legacy.keys) {
        expect(prefs.containsKey(k), isFalse, reason: k);
      }
      expect(prefs.getString('hadir_in_phone'), '0812');
      expect(await SessionService.getToken(), 'jwt-aktif');
      expect(await SessionService.getStaffId(), 'staff-baru');
    });

    test('clearSession juga membersihkan key lama', () async {
      SharedPreferences.setMockInitialValues({...legacy});
      await SessionService.clearSession();
      final prefs = await SharedPreferences.getInstance();
      for (final k in legacy.keys) {
        expect(prefs.containsKey(k), isFalse, reason: k);
      }
    });
  });
}
