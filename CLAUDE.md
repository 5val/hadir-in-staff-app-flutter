# hadir-in-staff-app-flutter

App mobile staff Hadir-In (absensi). Flutter/Dart. Konsumen `hadir-in-api-backend-express-js` (`/api/mobile/*`).

> **Status (diverifikasi ulang 2026-11-06):** app SUDAH terhubung penuh ke backend lewat `lib/services/api_client.dart` — 24 file di `lib/services/`, hampir semuanya konsumen endpoint `/api/mobile/*`. Tidak ada lagi mock untuk alur utama (login, absensi, cuti/izin, lembur, slip gaji, dokumen, notifikasi). Sisa data karangan (`SampleData`) hanya bertahan di layar yang tidak terjangkau atau sebagai fallback — lihat [docs/features/APP-FEATURES.md](docs/features/APP-FEATURES.md) bagian "Layar yatim & mock".
>
> Kode = sumber kebenaran. Dokumen di `docs/` memberi label **RENCANA** untuk keputusan yang belum ada di kode dan **perlu dicek** untuk hal yang tidak bisa dibuktikan dari kode.

## Stack
- Flutter (SDK >=3.0.0 <4.0.0), Dart. `version: 1.0.0+1` (`pubspec.yaml`)
- Jaringan: `http` (dibungkus `ApiClient`), JWT staff di header `Authorization: Bearer`
- Session/penyimpanan: `flutter_secure_storage` (JWT + staffId, terenkripsi OS), `shared_preferences` (flag UX lokal: login/sesi aktif, nomor HP terakhir, mode bunyi, id notifikasi sudah tampil, id slip tersimpan ke Drive), `path_provider` (folder privat draft dokumen)
- Absensi: `camera` + `google_mlkit_face_detection` ("ada wajah di tengah"; plus liveness kedip->toleh->lurus bila Kebijakan Absensi mewajibkan, `services/liveness_challenge.dart`. BUKAN pencocokan identitas), `geolocator` (GPS + deteksi `isMocked`)
- Berkas: `image_picker` (foto dokumen/lampiran), `pdf` + `printing` (bagikan/unduh PDF slip)
- Google: `google_sign_in` + `googleapis` + `extension_google_sign_in_as_googleapis_auth` (simpan slip terkunci ke Drive pribadi staff, scope `drive.file`)
- Notifikasi: `firebase_core` + `firebase_messaging` (push FCM), `flutter_local_notifications` (tray HP)
- Lain-lain: `url_launcher` (WhatsApp/telepon), `google_fonts`, `intl` (+`intl_utils`), `percent_indicator`
- Dev: `flutter_lints`, `flutter_launcher_icons`

## Struktur
```
lib/
├── main.dart     # init FCM (tanpa await), format tanggal id_ID, lockSession() tiap start dingin, AuthWrapper
├── config/       # api_config.dart (host/port/baseUrl/timeout), testing_config.dart (mode testing, --dart-define)
├── models/       # models.dart (SEMUA domain model + parsing API + SampleData mock lama), slip_filter.dart
│                 #   attendance.dart & user.dart: file kosong (0 byte)
├── services/     # 24 file. api_client.dart (base client) + 1 service per domain:
│   │             #   auth_service, session_service, profile_service, phone_change_service
│   │             #   attendance_service, attendance_provider (ChangeNotifier + AttendanceRules), location_service, calendar_service
│   │             #   leave_service, overtime_service, subordinate_service (persetujuan atasan)
│   │             #   salary_service, slip_deep_link, slip_drive_sync, google_drive_service, rekening_service
│   │             #   document_service (onboarding), document_draft_service (draft berkas lokal)
│   │             #   notification_service, push_notification_service (+NotificationCenter), fcm_service, notification_menu_hints
│   │             #   staff_log_service (popup naik jabatan / surat peringatan)
├── screens/      # UI. main_screen (shell tab) | home_tab, leave_tab, salary_screen (+SalaryDetailScreen), account_tab
│                 #   login_screen, passcode_unlock_screen, otp_verification_screen, onboarding_documents_screen
│                 #   camera_checkin_screen, notification_screen, rekening_screen, account_info_screen, slip_bukti_screen
│                 #   subordinate_requests_screen, all_subordinate_leave_history_screen, all_attendance_history_screen
│                 #   YATIM (tidak dipakai): landing, profile, checkin, history, all_leave_history, leave_choice (di-comment), break, manager_dashboard_tab
├── theme/        # app_theme.dart (token desain). "app_theme copy.dart" = salinan cadangan, jangan diedit
├── widgets/      # common_widgets, open_session_dialog, early_checkout_dialog, staff_log_dialog, uploaded_file_image, work_date_picker
assets/images/    # logo & maskot Hadir-In
test/             # 21 file test, lihat docs/TESTING.md
docs/             # lihat docs/README.md (indeks)
```
Folder `lib/screens copy/` dan `pubspec copy.yaml` yang disebut di catatan lama TIDAK ada di working tree saat ini; yang masih ada hanya `lib/theme/app_theme copy.dart`.

