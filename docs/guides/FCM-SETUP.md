# Setup & Uji Push FCM

Panduan operasional (kredensial, build, cara menguji). Arsitektur push (init, token, dedup dengan polling, deep-link) ada di [../NOTIFICATION-SYSTEM.md](../NOTIFICATION-SYSTEM.md) — sengaja **tidak digabung** ke sana karena isinya langkah kerja, bukan penjelasan desain. Sisi server: [backend NOTIFICATION-SYSTEM.md](../../../hadir-in-api-backend-express-js/docs/NOTIFICATION-SYSTEM.md) dan `docs/ops/deployment.md` / `development.md` backend. Diverifikasi terhadap kode 2026-11-06.

## 1. Yang dibutuhkan

| Sisi | Kebutuhan | Catatan |
|------|-----------|---------|
| Firebase Console | Project dengan app Android bernama paket **`com.hadirin.staff`** (final, jangan diubah) | minta akses ke pemilik project |
| App Android | `android/app/google-services.json` | di-gitignore; jangan commit |
| App iOS | `ios/Runner/GoogleService-Info.plist` + APNs key di Firebase | file tidak ada di working tree; konfigurasi APNs belum didokumentasikan → push iOS **perlu dicek** (ClickUp 1100280000005331 masih terbuka) |
| Backend | `FIREBASE_SERVICE_ACCOUNT_BASE64` (service account JSON ber-base64, kunci PENUH ke project Firebase) | kosong = notifikasi tetap tertulis di DB tetapi push dilewati (peringatan dicatat sekali saat push pertama) |

## 2. Cara kerja build tanpa kredensial

`android/app/build.gradle.kts` menerapkan plugin `com.google.gms.google-services` **hanya bila** `android/app/google-services.json` ada. Tanpa file itu:

- Gradle mencetak: `[hadir-in] android/app/google-services.json belum ada -- plugin google-services dilewati, push FCM TIDAK akan jalan di build ini.`
- Build tetap sukses; saat run, `FcmService.init()` gagal diam-diam (`[fcm] init gagal: …`) dan app memakai **polling 45 detik** sebagai satu-satunya jalur notifikasi (hanya saat app dibuka).

Jangan ubah penerapan plugin menjadi tanpa syarat: semua build developer lain akan gagal selama file kredensial belum dibagikan.

## 3. Mengaktifkan push di build lokal

1. Taruh `google-services.json` (paket `com.hadirin.staff`) di `android/app/`.
2. `flutter run` (Android 13+ akan menampilkan dialog izin notifikasi; izin ditolak = push tidak tampil, polling tetap jalan).
3. Login. Cek log (`flutter logs`/konsol):
   - `[fcm] ===== FCM TOKEN (salin untuk Send test message) =====` diikuti token utuh — dicetak tiap `getToken`/`onTokenRefresh`.
   - `[fcm] token terdaftar di backend untuk staff <id>` — `POST /api/mobile/staff/:id/fcm-token` berhasil (#42). Pendaftaran diam bila belum login; ia diulang otomatis sesudah login berhasil.
4. Pastikan backend punya `FIREBASE_SERVICE_ACCOUNT_BASE64` bila ingin push dari server.

## 4. Menguji

**A. Dari Firebase Console (hanya tes jalur tampil):** Messaging → Send test message → tempel token dari log. Pesan ini tidak punya `notificationId` di data, jadi tidak ikut dedup dan tap-nya tidak punya tujuan (`payload` null). Cukup untuk memastikan tray muncul.

**B. End-to-end lewat backend (disarankan):** picu kejadian nyata yang membuat notifikasi untuk staff itu — mis. dari portal web setujui cuti staff, atau kirim konfirmasi slip. Backend menulis baris `Notification` lalu mengirim push dengan `data`: `type`, `notificationId`, `webPath` (bila ada), `slipId` (bila ada), semua string. Cek:

| Skenario | Yang diharapkan |
|----------|-----------------|
| App di foreground | notifikasi tray muncul (di-render manual lewat `showAsLocalNotification`), banner in-app dari polling **tidak** dobel (`markShown`/`isShown`) |
| App di background | Android menampilkan push sendiri lewat channel `hadirin_umum`; ketuk membuka tab yang sesuai tipe |
| App ditutup (swipe) | idem; ketuk membuka app langsung ke tujuan (`getInitialMessage` + `flushPendingTap`) |
| Push slip gaji | ketuk membuka tab Gaji dan detail slip bila `slipId` ada |
| Logout lalu login staff lain di HP sama | token berpindah pemilik; staff lama tidak menerima lagi (`unregisterFromBackend` dipanggil `clearSession()`) |

## 5. Channel Android — harus sinkron

| Channel | Dibuat oleh | Dipakai untuk |
|---------|-------------|----------------|
| `hadirin_umum` (importance high) | `PushNotificationService` | semua push backend (default FCM ditunjuk di `AndroidManifest.xml`: `default_notification_channel_id`) |
| `hadirin_absensi` (importance max) | `PushNotificationService` | peringatan absensi lokal dan tipe berawalan `attendance` |

Id harus sama di tiga tempat: `push_notification_service.dart`, `AndroidManifest.xml`, dan backend (`lib/push-notification.ts`; lihat deployment.md backend). Bila beda, Android membuat channel "Lain-lain" berprioritas rendah dan notifikasi tidak muncul sebagai heads-up.

## 6. Troubleshooting

| Gejala | Kemungkinan |
|--------|-------------|
| Tidak ada log `[fcm] ===== FCM TOKEN` | `google-services.json` tidak ada/salah paket; HP tanpa Google Play Services; Firebase gagal init (lihat `[fcm] init gagal`) |
| Token tercetak tapi tidak ada `token terdaftar di backend` | belum login; backend tidak terjangkau (`ApiConfig.host`); respons 4xx (`token` kosong atau > 4096 karakter) |
| Push dari server tidak datang | `FIREBASE_SERVICE_ACCOUNT_BASE64` kosong di backend; token sudah ditolak Firebase lalu dihapus otomatis (login ulang untuk mendaftar ulang); izin notifikasi OS ditolak |
| Notifikasi dobel | id notifikasi backend tidak ikut di `data` (`notificationId`); lihat dedup di NOTIFICATION-SYSTEM.md |
| Push iOS tidak jalan | belum dikonfigurasi (lihat bagian 1) |

Catatan kode: komentar kelas di `fcm_service.dart` yang menyebut "backend BELUM mengirim FCM" sudah basi — backend sekarang mengirim FCM.
