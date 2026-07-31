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
- **Mode testing absensi:** `lib/config/testing_config.dart` (`TestingConfig.enabled`) mem-bypass GPS & jam untuk pengujian — lokasi dibelokkan di `LocationService.current()`, jam dikirim lewat field `time` yang memang didukung endpoint check-in/check-out. Jangan tambah bypass baru di layar; cukup lewat file itu. Detail & checklist rilis: `docs/TESTING-ABSENSI.md`.
- Sesi login pakai `SessionService` (local `shared_preferences` — phone/employeeId/passcode) DITAMBAH panggilan API asli lewat `api_client.dart`; jangan asumsikan lagi "belum ada backend" — cek service terkait dulu sebelum nulis integrasi baru dari nol.
- **Gap diketahui (2026-07-31):** `models.dart` (`SalarySlip.takeHomePay`/`netSalary`) menghitung ULANG take-home pay dari breakdown komponen di client, bukan baca `gajiNetto` langsung dari server. Ini termasuk uang makan (`Attendance.uangMakan`, dijumlah live oleh `routes/mobile/gaji.ts`) padahal backend BELUM menjumlah uang makan ke slip resmi (`payroll-calc.ts`/`gajiNetto`) — begitu `PayrollSettings.uangMakanPerHariAmount` diisi, angka yang ditampilkan app bisa lebih besar dari yang beneran ditransfer. Perbaikan: ganti ke baca `gajiNetto` server langsung, jangan rekonstruksi manual. Lihat `hadir-in-web-admin-react/docs/product/SPRINT2-PRD.md` EPIC 5b.

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

## Repo terkait
- `../hadir-in-api-backend-express-js` — endpoint mobile ada di `src/routes/mobile/index.ts`, sudah dikonsumsi penuh oleh app ini. Kontrak endpoint per fitur ada di `docs/api-contracts/sprint2.md` (dan sprint sebelumnya) — cek dulu sebelum ubah shape request/response.
