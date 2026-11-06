# Testing

Peta berkas test dan aturan menulis test baru. Mode testing **absensi** (GPS & jam palsu saat menjalankan app) adalah hal lain dan ada di [TESTING-ABSENSI.md](TESTING-ABSENSI.md). Diverifikasi terhadap `test/` pada 2026-11-06.

## Menjalankan

```bash
flutter test                 # semua
flutter test test/salary_slip_test.dart
flutter analyze
```

Catatan penting: `flutter test` **tidak meneruskan `--dart-define`**, jadi `TestingConfig.enabled` selalu `false` di test dan `TestingConfig.now()` selalu jam dinding asli. Karena itu logika jam di `AttendanceRules` diuji lewat fungsi murni yang menerima `now` sebagai parameter (`computePulangTarget`, `computeMasukTarget`, `computeNextMasukTarget`, `computeRemainingWorkTime`). Kalau menambah logika waktu baru, pisahkan versi murninya dengan pola yang sama.

## Aturan: test baru harus terbukti GAGAL di kode lama

Test regresi yang tidak pernah merah tidak membuktikan apa pun. Untuk setiap perbaikan bug atau perubahan perilaku:

1. Tulis test-nya **dulu** (atau setidaknya sebelum perbaikan diterapkan) dan jalankan terhadap kode lama; catat bahwa ia **gagal** dengan pesan yang sesuai bug-nya.
2. Terapkan perbaikan, jalankan lagi: harus hijau.
3. Cara praktis memverifikasi setelah perbaikan sudah ditulis: sementara kembalikan perubahan kode (mis. `git stash` hanya berkas `lib/` terkait — jangan menyentuh perubahan orang lain), jalankan test baru, pastikan merah, lalu pulihkan.
4. Tulis di komentar test atau deskripsi PR bug apa yang ia kunci (contoh baik: `testing_config_test.dart` menjelaskan literal `enabled = true` yang pernah bocor ke produksi; `attendance_rules_test.dart` menandai grup "the fixed behavior").
5. Jangan mengubah ekspektasi test yang ada agar hijau tanpa memahami kenapa ia ditulis. Test yang meng-encode perilaku lama yang memang akan diubah (lihat "Test yang akan perlu diubah" di bawah) boleh diubah **bersama** perubahan perilakunya, dengan catatan di commit.

## Peta berkas test

| Berkas | Yang dikunci |
|--------|--------------|
| `testing_config_test.dart` | `TestingConfig.enabled` default `false` tanpa `--dart-define=TESTING_MODE=true` (regresi: literal `true` pernah ke-commit dan mengirim GPS/jam palsu ke produksi) |
| `attendance_rules_test.dart` | `AttendanceRules`: target jam pulang/masuk untuk shift biasa vs overnight (21:00–06:00), input degenerate, jam masuk diturunkan mundur dari jam pulang, sisa jam kerja dijepit ke jam masuk, `computeNextMasukTarget` (jeda siang) |
| `auth_service_test.dart` | Parsing `OtpRequestResult` (bentuk respons email OTP), `AuthService.parseLockoutMinutes`, `buildSetPasscodeBody` (key `passcodeLama` tidak dikirim bila kosong) |
| `account_info_phone_sheet_test.dart` | Sheet "Ubah Nomor HP" tahan keyboard muncul/hilang dan tidak menyentuh controller yang sudah di-dispose |
| `holiday_overtime_test.dart` | `TodayHolidayStatus.fromApi` (lembur hari libur), `WorkCalendar.upcomingHolidays`, `periodeTertutup`/`periodeLemburTertutup`, `OvertimeRequestRecord.fromApi` |
| `join_date_gate_test.dart` | Gerbang `joinDate` ("Belum Mulai Bekerja"), predikat tanggal, date picker sebelum `joinDate` |
| `staff_profile_join_date_test.dart` | Parsing `StaffProfile.joinDate`, fail-open bila kosong/tak valid, `copyWithRekening` mempertahankan `joinDate` |
| `leave_request_duration_test.dart` | `LeaveRequest.dayCount` memakai `jumlahHari` server, fallback ke rentang kalender |
| `work_date_picker_and_drive_guard_test.dart` | `WorkCalendar.hasSelectableForSubmission`, `showWorkDatePicker` tanpa tanggal terpilih, penjaga unggah ganda `SlipDriveSync` (`claimUpload`) |
| `rekening_test.dart` | `RekeningValidator` (5–20 digit, spasi/strip ditoleransi), rekening di `StaffProfile` |
| `salary_slip_test.dart` | `SalarySlip`: `KonfirmasiResult` (server memutuskan status), round-trip `dikirimKonfirmasiAt`, `alasanTolak` hanya saat `ditolak`, state pencairan, **THP = `gajiNetto`** (regresi EPIC 9), komponen di luar THP, potongan BPJS (EPIC 9c), statistik kehadiran |
| `slip_followup_test.dart` | Tipe & label periode, `SlipFilter`, label status kartu, flag batal-setuju & bukti, notifikasi slip (`SlipDeepLink`), `AttentionPulse`, detail slip (batalkan persetujuan, bukti), `SlipBuktiScreen` |
| `slip_and_rekening_screens_test.dart` | Widget `SalaryDetailScreen` (Fasilitas bagian sendiri, status menentukan tombol, dialog Tolak dengan centang, banner pencairan, penolakan sekali + tanda revisi) dan `RekeningScreen` |
| `widget_test.dart` | Smoke test: `HadirInApp` ter-build tanpa crash |

Tidak ada test untuk: `LoginScreen`/`PasscodeUnlockScreen`, `CameraCheckinScreen`, `HomeTab`/`MainScreen`, `LeaveTab` (pengajuan), `OnboardingDocumentsScreen`, `ApiClient`, `FcmService`/`NotificationCenter`, `SubordinateService`. Perubahan di area itu tidak punya jaring pengaman otomatis — verifikasi manual dan tulis test bila memungkinkan.

## Test yang akan perlu diubah bersama perilakunya

- **Dialog Tolak slip (R9).** `slip_and_rekening_screens_test.dart` (grup "tolak dialog with per-part checkboxes" dan "reject dialog") saat ini **mengunci perilaku lama**: tombol "Kirim ke HR" aktif bila ada centang **atau** catatan ≥ 5 karakter, dan aktif hanya dengan catatan tanpa centang. Server sejak 2026-10-25 menolak request tanpa `bagian` (400). Saat R9 dikerjakan, test ini harus diubah: tombol harus **tetap mati** bila tidak ada centang walau catatan ≥ 5 karakter, dan test baru itu harus terbukti merah terhadap `_valid` yang sekarang (`salary_screen.dart:2693`). Lihat [features/SLIP-GAJI-FLOW.md](features/SLIP-GAJI-FLOW.md).
- **RENCANA batal-setuju** (centang bagian wajib saat membatalkan): test dialog batal-setuju di `slip_followup_test.dart` ("detail slip: batalkan persetujuan", memakai `BatalSetujuDialog` yang sekarang hanya meminta alasan 5–300 karakter) perlu diubah bersama dialog barunya, dan test baru harus terbukti merah terhadap dialog lama.

## Konvensi

- Test hidup di `test/` dan menamai file sesuai area (`<area>_test.dart`). Komentar boleh Bahasa Indonesia, sama seperti kode.
