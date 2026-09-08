import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'notification_menu_hints.dart';
import 'push_notification_service.dart';
import 'session_service.dart';

/// Handler pesan FCM saat app TIDAK sedang di layar (background atau
/// benar-benar ditutup).
///
/// Dijalankan Android di isolate Dart terpisah, jadi ia tidak melihat state
/// app sama sekali dan WAJIB menyalakan Firebase-nya sendiri. Anotasi
/// `vm:entry-point` mencegah tree-shaking membuangnya di build release --
/// tanpa itu push saat app tertutup diam-diam mati di APK release saja.
///
/// Pesan yang punya blok `notification` TIDAK disentuh di sini: Android sudah
/// menampilkannya sendiri ke tray lewat saluran yang ditunjuk
/// `default_notification_channel_id` di AndroidManifest. Kalau handler ini
/// ikut menampilkan, staff melihat notifikasi yang sama DUA kali. Yang perlu
/// ditangani manual hanya pesan data-only.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();

    // Catat bahwa notifikasi ini SUDAH sampai ke tray, walau yang
    // menampilkannya Android dan bukan kode Dart. Tanpa penanda ini polling
    // 45 detik akan memunculkannya lagi begitu staff membuka app -- kabar
    // yang sama muncul dua kali.
    final backendId = FcmService.backendIdOf(message);
    if (backendId != null) await NotificationCenter.markShown(backendId);

    // Sisanya hanya untuk pesan data-only; yang ber-blok `notification`
    // sudah ditampilkan Android sendiri.
    if (message.notification != null) return;
    await FcmService.showAsLocalNotification(message);
  } catch (e) {
    debugPrint('[fcm] background handler gagal: $e');
  }
}

/// Jembatan antara Firebase Cloud Messaging dan notifikasi HP yang sudah ada
/// di app ini.
///
/// Sengaja TIDAK memunculkan notifikasi dengan caranya sendiri: semuanya
/// dilempar ke [PushNotificationService.show] supaya push dari server tampil
/// dengan saluran, gaya BigText, petunjuk menu, dan perilaku ketukan yang
/// identik dengan notifikasi yang selama ini dibangkitkan app sendiri.
///
/// Pembagian tugas dengan polling 45 detik di `MainScreen`:
///   * FCM -- satu-satunya jalur yang bekerja saat app di-background/ditutup.
///   * polling -- masih dipertahankan karena backend BELUM mengirim FCM
///     (belum ada kolom device token maupun pengirim server-side). Begitu
///     backend mengirim push, polling boleh dikecilkan jadi sekadar
///     penyelaras saat app dibuka -- lihat dokumen requirement FCM.
///
/// Notifikasi kembar antara kedua jalur dicegah tanpa state tambahan: id
/// notifikasi HP diturunkan dari id notifikasi backend lewat
/// [PushNotificationService.idFor], jadi kalau pesan yang sama datang dua
/// kali (sekali via push, sekali via polling) Android MEMPERBARUI notifikasi
/// yang sama alih-alih menumpuk dua baris.
class FcmService {
  const FcmService._();

  static bool _initialized = false;

  static String? _token;

  /// Token registrasi device di FCM. Null selama Firebase belum siap atau
  /// perangkat belum berhasil mendaftar (mis. tanpa Google Play Services).
  static String? get token => _token;

  /// Siapkan Firebase + seluruh handler pesan. Aman dipanggil berkali-kali.
  ///
  /// Best-effort seperti [PushNotificationService.init]: kegagalan apa pun
  /// (google-services.json belum ada, perangkat tanpa Google Play Services,
  /// jaringan mati) TIDAK PERNAH dilempar keluar -- app harus tetap jalan,
  /// cuma tanpa push.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();

      // Saluran notifikasi harus SUDAH ADA sebelum pesan pertama masuk:
      // Android menampilkan push background lewat saluran yang ditunjuk
      // `default_notification_channel_id`, dan saluran itu dibuat di sini.
      // Ini juga yang meminta izin notifikasi Android 13+ -- dipanggil sedini
      // mungkin supaya tray sudah boleh dipakai sebelum staff login.
      await PushNotificationService.init();

      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Android 13+ menampilkan dialog izin di sini kalau belum dijawab; di
      // iOS ini yang mendaftarkan app ke APNs.
      await messaging.requestPermission();

