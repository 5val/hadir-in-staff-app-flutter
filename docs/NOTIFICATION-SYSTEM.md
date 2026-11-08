# Notification System — Flutter Reference

Referensi teknis untuk siapa pun yang kerja di notifikasi app staff. Disinkronkan dengan kode 2026-11-06 (versi sebelumnya, 2026-09-08, menyebut push "LOKAL, bukan FCM, belum ada pengirim server" — itu sudah tidak benar). Sisi server (tabel `Notification`, `createNotification()`, pengirim FCM) ada di [backend NOTIFICATION-SYSTEM.md](../../hadir-in-api-backend-express-js/docs/NOTIFICATION-SYSTEM.md); analisis bisnis lintas repo ada di `hadir-in-web-admin-react/docs/product/NOTIFICATION-SYSTEM-AUDIT-2026-09-08.md`. Dokumen ini fokus ke fakta teknis repo ini.

## Gambaran: tiga sumber, satu pintu ke tray

Semua notifikasi yang muncul di status bar HP lewat **satu** kelas: `PushNotificationService.show()` (`lib/services/push_notification_service.dart`, memakai `flutter_local_notifications`). Tiga sumber memberinya makan:

| # | Sumber | Kapan jalan | Kode |
|---|--------|-------------|------|
| 1 | **Push FCM** dari backend | Satu-satunya yang bekerja saat app di-background / ditutup | `lib/services/fcm_service.dart` |
| 2 | **Polling** `GET /staff/:id/notifications` | Tiap 45 detik selagi app di foreground + saat app resume | `MainScreen._startNotificationPolling` / `_pollNotifications` (`main_screen.dart`) → `NotificationCenter.syncFromServer` |
| 3 | **Peringatan lokal** buatan app (tanpa backend) | Timer 3 menit + saat resume | `MainScreen._runAttendanceGuards` / `_runShiftReminders` → `NotificationCenter.alertOnce` |

Polling **tetap dipertahankan** walau FCM sudah jalan, karena (a) ia penyelaras bila push ke-miss (token belum ter-refresh, izin notifikasi ditolak, HP tanpa Google Play Services) dan (b) ia satu-satunya sumber data untuk layar Notifikasi dan badge unread — keduanya tidak lahir dari event push.

## Jalur 1 — Push FCM

Tulang punggung: `FcmService` (`fcm_service.dart`).

- **Init** — `main()` memanggil `unawaited(FcmService.init())` (`main.dart:22`), sengaja tanpa `await` agar dialog izin notifikasi Android 13+ tidak menahan layar pertama. Isi `init()`: `Firebase.initializeApp()` → `PushNotificationService.init()` (buat channel) → `onBackgroundMessage(fcmBackgroundHandler)` → `requestPermission()` → listener `onMessage` (foreground), `onMessageOpenedApp` (ketuk dari tray), `getInitialMessage()` (app dibuka dari keadaan tertutup lewat notifikasi) → `onTokenRefresh` + `getToken()`. Best-effort: bila Firebase gagal menyala (mis. tanpa `google-services.json`), log `[fcm] init gagal` dan app tetap jalan dengan polling saja.
- **Pendaftaran token** — `registerWithBackend()` → `POST /api/mobile/staff/:id/fcm-token` `{token, platform: "android"|"ios"}`. Dipanggil di tiga saat: sesudah login berhasil (`AuthService._persistLogin`, tanpa await), tiap `onTokenRefresh`, dan tiap init. Diam bila belum login.
- **Pencabutan** — `unregisterFromBackend()` → `DELETE .../fcm-token` `{token}`, dipanggil `SessionService.clearSession()` SEBELUM JWT dihapus.
- **Payload `data`** (semua string, dari backend): `type`, `notificationId`, `webPath` (bila ada), `slipId` (bila ada). `backendIdOf()` membaca `notificationId` (fallback `id`).
- **Channel Android**: `hadirin_umum` (importance high, bisa dimatikan staff) dan `hadirin_absensi` (importance max, untuk peringatan yang harus tembus). `AndroidManifest.xml` menunjuk `default_notification_channel_id = hadirin_umum` — **harus sama** dengan yang dibuat `PushNotificationService` dan dengan konstanta di backend. Tipe berawalan `attendance` → `hadirin_absensi`; selain itu `hadirin_umum` (saat ini backend tidak mengirim tipe berawalan `attendance`).
- **Pesan ber-blok `notification`** saat app di background ditampilkan Android sendiri; `fcmBackgroundHandler` hanya mencatat `markShown(backendId)` lalu berhenti. Pesan **data-only** ditampilkan manual lewat `showAsLocalNotification`.
- **Ketukan** — payload `notification:<rawType>:<id>[:<slipId>]` (`SlipDeepLink.buildPayload`). Bila `MainScreen` belum memasang handler (app benar-benar tertutup), tujuan disimpan di `_pendingTapPayload` dan ditebus `FcmService.flushPendingTap()` setelah frame pertama.
- **iOS**: `Platform.isIOS` → `platform: "ios"` dikirim, tetapi `ios/Runner/GoogleService-Info.plist` tidak ada di working tree dan konfigurasi APNs belum didokumentasikan → push iOS **perlu dicek** (ClickUp 1100280000005331 menandainya terbuka).

