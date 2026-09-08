import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_menu_hints.dart';
import 'notification_service.dart';

/// Notifikasi NYATA di HP (status bar / notification tray), bukan sekadar
/// daftar di dalam app.
///
/// Sebelum ini seluruh "fitur notifikasi" app hanya berupa layar daftar yang
/// menarik `GET /notifications` — staff baru tahu dokumennya ditolak kalau ia
/// kebetulan membuka menu Notifikasi. Sekarang setiap notifikasi (dari
/// backend maupun yang dibangkitkan app sendiri, mis. batas lembur terlewat)
/// dimunculkan sebagai notifikasi sistem yang berbunyi & terlihat di layar
/// kunci.
///
/// TRANSPORT: paket ini menampilkan notifikasi LOKAL. Backend Hadir-In belum
/// punya infrastruktur FCM (tidak ada kolom device token maupun pengirim
/// server-side — lihat `src/routes/mobile/notifications.ts`), jadi
/// pengirimannya dipicu app: [NotificationCenter] menarik daftar notifikasi
/// secara berkala/saat app dibuka lalu memunculkan yang belum pernah
/// ditampilkan. Begitu backend punya FCM, cukup panggil [show] dari handler
/// pesan FCM — sisa app tidak perlu berubah.
class PushNotificationService {
  const PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _permissionGranted = false;

  /// Dipanggil saat notifikasi diketuk — diisi [MainScreen] supaya ketukan
  /// membuka layar Notifikasi, bukan sekadar membuka app di tab terakhir.
  static void Function(String? payload)? onNotificationTap;

  /// Saluran notifikasi umum (persetujuan cuti, dokumen, gaji, dst).
  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
    'hadirin_umum',
    'Notifikasi Hadir-In',
    description:
        'Pemberitahuan persetujuan cuti, status dokumen, gaji, dan info lain.',
    importance: Importance.high,
  );

  /// Saluran absensi — peringatan yang harus segera dilihat staff (batas
  /// lembur terlewat, lupa check-out). Dipisah supaya staff bisa mematikan
  /// notifikasi umum tanpa ikut mematikan peringatan absensi.
  static const AndroidNotificationChannel _attendanceChannel =
      AndroidNotificationChannel(
    'hadirin_absensi',
    'Pengingat Absensi',
    description:
        'Pengingat check-out, batas maksimal lembur, dan istirahat yang belum '
        'ditutup.',
    importance: Importance.max,
  );

  static bool get isInitialized => _initialized;
  static bool get permissionGranted => _permissionGranted;

  /// Siapkan plugin + minta izin notifikasi. Aman dipanggil berkali-kali.
  ///
  /// Kegagalan di sini TIDAK PERNAH dilempar keluar: app harus tetap jalan di
  /// perangkat yang notifikasinya dimatikan pengguna.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) =>
            onNotificationTap?.call(response.payload),
      );

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(_generalChannel);
        await androidImpl.createNotificationChannel(_attendanceChannel);
      }

      _initialized = true;
      await requestPermission();
    } catch (e) {
      debugPrint('[push] init gagal: $e');
    }
  }

  /// Minta izin notifikasi (Android 13+ & iOS). Di Android ≤12 izinnya
  /// otomatis ada, jadi langsung dianggap diberikan.
  static Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final impl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await impl?.requestNotificationsPermission();
        _permissionGranted = granted ?? true;
      } else if (Platform.isIOS) {
        final impl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await impl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permissionGranted = granted ?? false;
      } else {
        _permissionGranted = false;
      }
    } catch (e) {
      debugPrint('[push] minta izin gagal: $e');
      _permissionGranted = false;
    }
    return _permissionGranted;
  }

  /// Munculkan satu notifikasi di HP.
  ///
  /// [attendanceAlert] memilih saluran prioritas tinggi (batas lembur, lupa
  /// check-out) yang tetap lolos walau staff mematikan notifikasi umum.
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool attendanceAlert = false,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;

    final channel = attendanceAlert ? _attendanceChannel : _generalChannel;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: attendanceAlert ? Priority.max : Priority.high,
        // Teks notifikasi Hadir-In panjang (isinya menyebut alasan penolakan
        // + menu tujuan). Tanpa BigTextStyle, Android memotongnya di satu
        // baris dan justru bagian "buka menu ..." yang hilang.
        styleInformation: BigTextStyleInformation(body),
        ticker: title,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('[push] show gagal: $e');
    }
  }

  /// Id notifikasi yang stabil untuk sebuah kunci (mis. id notifikasi
  /// backend). Android memakai int 32-bit, jadi hash-nya dipangkas.
  static int idFor(String key) => key.hashCode & 0x7fffffff;

  /// Bersihkan semua notifikasi app ini — dipakai saat logout supaya
  /// notifikasi staff sebelumnya tidak tertinggal di HP.
  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}

/// Satu pintu untuk MEMUNCULKAN notifikasi ke HP staff.
///
/// Dua sumber:
///   1. Notifikasi backend — ditarik [syncFromServer] lalu ditampilkan sekali
///      saja per id (penanda "sudah pernah ditampilkan" disimpan lokal).
///   2. Peringatan yang dibangkitkan app sendiri ([alertOnce]) — batas
///      maksimal lembur terlewat, istirahat belum ditutup, belum check-out.
///      Ini tidak ada di backend, jadi tidak mungkin datang dari
///      `GET /notifications`.
///
/// Semua teks yang keluar dari sini lewat [NotificationMenuHints.withHint],
/// jadi staff selalu diberi tahu MENU MANA yang harus dibuka.
class NotificationCenter {
  const NotificationCenter._();

