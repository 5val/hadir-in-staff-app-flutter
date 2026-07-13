# hadir-in-staff-app-flutter

App mobile staff Hadir-In (absensi). Flutter/Dart. Konsumen `hadir-in-api-backend-express-js` (`/api/mobile/*`).

> **Status:** app ini belum terhubung ke backend sama sekali (0 API call). Prioritas pengembangan saat ini fokus ke `hadir-in-web-admin-react` + backend; integrasi app mobile ke backend ditunda ke fase akhir.

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
├── models/       # attendance.dart, user.dart (stub kosong) — domain real ada di models.dart (SampleData hardcode)
├── services/     # attendance_provider.dart (ChangeNotifier), google_drive_service.dart, session_service.dart
├── screens/      # UI screens
├── theme/        # design tokens
├── widgets/      # komponen reusable
assets/images/    # logo & maskot Hadir-In
```
> Fase 1 cleanup selesai: `lib/screens copy/`, `lib/main copy.dart`, `pubspec copy.yaml`, `lib/app_flutter.zip`, dan `lib/providers/` (dead duplicate) sudah dihapus.

## Konvensi
- Linter: `package:flutter_lints/flutter.yaml` (`analysis_options.yaml`), belum ada override kustom.
- Baca `docs/APP-UI-GUIDELINE.md`, `docs/UI-DESIGN-GUIDE.md`, `docs/COLOR-PALETTE.md` sebelum bikin UI baru — desain sistem sudah didefinisikan di situ.
- Sesi login pakai `SessionService` (local `shared_preferences` saja — phone/employeeId/passcode), tidak ada token server. Jangan asumsikan ada auth backend sampai integrasi API dikerjakan.

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
- `../hadir-in-api-backend-express-js` — endpoint mobile ada di `src/routes/mobile/index.ts`, tapi belum dikonsumsi app ini. Integrasi ditunda.