> Catatan: komentar kelas di `fcm_service.dart` ("backend BELUM mengirim FCM ...") sudah basi — backend sekarang mengirim FCM (`createNotification()` → `StaffDeviceToken`). Itu komentar di kode, tidak diubah di sini.

## Jalur 2 — Polling & `NotificationCenter`

`MainScreen._pollNotifications` menarik `GET /staff/:id/notifications` (50 terbaru + `unreadCount`) dan menyuapi **dua kanal**:

1. **Banner in-app** (SnackBar "candy-bar", 4 detik, tombol "Lihat" yang pindah tab). Hanya untuk notifikasi yang baru sejak polling mulai (`_seenNotifIds` di memori; tarikan pertama hanya menyemai set ini).
2. **Tray HP** lewat `NotificationCenter.syncFromServer(prefetched: result)` — penanda "sudah ditampilkan" disimpan di `SharedPreferences` (`notif_shown_ids`, maks 200 id).

Sinkron pertama setelah instal/login (`seen` kosong) dibatasi: hanya notifikasi **belum dibaca**, berumur ≤ 24 jam, maksimal 5 (`_firstRunLimit`); sisanya hanya didaftarkan sebagai "sudah dilihat". Notifikasi yang sudah dibaca (mis. lewat web) tidak dimunculkan ulang.

### Dedup antar-jalur
- Id tray diturunkan dari id notifikasi backend (`PushNotificationService.idFor`), jadi push + polling untuk kejadian yang sama **memperbarui** satu baris, bukan dua.
- Jalur push memanggil `NotificationCenter.markShown(backendId)` begitu tampil; `syncFromServer` melewati id itu. Banner in-app mengecek `NotificationCenter.isShown` **sebelum** `syncFromServer` (urutan penting: sesudahnya hasilnya selalu true).

### Layar Notifikasi & tujuan ketukan
- `notification_screen.dart`: daftar penuh, filter (Belum Dibaca / Disetujui / Ditolak / Pengingat / Info), mark-read (`PATCH .../notifications/:id/read`, `.../read-all`). Pengguna dengan `Jabatan.isSupervisor` mendapat toggle "Diri Sendiri / Tim" — tetapi `AppNotification.isTeam` selalu `false` dari API (`models.dart:1534`), jadi sisi "Tim" selalu kosong (known issue).
- Pemetaan `rawType` → tab (`notificationTargetFromRawType` + `NotificationTargetTab.staffTabIndex`, `models.dart:1560`): `leave_*` dan `lembur_*` → tab Cuti & Izin (index 1); `slip_*`/`gaji_*`/`pencairan_*` → tab Gaji (index 3, dan `SlipDeepLink` membuka detail slip bila `slipId` ada); `location_transfer_*` → Home (index 0, **belum ada layar staff** untuk Pindah Lokasi); lainnya → buka layar Notifikasi.