  static const _seenKey = 'notif_shown_ids';
  static const _localAlertPrefix = 'notif_local_alert_';

  /// Batas jumlah id yang diingat. Cukup besar untuk menampung 50 notifikasi
  /// yang dikembalikan backend beberapa kali, cukup kecil supaya
  /// SharedPreferences tidak tumbuh tanpa batas.
  static const _maxSeen = 200;

  /// Batas notifikasi yang dimunculkan pada sinkronisasi PERTAMA setelah
  /// login/instal.
  static const _firstRunLimit = 5;

  /// Notifikasi backend yang belum pernah dimunculkan → tampilkan di HP.
  ///
  /// Mengembalikan `unreadCount` terbaru supaya pemanggil bisa sekalian
  /// memperbarui badge, atau null bila gagal (mis. jaringan mati).
  /// Best-effort: tidak pernah melempar.
  /// [prefetched] menghindari penarikan HTTP kedua: `MainScreen` sudah
  /// menarik daftar notifikasi tiap 45 detik untuk banner in-app, dan hasil
  /// yang sama itu diserahkan ke sini alih-alih memukul endpoint yang sama
  /// dua kali dengan jadwal berbeda.
  static Future<int?> syncFromServer({NotificationResult? prefetched}) async {
    try {
      final result = prefetched ?? await NotificationService.myNotifications();

      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getStringList(_seenKey) ?? const <String>[];
      final seenSet = seen.toSet();

      // Pertama kali dipasang/login, `seen` kosong sementara backend bisa
      // punya puluhan notifikasi lama. Memunculkan semuanya sekaligus akan
      // membanjiri status bar HP dengan kabar berbulan-bulan lalu, jadi
      // angkatan pertama dibatasi: hanya yang BELUM DIBACA dan masih baru
      // (24 jam terakhir), maksimal [_firstRunLimit] buah. Sisanya cukup
      // didaftarkan sebagai "sudah dilihat" — semuanya tetap ada di layar
      // Notifikasi di dalam app.
      final firstRun = seen.isEmpty;

      // Dari yang paling lama ke paling baru, supaya urutan di tray HP sama
      // dengan urutan kejadiannya.
      final fresh = result.items
          .where((n) => n.id.isNotEmpty && !seenSet.contains(n.id))
          .toList()
          .reversed
          .toList();

      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      var shownOnFirstRun = 0;

      for (final n in fresh) {
        // Yang sudah dibaca staff (mis. lewat web admin) tidak perlu
        // dimunculkan lagi sebagai notifikasi baru.
        if (n.isRead) continue;
        if (firstRun) {
          if (n.createdAt.isBefore(cutoff)) continue;
          if (shownOnFirstRun >= _firstRunLimit) continue;
          shownOnFirstRun++;
        }
        await PushNotificationService.show(
          id: PushNotificationService.idFor(n.id),
          title: n.title,
          body: NotificationMenuHints.withHint(
            n.message,
            n.rawType,
            title: n.title,
          ),
          // rawType ikut dibawa: saat notifikasi ini diketuk (bisa
          // berjam-jam kemudian, setelah app ditutup) objek AppNotification-
          // nya sudah tidak ada, sementara tujuan deep-link-nya diturunkan
          // dari rawType — lihat `MainScreen._handleNotificationTap`.
          payload: 'notification:${n.rawType}:${n.id}',
          attendanceAlert: n.rawType.startsWith('attendance'),
        );
      }

      final updated = <String>[...fresh.map((n) => n.id), ...seen];
      await prefs.setStringList(
        _seenKey,
        updated.length > _maxSeen ? updated.sublist(0, _maxSeen) : updated,
      );

      return result.unreadCount;
    } catch (e) {
      debugPrint('[notif-center] sync gagal: $e');
      return null;
    }
  }

  /// Peringatan lokal yang hanya boleh muncul SEKALI per [key] per hari.
  ///
  /// Kenapa dikunci per hari: pemanggilnya adalah pemeriksa yang berjalan
  /// tiap detik/menit (timer home, resume app). Tanpa kunci ini, "batas
  /// maksimal lembur sudah lewat" akan muncul berulang-ulang sampai staff
  /// check-out.
  static Future<void> alertOnce({
    required String key,
    required String title,
    required String body,
    String type = 'attendance_reminder',
    DateTime? day,
  }) async {
    try {
      final d = day ?? DateTime.now();
      final stamp = '${d.year}-${d.month}-${d.day}';
      final prefs = await SharedPreferences.getInstance();
      final prefsKey = '$_localAlertPrefix$key';
      if (prefs.getString(prefsKey) == stamp) return;
      await prefs.setString(prefsKey, stamp);

      await PushNotificationService.show(
        id: PushNotificationService.idFor('local:$key'),
        title: title,
        body: NotificationMenuHints.withHint(body, type, title: title),
        payload: 'local:$key',
        attendanceAlert: true,
      );
    } catch (e) {
      debugPrint('[notif-center] alertOnce gagal: $e');
    }
  }

  /// Lupakan semua penanda — dipakai saat logout supaya staff berikutnya di
  /// HP yang sama tidak kehilangan notifikasinya (id staff lain).
  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_seenKey);
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith(_localAlertPrefix)) await prefs.remove(k);
      }
      await PushNotificationService.cancelAll();
    } catch (_) {}
  }

}
