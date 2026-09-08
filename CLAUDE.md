# hadir-in-staff-app-flutter

App mobile staff Hadir-In (absensi). Flutter/Dart. Konsumen `hadir-in-api-backend-express-js` (`/api/mobile/*`).

> **Status (2026-07-31):** app SUDAH terhubung ke backend — 16 service file di `lib/services/` masing-masing konsumsi endpoint `/api/mobile/*` (auth, attendance, document/onboarding, overtime, subordinate, location, calendar, staff-log/popup, salary, leave, notification, profile). Jangan asumsikan lagi "0 API call" — cek `lib/services/api_client.dart` buat base client-nya.

## Stack
- Flutter (SDK >=3.0.0 <4.0.0), Dart
- camera + google_mlkit_face_detection — absensi pakai deteksi wajah
- google_sign_in + googleapis + extension_google_sign_in_as_googleapis_auth — Google Sign-In & Drive
- shared_preferences — local storage/session
- pdf + printing — cetak slip/laporan
- google_fonts, intl, percent_indicator

## Struktur
```
lib/
├── models/       # models.dart — semua domain model + parsing response API (SalarySlip, Attendance, StaffLog, dst)
├── services/     # api_client.dart (base HTTP client) + 1 service per domain:
│                 #   auth_service, session_service, attendance_service, attendance_provider (ChangeNotifier),
│                 #   document_service (onboarding+dokumen), overtime_service (lembur), staff_log_service (popup naik jabatan/SP),
│                 #   subordinate_service, location_service, calendar_service (hari libur), salary_service, leave_service,
│                 #   notification_service, profile_service, google_drive_service
├── screens/      # UI screens (login, main/tab shell, onboarding_documents, salary, leave, overtime history dihapus → masuk home_tab, dst)
├── theme/        # design tokens
├── widgets/      # komponen reusable (mis. staff_log_dialog — popup promosi/SP)
assets/images/    # logo & maskot Hadir-In
```

## Konvensi
- Linter: `package:flutter_lints/flutter.yaml` (`analysis_options.yaml`), belum ada override kustom.
- Baca `docs/APP-UI-GUIDELINE.md`, `docs/UI-DESIGN-GUIDE.md`, `docs/COLOR-PALETTE.md` sebelum bikin UI baru — desain sistem sudah didefinisikan di situ.
- **Gerbang onboarding dokumen** ada di `screens/main_screen.dart#_hydrateProfile` (bukan di layar login) — MainScreen adalah satu-satunya pintu ke isi app, jadi semua jalur masuk (login, passcode unlock, sesi aktif) ikut tergerbang. Jangan menambah pemeriksaan duplikat di layar lain.
- **Mode testing absensi:** `lib/config/testing_config.dart` (`TestingConfig.enabled`) mem-bypass GPS & jam untuk pengujian — lokasi dibelokkan di `LocationService.current()`, jam dikirim lewat field `time` yang memang didukung endpoint check-in/check-out. Jangan tambah bypass baru di layar; cukup lewat file itu. Sejak Sprint 3 EPIC 1, `enabled` dibaca dari compile-time flag `bool.fromEnvironment('TESTING_MODE', defaultValue: false)` — BUKAN literal di source lagi (literal `true` yang ke-commit pernah bocor ke produksi). Aktifkan lokal dengan `flutter run --dart-define=TESTING_MODE=true`; tanpa flag ini selalu `false`. Detail & checklist rilis: `docs/TESTING-ABSENSI.md`.
- **Dokumen onboarding TIDAK diunggah saat dipilih.** Memilih berkas hanya menyalinnya ke folder privat app lewat `services/document_draft_service.dart` (draft bertahan walau app ditutup); satu-satunya tempat berkas benar-benar dikirim (`POST /documents` + `/documents/reuse`) adalah tombol tunggal "Ajukan Dokumen" di bawah `screens/onboarding_documents_screen.dart#_submitAll`. Jangan kembalikan tombol unggah per kartu — sebelum ini, satu ketukan langsung menaruh berkas di Google Drive dan membuat baris `staff_document` pending yang tidak bisa dibatalkan staff.
- **Notifikasi HP** ada di `services/push_notification_service.dart` (`flutter_local_notifications`) — SATU-SATUNYA yang boleh memunculkan notifikasi ke tray. Ada DUA sumber yang memberinya makan: (1) push FCM dari backend lewat `services/fcm_service.dart` — jalur utama, satu-satunya yang bekerja saat app di-background/ditutup; (2) polling `NotificationCenter.syncFromServer()` yang ditarik `MainScreen` tiap 45 detik + saat app resume, dipertahankan sebagai penyelaras kalau push ke-miss (token belum ter-refresh, izin notifikasi ditolak, HP tanpa Play Services). Notifikasi kembar dicegah `NotificationCenter.markShown()`: jalur push menandai id backend-nya begitu tampil, jadi polling melewatinya. Peringatan yang dibangkitkan app sendiri (batas lembur, lupa check-out) lewat `NotificationCenter.alertOnce`. Setiap teks yang keluar dilewatkan `services/notification_menu_hints.dart` supaya menyebut menu tujuan ("Buka menu Akun > Dokumen Saya ..."); tambahkan `type` baru ke peta di file itu, bukan menempel nama menu di teks backend.
- **Absensi yang menggantung** (lupa break-out/check-out, termasuk yang terbawa ke hari berikutnya) ditangani `GET/POST .../attendance/open-session|auto-checkout` di backend: istirahat DAN check-out dipatok ke `Shift.jamPulang` hari itu dengan `lembur = 0`. App memblokir check-in berikutnya lewat `widgets/open_session_dialog.dart` (dipakai FAB MainScreen & kartu check-in HomeTab), server menolaknya dengan HTTP 409.
- Sesi login pakai `SessionService` (local `shared_preferences` — phone/employeeId/passcode) DITAMBAH panggilan API asli lewat `api_client.dart`; jangan asumsikan lagi "belum ada backend" — cek service terkait dulu sebelum nulis integrasi baru dari nol.
- **Take Home Pay = `gajiNetto` server, JANGAN dihitung ulang di client** (Sprint 2 EPIC 9, selesai 2026-08-01 — lihat `docs/SPRINT2-EPIC9-FLUTTER-TASKS.md`). `SalarySlip.takeHomePay`/`netSalary` sekarang cuma mengembalikan field `gajiNetto` dari respons API. Formula resminya milik backend (`payroll-calc.ts`: `gajiNetto = totalPendapatan + totalTunjanganUang`); kalau app merekonstruksi sendiri dari breakdown, angkanya akan meleset tiap kali backend ganti aturan. Komponen yang TAMPIL tapi tidak menambah THP (tunjangan `bentuk: "barang"`, Fasilitas/natura, dan uang makan yang backend belum wire ke `gajiNetto`) ditandai lewat `SalaryComponent.excludedFromThp` + badge "Di luar THP" di UI. Regression test: `test/salary_slip_test.dart`.