      // App sedang dibuka: Android TIDAK menampilkan apa pun sendiri, jadi
      // notifikasinya kita munculkan manual. Ini yang membuat push tetap
      // terlihat di tray selagi staff memandangi app.
      FirebaseMessaging.onMessage.listen(showAsLocalNotification);

      // Staff mengetuk notifikasi dari tray saat app di background.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedFromTray);

      // App benar-benar tertutup lalu dibuka LEWAT notifikasi: pesannya tidak
      // lewat stream mana pun, harus diambil sekali di sini.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpenedFromTray(initial);

      messaging.onTokenRefresh.listen(_publishToken);
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) _publishToken(fcmToken);

      _initialized = true;
    } catch (e) {
      debugPrint('[fcm] init gagal: $e');
    }
  }

  static void _publishToken(String fcmToken) {
    _token = fcmToken;
    // Dicetak utuh dan diberi penanda mencolok karena inilah yang harus
    // ditempel ke Firebase Console > Messaging > Send test message untuk
    // menguji push ke satu HP tertentu.
    debugPrint('[fcm] ===== FCM TOKEN (salin untuk Send test message) =====');
    debugPrint(fcmToken);
    debugPrint('[fcm] ====================================================');
    unawaited(registerWithBackend());
  }

  /// Daftarkan HP ini sebagai alamat push milik staff yang sedang login.
  ///
  /// Dipanggil di TIGA saat, dan ketiganya perlu:
  ///   1. sesudah login berhasil (`AuthService._persistLogin`) -- token FCM
  ///      biasanya sudah ada jauh sebelum staff login, jadi tanpa ini HP baru
  ///      terdaftar saat token kebetulan di-refresh;
  ///   2. setiap `onTokenRefresh` -- token bisa berubah sendiri (reinstall,
  ///      clear data, restore backup) dan token lama langsung mati;
  ///   3. setiap init app, lewat [_publishToken] di atas.
  ///
  /// Diam-diam berhenti kalau staff belum login: endpoint-nya ber-auth, dan
  /// token tanpa pemilik tidak ada gunanya disimpan.
  ///
  /// Best-effort: kegagalan jaringan tidak boleh menggagalkan login.
  static Future<void> registerWithBackend() async {
    try {
      final fcmToken = _token ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;
      _token = fcmToken;

      final staffId = await SessionService.getStaffId();
      if (staffId == null || staffId.isEmpty) return;

      await ApiClient.instance.post(
        '/mobile/staff/$staffId/fcm-token',
        body: {
          'token': fcmToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
      debugPrint('[fcm] token terdaftar di backend untuk staff $staffId');
    } catch (e) {
      debugPrint('[fcm] gagal mendaftarkan token ke backend: $e');
    }
  }

  /// Cabut pendaftaran HP ini — dipanggil `SessionService.clearSession()`
  /// SEBELUM JWT dihapus (endpointnya ber-auth).
  ///
  /// Tanpa ini, staff berikutnya yang memakai HP yang sama akan membuat token
  /// berpindah pemilik dengan benar, TAPI staff yang baru saja logout tetap
  /// terdaftar sampai itu terjadi — artinya notifikasi pribadinya masih
  /// mendarat di HP yang sudah bukan miliknya lagi.
  static Future<void> unregisterFromBackend() async {
    try {
      final fcmToken = _token;
      if (fcmToken == null || fcmToken.isEmpty) return;

      final staffId = await SessionService.getStaffId();
      if (staffId == null || staffId.isEmpty) return;

      await ApiClient.instance.delete(
        '/mobile/staff/$staffId/fcm-token',
        body: {'token': fcmToken},
      );
    } catch (e) {
      debugPrint('[fcm] gagal mencabut token di backend: $e');
    }
  }

  /// Tampilkan [message] sebagai notifikasi HP lewat jalur yang sama dengan
  /// notifikasi app lainnya.
  static Future<void> showAsLocalNotification(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    final title = notification?.title ?? _stringOf(data['title']);
    final body = notification?.body ?? _stringOf(data['body']);
    // Tanpa judul maupun isi tidak ada yang berguna untuk ditampilkan -- mis.
    // pesan data-only yang murni untuk sinkronisasi diam-diam.
    if (title == null && body == null) return;

    final rawType = _stringOf(data['type']) ?? '';
    final backendId = backendIdOf(message);

    // Sama alasannya dengan di [fcmBackgroundHandler]: begitu push tampil,
    // polling tidak boleh memunculkan kabar yang sama untuk kedua kalinya.
    if (backendId != null) await NotificationCenter.markShown(backendId);

    await PushNotificationService.show(
      // Id notifikasi backend dipakai kalau ada, supaya push dan polling tidak
      // menghasilkan dua baris untuk kejadian yang sama.
      id: PushNotificationService.idFor(
        backendId ?? message.messageId ?? DateTime.now().toIso8601String(),
      ),
      title: title ?? 'Hadir-In',
      body: NotificationMenuHints.withHint(body ?? '', rawType, title: title),
      payload: backendId == null ? null : 'notification:$rawType:$backendId',
      attendanceAlert: rawType.startsWith('attendance'),
    );
  }

  static bool _hasPendingTap = false;
  static String? _pendingTapPayload;

  /// Ketukan notifikasi yang ditampilkan SISTEM (app di background/tertutup).
  ///
  /// Diarahkan ke penangan ketukan yang sama dengan notifikasi lokal --
  /// `MainScreen` mengisinya di `initState`, jadi deep-link ke tab yang benar
  /// bekerja identik lewat kedua jalur.
  /// Id baris `notification` di backend yang melahirkan pesan ini.
  ///
  /// Inilah kunci yang menyatukan push dengan polling: id yang sama dipakai
  /// sebagai id notifikasi HP DAN sebagai penanda "sudah ditampilkan", jadi
  /// satu kejadian tidak pernah muncul dua kali walau tiba lewat dua jalur.
  /// Null berarti pesan itu tidak berasal dari tabel notification (mis. tes
  /// manual dari Firebase Console).
  static String? backendIdOf(RemoteMessage message) =>
      _stringOf(message.data['notificationId']) ?? _stringOf(message.data['id']);

  static void _handleOpenedFromTray(RemoteMessage message) {
    final data = message.data;
    final rawType = _stringOf(data['type']) ?? '';
    final backendId = backendIdOf(message);
    final payload =
        backendId == null ? null : 'notification:$rawType:$backendId';

    final handler = PushNotificationService.onNotificationTap;
    if (handler == null) {
      // Kasus app BENAR-BENAR tertutup lalu dibuka lewat ketukan notifikasi:
      // `getInitialMessage` menjawab sebelum MainScreen sempat memasang
      // penangannya, jadi tujuannya disimpan dulu dan ditebus
      // [flushPendingTap]. Tanpa ini app cuma terbuka di tab terakhir dan
      // ketukan staff terasa tidak melakukan apa-apa.
      _hasPendingTap = true;
      _pendingTapPayload = payload;
      return;
    }
    handler(payload);
  }

  /// Jalankan ketukan notifikasi yang tertunda, kalau ada.
  ///
  /// Dipanggil `MainScreen` setelah [PushNotificationService.onNotificationTap]
  /// terpasang DAN frame pertama selesai -- penangannya memakai `Navigator`,
  /// yang belum tersedia selama `initState`.
  static void flushPendingTap() {
    if (!_hasPendingTap) return;
    final payload = _pendingTapPayload;
    _hasPendingTap = false;
    _pendingTapPayload = null;
    PushNotificationService.onNotificationTap?.call(payload);
  }

  /// Payload FCM selalu `Map<String, dynamic>` dengan nilai bertipe bebas --
  /// dirapikan ke String? supaya sisa kelas ini tidak perlu menjaga tipe.
  static String? _stringOf(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }
}
