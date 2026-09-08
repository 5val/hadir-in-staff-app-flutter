# Notification System — Flutter Reference (2026-09-08)

Referensi teknis buat siapa pun yang kerja di notifikasi app staff. Versi lengkap lintas-3-repo (analisis bisnis, apa yang kurang, rencana fase) ada di `hadir-in-web-admin-react/docs/product/NOTIFICATION-SYSTEM-AUDIT-2026-09-08.md` — baca itu dulu buat konteks penuh, dokumen ini fokus ke fakta teknis repo ini aja.

## 2 jalur notifikasi yang BEDA arsitektur — jangan tertukar

### Jalur 1 — dari backend (`Notification` table, lewat `GET /api/mobile/staff/:id/notifications`)
Ditarik `NotificationService.myNotifications()` (`lib/services/notification_service.dart`), di-polling tiap 45 detik selagi app di-foreground (`MainScreen._startNotificationPolling`, di `main_screen.dart`), muncul di:
- Banner in-app (SnackBar candy-bar) buat yang baru muncul sejak polling mulai.
- Layar Notifikasi (`notification_screen.dart`) — daftar lengkap, bisa di-mark-read.
- Notifikasi status-bar HP asli, lewat `NotificationCenter.syncFromServer` → `PushNotificationService.show()`.

`type` mentah dari backend disimpan di `AppNotification.rawType` (dulu dibuang, sekarang disimpan — lihat `lib/models/models.dart`). `NotificationTarget`/`staffTabIndex` (extension di file yang sama) resolve mau buka tab mana pas notif di-tap: `leave_*` → tab Cuti & Izin, `lembur_*`/`location_transfer_*` → tab Home (belum ada layar khusus buat keduanya, fallback ke Home).

### Jalur 2 — lokal, dibangkitkan APP SENDIRI (`NotificationCenter.alertOnce`, `main_screen.dart`)
Sama sekali TIDAK lewat backend/`Notification` table — dihitung langsung di HP dari `AttendanceRules` (waktu shift, status absensi lokal), dipicu timer 3 menit + tiap app di-resume (`MainScreen._startBackgroundWatchers` → `_runAttendanceGuards`). Dedup "sekali per hari per key" via `SharedPreferences`.

**Yang SUDAH jalan** (`_runAttendanceGuards`, `main_screen.dart` ~baris 368-414):
- `attendance_missing_checkout` — open session menggantung dari hari sebelumnya belum ditutup.
- `attendance_overtime_limit` — sudah lembur lewat batas maksimal (`Jabatan.maxExtraHour`), belum checkout.
- `break_reminder` — masih istirahat padahal jam pulang shift sudah lewat.

## Kenapa reminder BARU (T-15/T-5/T-0 sebelum masuk, dst) itu murah dikerjakan di sini

Semua building block waktu yang dibutuhkan **SUDAH ADA** di `AttendanceRules` (`lib/services/attendance_provider.dart`), semuanya sudah wrap-aware buat shift overnight (lihat `computePulangTarget`/`computeMasukTarget`, dites di `test/attendance_rules_test.dart`):

- `jamMasukTarget` — `DateTime` jam masuk shift hari ini (atau besok kalau shift overnight sedang di jeda siang).
- `remainingWorkTime` — sisa waktu ke jam pulang.
- `overtimeDeadline` / `isPastOvertimeLimit` — sudah dipakai `attendance_overtime_limit`.
- `overtimeElapsedSinceCheckout` — sudah dipakai buat timer hitung-naik di Home tab.

Artinya nambah reminder baru **TIDAK BUTUH backend baru sama sekali** — tinggal tambah kondisi baru di `_runAttendanceGuards`, pakai `NotificationCenter.alertOnce(key: ..., title: ..., body: ..., type: ...)` yang sudah ada.

### Reminder yang BELUM ada, siap dibangun dengan pola yang sama

Semua ini derivable dari `AttendanceRules.jamMasukTarget` + status `AttendanceProvider` yang sudah ada, tidak butuh field/model baru:

1. **T-15 / T-5 menit sebelum jam masuk** — bandingkan `DateTime.now()` vs `jamMasukTarget`, cuma relevan kalau status masih `notCheckedIn` dan hari ini hari kerja (`_isWorkDay`). Key dedup: `pre_checkin_15/staffId/tanggal`.
2. **"Sekarang waktunya check-in"** — persis di `jamMasukTarget`, sama syaratnya.
3. **Sudah telat, sisa toleransi** — butuh field toleransi keterlambatan (cek apakah `Jabatan`/`PayrollSettings`/`KebijakanAbsensi` punya kolom ini; kalau tidak ada, tulis pesan tanpa angka toleransi — jangan mengarang angka).
4. **Separuh durasi shift lewat, belum istirahat** — hitung `remainingWorkTime` vs total durasi shift (`jamPulang - jamMasuk`, wrap-aware), cuma relevan kalau status `checkedIn` (belum pernah `onBreak`/`breakEnded`) DAN sudah lewat separuh.
5. **Mendekati/pas/lewat jam pulang** — `remainingWorkTime` mendekati 0 / `isAfterNormalCheckout` baru jadi true — ini SEBAGIAN sudah ada sebagai tampilan (bukan reminder push) di kartu Home (`home_tab.dart`, Fase 6 sesi sebelumnya), tinggal tambahkan versi push-nya kalau mau lebih menonjol.

**Yang TIDAK bisa dibangun di sini**: rollup lintas-staff buat Manager ("12 dari 20 staff sudah masuk") — itu butuh data staff LAIN yang tidak ada di 1 device, harus backend (lihat dokumen backend).

## `NotificationMenuHints` (`lib/services/notification_menu_hints.dart`)

Peta `type` (dari backend ATAU lokal) → "Menu > Submenu" tujuan di app, dipakai nempel kalimat "Buka menu Akun > Dokumen Saya untuk mengunggah ulang." di belakang body notifikasi HP. Kalau nambah `type` baru (baik dari backend maupun `alertOnce` lokal), **tambahkan juga entry-nya di sini** (`_byType`) — kalau lupa, ada fallback tebak-kata-kunci (`_byKeyword`) tapi lebih baik eksplisit.

Catatan: `location_transfer_*` SENGAJA tidak ada di peta ini — Pindah Lokasi belum punya layar staff sama sekali di Flutter (dikonfirmasi: nol layar di `lib/screens/` yang menampilkannya). Jangan tambahkan menu tujuan sampai layarnya beneran ada.

## `PushNotificationService` (`lib/services/push_notification_service.dart`)

Notifikasi status-bar HP ASLI (bukan cuma daftar di dalam app), pakai `flutter_local_notifications`. **Ini LOKAL, bukan FCM** — belum ada infrastruktur push server-side (tidak ada kolom device token, tidak ada pengirim). Begitu FCM tersambung (lihat requirement FCM di `hadir-in-web-admin-react/docs/product/SPRINT3-REMAINING-FCM-REQUIREMENT-2026-09-07.md`), tinggal panggil `PushNotificationService.show()` yang sama dari handler pesan FCM — servicenya sendiri sudah didesain gak perlu berubah.

2 channel Android sudah dipisah: `hadirin_umum` (importance high, bisa dimatikan staff) vs `hadirin_absensi` (importance max, buat peringatan yang harus tetap tembus — lembur/lupa checkout/istirahat).

## Bug/gap yang relevan dari sisi backend (lihat detail di dokumen backend)

- Bell **web-admin** (bukan di sini) bocor scoping — tidak berdampak ke app ini (mobile endpoint sudah scoped benar per staffId), cuma relevan kalau kerja lintas repo.
- `phone_verification` copy salah orang (backend, `v1/staff.ts`) — begitu diperbaiki backend-side, tidak ada perubahan yang dibutuhkan di app ini (cuma teks body yang berubah).
- Tidak ada `breadcrumb`/`webPath` di response backend — untuk app ini TIDAK masalah besar karena `NotificationMenuHints` sudah jalan cukup baik sebagai versi client-side-nya. Kalau backend nanti nambah field `mobileTarget` yang otoritatif, evaluasi apa masih perlu dipakai atau `NotificationMenuHints` tetap cukup.