## Commands
```bash
flutter pub get
flutter run              # jalankan di device/emulator terhubung
flutter analyze          # lint
flutter test
flutter build apk        # / build ios, dst
```

## Environment
`android/app/google-services.json` dan `ios/Runner/GoogleService-Info.plist` di-gitignore (mengandung client ID Google) — minta file asli ke pemilik project kalau butuh build ulang, jangan commit ulang.

**Identitas app (2026-09-08, FINAL — jangan diubah).** `applicationId`/`namespace` Android dan bundle id iOS/macOS semuanya `com.hadirin.staff` (dulu `com.example.*`). Nilai ini terikat mati ke `google-services.json` dan ke listing Play Store, jadi mengubahnya = daftar ulang app di Firebase Console. Sumber kebenarannya `namespace` + `applicationId` di `android/app/build.gradle.kts`; `AndroidManifest.xml` sengaja TIDAK lagi punya atribut `package` (tidak didukung sejak AGP 8). `minSdk` di-pin `24` di file yang sama, bukan `flutter.minSdkVersion` — Firebase minta ≥ 23, dan 24 adalah default Flutter 3.44 sekarang.

**Plugin `com.google.gms.google-services`** ada di classpath (`android/settings.gradle.kts`, v4.4.2) tapi diterapkan BERSYARAT di `android/app/build.gradle.kts`: hanya kalau `android/app/google-services.json` benar-benar ada. Ini disengaja supaya repo tetap bisa di-build selagi kredensial Firebase belum turun; kalau file-nya belum ada, Gradle mencetak peringatan `[hadir-in] ... push FCM TIDAK akan jalan`. Jangan ubah jadi penerapan tanpa syarat sebelum file itu masuk — semua build developer lain akan gagal.

## Repo terkait
- `../hadir-in-api-backend-express-js` — endpoint mobile ada di `src/routes/mobile/index.ts`, sudah dikonsumsi penuh oleh app ini. Kontrak endpoint per fitur ada di `docs/api-contracts/sprint2.md` (dan sprint sebelumnya) — cek dulu sebelum ubah shape request/response.