## Konvensi
- Linter: `package:flutter_lints/flutter.yaml` (`analysis_options.yaml`), belum ada override kustom.
- Baca `docs/APP-UI-GUIDELINE.md`, `docs/UI-DESIGN-GUIDE.md`, `docs/COLOR-PALETTE.md` sebelum bikin UI baru.
- Ikuti penempatan file yang ada — `attendance_provider.dart` memang di `lib/services/`, bukan `lib/providers/`.
- **Kontrak API:** sumber utama [`../hadir-in-api-backend-express-js/docs/mobile-api.md`](../hadir-in-api-backend-express-js/docs/mobile-api.md) (keadaan sekarang, 49 route) + log kronologis `docs/api-contracts/sprint2.md` dan `docs/api-contracts/sprint3.md` (slip gaji, notifikasi, dan perubahan 2026-09 s/d 2026-11 ada di **sprint3.md**). Cek dulu sebelum ubah shape request/response; kalau butuh perubahan backend, laporkan — jangan tebak.
- **Sesi login** (`services/session_service.dart`): JWT staff + `staffId` disimpan di `flutter_secure_storage` (Sprint 3 EPIC 5a). Di `shared_preferences` hanya flag UX: `logged_in`, `session_active`, `employee_id`, `phone` (nomor terakhir, TIDAK dihapus saat logout), mode bunyi notifikasi. **Passcode TIDAK disimpan di HP** — hash-nya di server (`Staff.passcodeHash`). `main()` memanggil `lockSession()` di setiap start dingin, jadi buka app setelah ditutup selalu minta passcode (`PasscodeUnlockScreen`). Alur lengkap: [docs/features/AUTH-LOGIN-FLOW.md](docs/features/AUTH-LOGIN-FLOW.md).
- **Gerbang onboarding dokumen** ada di `screens/main_screen.dart#_hydrateProfile` (bukan di layar login) — MainScreen adalah satu-satunya pintu ke isi app, jadi semua jalur masuk (login, passcode unlock, sesi aktif) ikut tergerbang. Jangan menambah pemeriksaan duplikat di layar lain. Gagal memeriksa (jaringan) = fail-open, staff dibiarkan masuk. Detail: [docs/features/ONBOARDING-DOKUMEN.md](docs/features/ONBOARDING-DOKUMEN.md).
- **Mode testing absensi:** `lib/config/testing_config.dart` (`TestingConfig.enabled`) mem-bypass GPS & jam — lokasi dibelokkan di `LocationService.current()`, jam dikirim lewat field `time` (backend hanya menghormatinya bila `NODE_ENV != production`). Jangan tambah bypass baru di layar. **Kebijakan Absensi** (`GET .../attendance/policy`, `models/attendance_policy.dart`, 2026-11-12) menentukan foto/GPS/radius/deteksi mock/liveness di `widgets/attendance_entry_flow.dart`; detail di `docs/features/ABSENSI-SHIFT-RULES.md` 3b. `enabled` dibaca dari `bool.fromEnvironment('TESTING_MODE', defaultValue: false)`; aktifkan lokal dengan `flutter run --dart-define=TESTING_MODE=true`. Skenario jam lewat `--dart-define=TESTING_SCENARIO=<nama>` (default **`lembur`**, bukan `normal`). Detail & checklist rilis: `docs/TESTING-ABSENSI.md`.
- **Dokumen onboarding TIDAK diunggah saat dipilih.** Memilih berkas hanya menyalin ke folder privat app lewat `services/document_draft_service.dart`; satu-satunya tempat berkas benar-benar dikirim (`POST /documents` + `/documents/reuse`) adalah tombol "Ajukan Dokumen" (`onboarding_documents_screen.dart#_submitAll`). Jangan kembalikan tombol unggah per kartu.
- **Notifikasi HP** ada di `services/push_notification_service.dart` (`flutter_local_notifications`) — SATU-SATUNYA yang boleh memunculkan notifikasi ke tray. DUA sumber memberinya makan: (1) push FCM lewat `services/fcm_service.dart` — satu-satunya yang bekerja saat app di-background/ditutup; (2) polling `NotificationCenter.syncFromServer()` yang ditarik `MainScreen` tiap 45 detik + saat app resume, dipertahankan sebagai penyelaras kalau push ke-miss. Notifikasi kembar dicegah `NotificationCenter.markShown()`. Peringatan yang dibangkitkan app sendiri (batas lembur, lupa check-out, pengingat jam masuk/istirahat/pulang) lewat `NotificationCenter.alertOnce`. Teks keluar dilewatkan `services/notification_menu_hints.dart`; tambahkan `type` baru ke peta di file itu. Arsitektur lengkap: [docs/NOTIFICATION-SYSTEM.md](docs/NOTIFICATION-SYSTEM.md).
- **Absensi yang menggantung** (lupa break-out/check-out, termasuk yang terbawa ke hari berikutnya) ditangani `GET .../attendance/open-session` + `POST .../attendance/auto-checkout`. App memblokir check-in berikutnya lewat `widgets/open_session_dialog.dart` (FAB MainScreen & kartu check-in HomeTab); server menolaknya dengan HTTP 409. Jam yang dicatat: absensi hari SEBELUMNYA dipatok ke jam pulang shift, absensi hari ini dicatat jam sekarang, keduanya lembur 0 (komentar `open_session_dialog.dart#openSessionExplanation`; angka resmi milik server). Aturan lengkap: [docs/features/ABSENSI-SHIFT-RULES.md](docs/features/ABSENSI-SHIFT-RULES.md).
- **Take Home Pay = `gajiNetto` server, JANGAN dihitung ulang di client.** `SalarySlip.takeHomePay`/`netSalary` hanya mengembalikan `gajiNetto`. Komponen yang TAMPIL tapi tidak menambah THP (tunjangan `bentuk: "barang"` dan Fasilitas/natura) ditandai `SalaryComponent.excludedFromThp` + badge "Di luar THP". **Uang makan SUDAH masuk THP sejak 2026-08-03** (tidak ditandai lagi). Regression test: `test/salary_slip_test.dart`. Alur slip: [docs/features/SLIP-GAJI-FLOW.md](docs/features/SLIP-GAJI-FLOW.md); aturan bisnis kanonik: [`../hadir-in-web-admin-react/docs/product/ATURAN-BISNIS-PENGGAJIAN.md`](../hadir-in-web-admin-react/docs/product/ATURAN-BISNIS-PENGGAJIAN.md).
- **Peran di app:** satu-satunya pembeda nyata adalah `isApprover` dari server (`GET .../subordinates/requests`) yang memunculkan tombol "See My Team" di tab Cuti & Izin. `UserRole.admin` TIDAK PERNAH dihasilkan dari API, jadi tab "Tim"/`AdminDashboardTab` (isi `SampleData`) tidak pernah tampil. Matriks: [docs/features/ROLE-MATRIX.md](docs/features/ROLE-MATRIX.md).
- Test baru harus terbukti GAGAL di kode lama (lihat [docs/TESTING.md](docs/TESTING.md)).