## Jalur 3 — Peringatan lokal (`NotificationCenter.alertOnce`)

Dihitung langsung di HP dari `AttendanceRules` (`lib/services/attendance_provider.dart`) dan status absensi lokal; tidak lewat backend/tabel `Notification`. Dedup "sekali per `key` per hari" lewat `SharedPreferences` (`notif_local_alert_*`). Dipicu timer 3 menit (`_guardTimer`) dan tiap resume. Tidak jalan bila profil belum termuat, gerbang onboarding aktif, atau role admin.

`_runAttendanceGuards` (`main_screen.dart`):

| `type` | Kondisi |
|--------|---------|
| `attendance_missing_checkout` | Ada sesi menggantung dari **hari sebelumnya** (`open.isPreviousDay`) — juga memunculkan dialog penutup. Sesi hari ini yang cuma lewat batas lembur TIDAK memicu dialog |
| `attendance_overtime_limit` | Masih bekerja dan lembur sudah melewati batas (`min(Jabatan.maxExtraHour, 4)` jam) |
| `break_reminder` | Masih tercatat istirahat padahal jam pulang sudah lewat |

`_runShiftReminders` (Sprint 3 Fase 4; tidak berlaku di hari libur, bukan hari kerja shift, atau saat cuti/izin hari itu):

| `type` | Kondisi |
|--------|---------|
| `attendance_reminder_checkin` | Belum check-in: T-15 (`checkin_t15_*`), T-5 (`checkin_t5_*`), dan 0–10 menit setelah jam masuk (`checkin_ontime_*`) |
| `attendance_reminder_late` | Belum check-in dan ≥ 15 menit lewat jam masuk (`checkin_late_*`) |
| `attendance_reminder_break` | Sudah check-in, belum pernah istirahat, dan lewat separuh durasi shift |
| `attendance_reminder_checkout` | Bekerja (checkedIn/breakEnded, bukan onBreak) dan jam pulang sudah lewat |

Tidak ada angka toleransi keterlambatan di client (tidak ada field-nya) — pesan sengaja tidak menyebut angka toleransi. Rollup lintas-staff untuk Manager ("12 dari 20 staff sudah masuk") tidak bisa dibangun di HP dan butuh backend.

## `NotificationMenuHints` (`lib/services/notification_menu_hints.dart`)

Peta `type` → "Menu > Submenu" yang ditempel di belakang body notifikasi ("Buka menu Akun > Dokumen Saya ..."), dipakai tray, banner, dan layar Notifikasi supaya menyebut tujuan yang sama. Tambah `type` baru (dari backend atau `alertOnce`) ke `_byType`; bila lupa ada fallback tebak-kata-kunci (`_byKeyword`) yang kurang presisi. `location_transfer_*` sengaja tidak ada (belum ada layar tujuannya).

## `PushNotificationService` (`push_notification_service.dart`)

Membungkus `flutter_local_notifications`: `init()` (buat saluran umum + absensi, masing-masing per mode bunyi: `_sound/_vibration/_silent`, minta izin), `show(...)` (membaca sakelar **Notifikasi** dan mode **Notifikasi Suara** lewat `NotificationDelivery.decide`; sakelar mati menyembunyikan notifikasi umum, pengingat absensi tetap tampil), `cancelAll()`, `onNotificationTap` (diisi `MainScreen`). `NotificationCenter.unreadCount` (`ValueNotifier`) memberi makan titik merah lonceng Home. `NotificationCenter.reset()` dipanggil oleh `SessionService.clearSession()` untuk semua jalur logout.

## Known issues
- Sisi "Tim" di layar Notifikasi hanya muncul bila ada notifikasi `isTeam` (API belum pernah mengirimnya).
- Push iOS belum terverifikasi (lihat atas).

Setup Firebase dan cara menguji push: [guides/FCM-SETUP.md](guides/FCM-SETUP.md).
