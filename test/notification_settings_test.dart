import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/push_notification_service.dart';
import 'package:hadirin_staff_app/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F7: sakelar Notifikasi & mode Notifikasi Suara harus benar-benar dibaca
/// PushNotificationService; titik merah lonceng mengikuti unreadCount.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NotificationDelivery.decide', () {
    test('sakelar mati menyembunyikan notifikasi umum, bukan peringatan absensi', () {
      final umum = NotificationDelivery.decide(
          enabled: false, soundMode: 'Sound', attendanceAlert: false);
      expect(umum.show, isFalse);
      final absensi = NotificationDelivery.decide(
          enabled: false, soundMode: 'Sound', attendanceAlert: true);
      expect(absensi.show, isTrue);
    });

    test('mode bunyi: Sound = suara+getar, Vibration = getar saja, Silent = hening', () {
      NotificationDelivery d(String m) => NotificationDelivery.decide(
          enabled: true, soundMode: m, attendanceAlert: false);
      expect([d('Sound').playSound, d('Sound').vibrate], [true, true]);
      expect([d('Vibration').playSound, d('Vibration').vibrate], [false, true]);
      expect([d('Silent').playSound, d('Silent').vibrate], [false, false]);
      // Nilai tak dikenal = Sound.
      expect(d('???').playSound, isTrue);
    });
  });

  group('preferensi tersimpan', () {
    test('sakelar Notifikasi default aktif dan bertahan', () async {
      expect(await SessionService.getNotifEnabled(), isTrue);
      await SessionService.saveNotifEnabled(false);
      expect(await SessionService.getNotifEnabled(), isFalse);
    });
  });

  group('titik merah lonceng', () {
    test('unreadCount nol setelah reset (logout)', () async {
      NotificationCenter.unreadCount.value = 3;
      await NotificationCenter.reset();
      expect(NotificationCenter.unreadCount.value, 0);
    });
  });
}
