# Login, OTP, Passcode, dan Sesi

Diverifikasi terhadap kode 2026-11-06. Kontrak: [mobile-api.md bagian 1, 2, 11](../../../hadir-in-api-backend-express-js/docs/mobile-api.md) (#1–#6, #46–#48). Kode: `lib/screens/login_screen.dart`, `passcode_unlock_screen.dart`, `otp_verification_screen.dart`, `auth_wrapper.dart`, `lib/services/auth_service.dart`, `session_service.dart`, `phone_change_service.dart`, `fcm_service.dart`. Test: `test/auth_service_test.dart`, `test/account_info_phone_sheet_test.dart`.

## 1. Ide dasar

- **Identitas login = nomor HP.** Tidak ada username/password.
- **Staff lama masuk dengan passcode 6 digit tanpa OTP.** "Sudah punya passcode atau belum" dijawab **server** (`Staff.passcodeHash`), sehingga logout, ganti HP, atau install ulang tidak memaksa OTP lagi.
- **OTP dikirim ke EMAIL staff** (`Staff.email`), bukan WhatsApp/SMS (berubah di Sprint 2 OTP/auth overhaul, 2026-08-03). Dipakai untuk: staff baru yang belum punya passcode, lupa passcode, dan ganti nomor HP.
- **Passcode disimpan hash di server** (bcrypt); **tidak ada passcode di HP** (dulu di SharedPreferences, dihapus di Fase 8).
- **JWT staff 30 hari** (`type: "staff"`), ditolak oleh portal `/api/v1/*`.

## 2. Diagram status masuk app

```
start dingin → main() → SessionService.lockSession()  (sesi aktif := false, SELALU)
AuthWrapper:
   logged_in = false                   → LoginScreen
   logged_in = true & session_active=false → PasscodeUnlockScreen   ← kasus normal buka app
   logged_in = true & session_active=true  → MainScreen             ← hanya bila app tidak start dingin (mis. kembali dari background)
```

`isLoggedIn` dan `isSessionActive` adalah flag `SharedPreferences`; JWT dan staffId di `flutter_secure_storage`.

## 3. Login (`LoginScreen`, langkah `LoginStep`)

`phone → otp → enterPasscode → createPasscode → confirmPasscode`

| Langkah | Aksi | Endpoint | Hasil |
|---------|------|----------|-------|
| `phone` | submit nomor | `POST /auth/staff/passcode-status` `{phone}` (#1, publik) → `{hasPasscode, nama, lockedForMinutes}` | `lockedForMinutes > 0` → error "Akun terkunci sementara… coba lagi dalam N menit". `hasPasscode` → langkah `enterPasscode`. Selain itu → `request-otp` → langkah `otp` |
| `enterPasscode` | ketik 6 digit | `POST /auth/staff/login-passcode` `{phone, passcode}` (#2) → `{token, staff}` | simpan token + staffId → `_finishLogin`. Salah: 401 `Passcode salah. Sisa N percobaan.`; **5 gagal beruntun → kunci 15 menit** (429, in-memory server, hilang saat restart) |
| `otp` | kode 6 digit dari email | `POST /auth/staff/request-otp` (#3), `POST /auth/staff/verify-otp` `{phone, code}` (#4) → `{token, hasPasscode, staff}` | `hasPasscode` true & bukan jalur lupa → langsung `_finishLogin`; selain itu → `createPasscode` |
| `createPasscode` → `confirmPasscode` | passcode baru 2×, harus cocok | `POST /auth/staff/set-passcode` `{passcode}` (#5, ber-auth) | `_finishLogin` |

`_finishLogin(staffId)`: `SessionService.saveSessionWithPhone(phone, staffId)` (set `logged_in`, `session_active`, simpan nomor) → cek `GET onboarding-status` → `MainScreen` bila `completed`, `OnboardingDocumentsScreen` bila belum (gagal cek = anggap selesai; `MainScreen` memeriksanya lagi). `_persistLogin` juga memanggil `FcmService.registerWithBackend()` tanpa await.

Penjagaan OTP:
- **Kirim ulang**: hitung mundur 60 detik di UI; server menegakkan cooldown 60 dtk dan **maks 3 kirim / 30 menit** (429 → tombol kirim ulang diblokir permanen di layar dengan pesan server, `_resendBlockedMessage`).
- **Salah kode 3×** → server mengunci 15 menit (429); `_startOtpLockout` menghitung mundur dari angka menit yang di-parse dari teks pesan (`AuthService.parseLockoutMinutes`, default 15 — server tidak mengirim field terstruktur).
- Kode kedaluwarsa 10 menit.
- Nomor tak terdaftar: `passcode-status`/`login-passcode`/`verify-otp` membalas **404** (nomor bisa dienumerasi — dicatat backend); `request-otp` membalas 200 generik. Staff nonaktif → 403.

### Catatan nama menyesatkan

`_showMockWaNotification` (`login_screen.dart:119`) dan `_waNotifMessage` adalah sisa nama dari era WhatsApp/mock. Sekarang fungsi itu hanya menampilkan banner "[Hadir-In] Kode OTP Email Anda: …" **bila server mengembalikan `devCode`** (hanya non-production dan email gagal terkirim; di produksi selalu null). Tidak ada OTP palsu di app. Jangan diartikan sebagai fitur mock.

## 4. Lupa passcode

Dua pintu, mekanisme server sama ("Piece 3"):

1. **Saat login** (`enterPasscode`): tombol "Lupa Passcode? Kirim OTP" → `_forgotPasscode()` set `_isForgotPasscodeFlow = true` → `request-otp` → `otp` → `verify-otp`. Karena `hasPasscode` true, biasanya app langsung masuk; flag ini memaksa app **tetap ke `createPasscode`**. Token dari `verify-otp` memuat klaim `passcodeResetAllowedUntil` (10 menit) sehingga `set-passcode` **tanpa `passcodeLama`** diterima (`AuthService.buildSetPasscodeBody` sengaja tidak mengirim key `passcodeLama` sama sekali bila kosong — backend membedakan "tidak ada" dari "ada tapi salah").
2. **Saat buka kunci** (`PasscodeUnlockScreen`): tautan "Lupa?" → sheet "Lupa Passcode?" → "Kirim OTP ke Email" (satu-satunya pilihan; WA/Gmail lama dihapus) → `UnlockStep.verifyOtp` → passcode baru → konfirmasi → `set-passcode` → `setSessionActive(true)` → `MainScreen`.

Bila email pemulihan tak bisa diakses: layar passcode selalu menampilkan tombol **Keluar akun** supaya staff bisa logout dan login dengan nomor lain (`PasscodeUnlockScreen._logout`). Tidak ada jalur pemulihan lain; admin tidak mereset passcode dari app.

## 5. Buka kunci (`PasscodeUnlockScreen`)

Nomor diambil dari `SessionService.getSavedPhone()`. Verifikasi = `POST login-passcode` (sama dengan login) — sekaligus **menyegarkan JWT**, jadi sesi yang token-nya kedaluwarsa pulih saat membuka kunci. Sukses → `setSessionActive(true)` → `MainScreen`. Gagal → shake + pesan server (termasuk sisa percobaan dan kunci 15 menit).

Tidak ada biometrik. Tidak ada auto-lock saat app masuk background lama; kunci hanya terpasang di start dingin (`main()`).

## 6. Ubah passcode (menu Akun → Keamanan)

`AccountTab._showChangePasscode`: passcode lama + baru + konfirmasi (6 digit) → `POST set-passcode {passcode, passcodeLama}`; server memverifikasi lama (401 `Passcode lama salah`). Tidak ada kunci/rate-limit khusus di app.

## 7. Ganti nomor HP (Akun → Informasi Akun → Ubah Nomor HP)

Membalik keputusan Sprint 2 "hanya admin" (2026-08-29): staff menggantinya sendiri.

1. `_ChangePhoneSheet` minta nomor baru (validasi lokal: ≥ 9 digit) → `POST /staff/:id/phone-change/request-otp {phone}` (#46). OTP dikirim ke **email** (bukan nomor baru, karena itu sirkular). Server: 400 nomor sama/tidak valid, 409 `Nomor HP tersebut sudah dipakai akun lain`, 429 cooldown 60 dtk.
2. `OtpVerificationScreen` ("Verifikasi Identitas", footnote tentang dokumen yang perlu diajukan ulang) → `POST phone-change/verify {code}` (#47); kirim ulang = `request-otp` lagi.
3. Mundur dari layar OTP tanpa verifikasi → `POST phone-change/cancel` (#48), best-effort; nomor lama tetap berlaku sampai OTP terbukti benar.
4. Sukses: nomor berganti di server, `documentsResetAt` terisi (gerbang dokumen **dibuka ulang**) dan notifikasi office `staff_phone_changed`. App: `SessionService.savePhone(newPhone)`, dialog "Nomor HP berhasil diganti", lalu `pushAndRemoveUntil` ke `OnboardingDocumentsScreen` (mode ajukan ulang; dokumen yang pernah disetujui bisa dipakai ulang — [ONBOARDING-DOKUMEN.md](ONBOARDING-DOKUMEN.md)).

**Email tidak bisa diubah dari app** (field read-only): email adalah kanal pemulihan; mengizinkan ubah email + nomor dari satu layar berarti pemegang HP yang sedang login bisa memindahkan seluruh jalur pemulihan. Kartu "Hubungi Admin" di tab Akun (bila `kontakAdminPhone` terisi) masih menyebut nomor "hanya bisa diganti oleh admin kantor" — teks basi yang bertentangan dengan alur di atas (known issue).

## 8. Penyimpanan sesi

| Data | Tempat | Dihapus saat logout? |
|------|--------|----------------------|
| JWT (`hadir_in_token`), staffId (`hadir_in_staff_id`) | `flutter_secure_storage` (Android: `encryptedSharedPreferences`) | ya |
| `hadir_in_logged_in`, `hadir_in_session_active`, `hadir_in_employee_id` | `SharedPreferences` | ya |
| `hadir_in_phone` (nomor terakhir) | `SharedPreferences` | **tidak** (sengaja: kenyamanan; bukan kredensial) |
| `hadir_in_sound_notif_mode`, `notif_shown_ids`, `notif_local_alert_*`, `slip_drive_saved_ids`, draft dokumen | `SharedPreferences` / folder privat | **tidak**, kecuali jalur tertentu (lihat bawah) |

## 9. Logout

Lima titik keluar (empat hidup, satu kode mati), **hasilnya tidak sama**:

| Titik | Memanggil `SessionService.clearSession()` | Juga `DocumentDraftService.clear()` + `NotificationCenter.reset()` |
|-------|:---:|:---:|
| `AccountTab._logout` (menu Logout) | ya | **tidak** |
| `HomeTab._logout` (private, tidak dipanggil siapa pun — kode mati) | ya | tidak |
| `PasscodeUnlockScreen._logout` | ya | **tidak** |
| `OnboardingDocumentsScreen._logout` | ya | **tidak** |
| `MainScreen._logout` (hanya dari tampilan error "Gagal memuat data → Keluar") | ya | **ya** |

`clearSession()` melakukan, berurutan: `FcmService.unregisterFromBackend()` (**dulu**, selagi JWT ada — `DELETE /fcm-token`) → hapus flag SharedPreferences → hapus JWT/staffId dari secure storage → `AppSession.clearUser()`. Komentar di `MainScreen._logout` menyatakan draft dokumen dan penanda notifikasi terikat staff dan harus dibersihkan "supaya tidak bocor ke staff berikutnya di HP yang sama" — tetapi jalur logout yang dipakai staff sehari-hari (Akun) tidak melakukannya. **Known issue** (rekomendasi: pindahkan pembersihan ke `SessionService.clearSession()`; belum dilakukan karena di luar cakupan dokumen).

## 10. Token kedaluwarsa

`ApiException.isUnauthorized` (401) ada tetapi **tidak ada handler global** yang memaksa keluar saat 401; setiap layar menampilkan pesan error-nya sendiri. Dalam praktik token disegarkan tiap start dingin (buka kunci = `login-passcode`), sehingga masalah baru muncul bila app dibiarkan hidup > 30 hari tanpa start dingin (**perlu dicek**).

## 11. Known issues

- Logout tidak seragam (bagian 9).
- `_showMockWaNotification` / `_waNotif*` bernama menyesatkan (bagian 3).
- Teks kartu "Hubungi Admin" basi (bagian 7).
- Mode `LoginDestination.leaveRequest` (re-verifikasi passcode di dalam `LoginScreen`) hanya terjangkau dari `LandingScreen` yang yatim → kode mati.
- Tidak ada handler 401 global (bagian 10).
- Enumerasi nomor lewat 404 di tiga endpoint (catatan backend).