## Commands
```bash
flutter pub get
flutter run                                        # device/emulator
flutter run --dart-define=TESTING_MODE=true        # mode testing absensi (GPS & jam palsu)
flutter analyze
flutter test
flutter build apk                                  # / build ios, dst — lihat docs/guides/BUILD-RELEASE-ENV.md
```

## Environment
- **Host backend** di-hardcode di `lib/config/api_config.dart` (`host = '10.10.3.12'`, port 4000, **`http://`**). Ganti manual sesuai jaringan; belum ada `--dart-define` untuk host. Detail: [docs/guides/BUILD-RELEASE-ENV.md](docs/guides/BUILD-RELEASE-ENV.md).
- `android/app/google-services.json` dan `ios/Runner/GoogleService-Info.plist` di-gitignore — minta file asli ke pemilik project, jangan commit. Setup & uji push: [docs/guides/FCM-SETUP.md](docs/guides/FCM-SETUP.md).
- **Identitas app (2026-09-08, FINAL — jangan diubah).** `applicationId`/`namespace` Android dan bundle id iOS/macOS semuanya `com.hadirin.staff`. Terikat mati ke `google-services.json` dan listing Play Store. `minSdk` di-pin `24` di `android/app/build.gradle.kts`.
- Plugin `com.google.gms.google-services` diterapkan BERSYARAT hanya bila `android/app/google-services.json` ada. Jangan ubah jadi tanpa syarat.
- Build release saat ini memakai **debug signing** (TODO di `build.gradle.kts`) — belum siap Play Store.

## Known issues (ringkas; rincian & rujukan baris di docs/features/*)
`http://` + IP LAN; debug signing di release; tab "Tim" mock tak terjangkau; nama `_showMockWaNotification` menyesatkan (OTP dikirim via email; banner hanya bila server mengembalikan `devCode`); menu "Coming soon" (Tema/Bahasa/Ukuran Teks/Panduan/Syarat/Privasi). **Diperbaiki 2026-11-08 (F1-F8):** Tolak slip wajib centang + catatan (R9); satu rutin logout `SessionService.clearSession()` + draft dokumen per staffId; foto wajib saat absen; `isMocked` diblokir di `LocationService.current()` untuk semua pintu; FAB & kartu Home memakai alur sama (`widgets/attendance_entry_flow.dart`); persetujuan lembur + alasan tolak di "Pengajuan Karyawan"; sakelar Notifikasi/Notifikasi Suara dibaca `PushNotificationService`, titik lonceng mengikuti `NotificationCenter.unreadCount`; SOS memakai `kontakAdminPhone`; nama app "Hadir-In".

## Repo terkait
- `../hadir-in-api-backend-express-js` — endpoint mobile di `src/routes/mobile/*.ts`; referensi: `docs/mobile-api.md`, `docs/authorization.md`, `docs/api-contracts/sprint2.md` & `sprint3.md`.
- `../hadir-in-web-admin-react` — portal Admin/Manager; PRD sprint di `docs/product/SPRINT*-PRD.md`, aturan penggajian di `docs/product/ATURAN-BISNIS-PENGGAJIAN.md`.
