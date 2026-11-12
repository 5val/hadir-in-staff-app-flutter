# Peta Fitur Per Layar

Diverifikasi terhadap kode 2026-11-06 (branch `sprint3`). Kontrak endpoint: [backend mobile-api.md](../../../hadir-in-api-backend-express-js/docs/mobile-api.md) (nomor `#n` di bawah merujuk tabel di sana). Label: **RENCANA** = belum di kode; **perlu dicek** = tidak terbukti dari kode.

## 1. Alur masuk (gerbang berlapis)

```
main()  ──► FcmService.init() (tanpa await) ► initializeDateFormatting ► SessionService.lockSession()  [main.dart]
AuthWrapper (auth_wrapper.dart) membaca SharedPreferences:
   isLoggedIn=false                      ► LoginScreen
   isLoggedIn=true, sesi aktif=false     ► PasscodeUnlockScreen   (SELALU begini setelah start dingin, karena lockSession())
   isLoggedIn=true, sesi aktif=true      ► MainScreen
MainScreen._hydrateProfile (main_screen.dart):
   GET profile (#6) ► gagal: layar "Gagal memuat data" (Coba Lagi / Keluar)
   GET onboarding-status (#19) ► completed=false: tampilkan OnboardingDocumentsScreen (gerbang dokumen); error jaringan = fail-open
   muat kalender kerja (#35) ► hidrasi AttendanceRules (best-effort)
   GET attendance/today (#9) ► hidrasi status Home/FAB
   mulai polling notifikasi 45 dtk + guard absensi 3 mnt
   GET logs (#36) ► popup naik jabatan / surat peringatan (StaffLogDialog), lalu ditandai dibaca per log (#37)
```

Alur login/passcode/OTP: [AUTH-LOGIN-FLOW.md](AUTH-LOGIN-FLOW.md). Gerbang dokumen: [ONBOARDING-DOKUMEN.md](ONBOARDING-DOKUMEN.md).

## 2. Navigasi utama (`MainScreen`, bottom bar)

`IndexedStack` 5 slot; slot 2 kosong (diisi FAB kamera di tengah).

| Slot | Label | Layar | Siapa |
|------|-------|-------|-------|
| 0 | Home | `HomeTab` | semua staff |
| 1 | Cuti & Izin | `LeaveTab` | semua staff (tombol "See My Team" hanya bila `isApprover`) |
| FAB | (kamera) | `CameraCheckinScreen` via `MainScreen._onFabTap` | semua staff |
| 3 | Gaji | `SalaryScreen(isFromAccount: false)` | semua staff |
| 4 | Akun | `AccountTab` | semua staff |

Ada cabang `isManager = currentUser.role == UserRole.admin` (`main_screen.dart:963`) yang menukar slot 1 menjadi "Tim" (`AdminDashboardTab`) dan `_buildAdminLayout()`. **Cabang ini mati**: `UserRole.admin` tidak pernah dihasilkan dari API (`StaffProfile.toUserProfile`, `models.dart:2302`, hanya `supervisor`/`staff`). Lihat bagian 9 dan [ROLE-MATRIX.md](ROLE-MATRIX.md).

Tap notifikasi / banner → `_onTabTap(index)` (peta di [NOTIFICATION-SYSTEM.md](../NOTIFICATION-SYSTEM.md)).

## 3. Home (`home_tab.dart`)

| Elemen | Aksi / isi | Endpoint / sumber | Gerbang |
|--------|-----------|-------------------|---------|
| App bar: ikon riwayat | buka `AllAttendanceHistoryScreen` (kalender bulan, `limit: 100`) | `GET attendance?month=YYYY-MM&limit=100` (#16) | — |
| App bar: lonceng | buka `NotificationScreen` | `GET notifications` (#39) | titik merah hanya bila `NotificationCenter.unreadCount > 0` (diisi polling `MainScreen` + layar Notifikasi) |
| Banner Hari Libur Kerja | info lembur hari libur disetujui | kalender (#35) | hanya bila `hariIni.kerjaHariLibur` |
| Banner Rekening belum diisi | buka `RekeningScreen` | profil | hilang bila `rekeningLengkap` |
| Banner MODE TESTING | penanda | `TestingConfig` | hanya `--dart-define=TESTING_MODE=true` |
| Kartu lokasi | GPS + jarak ke titik kantor, peringatan GPS palsu | `geolocator` (lokal) | `_checkLocation` saat buka + tarik-refresh |
| Kartu Check-In | buka kamera → `POST check-in` (#10) | | tombol aktif hanya bila GPS aktif, **dalam radius**, dan bukan `isMocked` (masing-masing mengikuti Kebijakan Absensi sejak 2026-11-12: radius hanya bila `cekRadius`, GPS hanya bila `wajibGps`, mock hanya bila `deteksiMockGps`); kartu diganti "Belum Mulai Bekerja" (sebelum `joinDate`) atau kartu Hari Libur (`hariIni.bolehAbsen=false`) |
| Kartu Aktivitas Saat Ini | hitung mundur ke jam pulang, lalu timer lembur naik | `AttendanceRules` | status checkedIn/onBreak/breakEnded |
| Tombol Istirahat / Break | `POST break-in` (#14); selesai istirahat `POST break-out` (#15) | | hanya setelah check-in, sebelum check-out |
| Tombol Check-Out | buka kamera → `POST check-out` (#11) | | lihat catatan "kartu vs FAB" di bawah |
| Kartu Detail Kehadiran, Timeline | jam/lokasi/foto absen, uang makan | `attendance/today` (#9) | setelah check-in |
| Tarik-refresh | muat ulang profil, absensi hari ini, cek ulang lokasi | #6, #9 | — |
| Tombol **SOS** (FAB Home) | dialog "Hubungi Admin/HR": nomor `kontakAdminPhone` office (profil), tombol "Hubungi WhatsApp" membuka `wa.me` (fallback salin nomor); bila kosong dialog berisi info "belum diatur" tanpa tombol hubungi | profil (#6) | F8 |

**Dua pintu absen (setara sejak F5).** FAB MainScreen dan kartu Home memakai SATU alur `runAttendanceEntry` (`widgets/attendance_entry_flow.dart`): sesi menggantung -> konfirmasi hari libur -> dialog "Belum Jam Pulang!" -> kamera -> GPS segar (+ tolak lokasi palsu, F4) -> pemanggil mengirim ke server. Foto wajib (F3) bila kebijakan `wajibFoto`; kebijakan (`GET attendance/policy`) menentukan foto/GPS/radius/mock dan liveness kedip+toleh (2026-11-12). Aturan rinci: [ABSENSI-SHIFT-RULES.md](ABSENSI-SHIFT-RULES.md).

Status absensi lokal (`AttendanceProviderStatus`): `notCheckedIn` → `checkedIn` → `onBreak` ⇄ `breakEnded` → `checkedOut`; semuanya diturunkan dari satu record `attendance/today` di `AttendanceProvider.hydrateFromToday` (tidak ada jalur lain yang menebak status).

## 4. Cuti & Izin (`leave_tab.dart`)

4 sub-tab: **Cuti**, **Izin**, **Lembur**, **Riwayat**. Detail dan aturan jendela tanggal: [CUTI-IZIN-LEMBUR.md](CUTI-IZIN-LEMBUR.md).

| Sub-tab | Aksi | Endpoint |
|---------|------|----------|
| Cuti | ajukan cuti tahunan (`subTipe: "Cuti Tahunan"`) | `POST leave` (#24); sisa cuti dari profil |
| Izin | Sakit / Seminar / Lainnya, foto lampiran opsional (maks 3) | `POST leave` (#24) |
| Lembur | daftar hari lewat jam pulang yang bisa diajukan + lembur hari libur | `GET lembur/eligible-days` (#25), `POST lembur` (#27) |
| Riwayat | riwayat cuti/izin (filter jenis/status) + riwayat lembur | `GET leave` (#22), `GET lembur` (#26) |
| Header "See My Team" | hanya `isApprover`; buka `SubordinateRequestsScreen` (Setujui/Tolak cuti-izin bawahan) + riwayat tim | `GET subordinates/requests` (#49), `PATCH subordinates/leave/:id` (#50) |

Persetujuan **lembur** oleh Manager sekarang ada di `SubordinateRequestsScreen` ("Pengajuan Karyawan"): bagian "Pengajuan Lembur" tampil bila `canApproveLembur`; tolak (cuti/izin/lembur) punya kolom alasan opsional (`alasanTolak`, maks 500). `_buildEmployeeTab()` dan `_EmployeeAppTile` mati di `leave_tab.dart` sudah dihapus. Lihat [CUTI-IZIN-LEMBUR.md](CUTI-IZIN-LEMBUR.md).

## 5. Gaji (`salary_screen.dart`)

Daftar slip (`SalaryScreen`) + detail (`SalaryDetailScreen`). Dipakai di tab Gaji dan di Akun → "Riwayat Gaji" (`isFromAccount: true`). Alur penuh: [SLIP-GAJI-FLOW.md](SLIP-GAJI-FLOW.md).

| Aksi | Endpoint |
|------|----------|
| Muat daftar slip (limit 500), filter periode | `GET gaji/slip?limit=500` (#28) |
| Segarkan detail setelah 409 / pull-refresh | `GET gaji/slip/:slipId` (#29) |
| Konfirmasi ("Konfirmasi, sudah benar") | `POST .../konfirmasi` (#31) |
| Tolak ("Ada yang salah") | `POST .../tolak` (#32) |
| Batalkan persetujuan | `POST .../batal-setuju` (#34) |
| Unduh PDF / Simpan ke Google Drive | `GET .../pdf` (#30) |
| Lihat bukti pembayaran | `GET .../bukti` (#33) |

## 6. Akun (`account_tab.dart`)

| Menu | Aksi | Endpoint |
|------|------|----------|
| Kartu profil | nama, jabatan, QR "Scan ID" (`user.employeeId`), Sisa Cuti, Shift; tarik-refresh profil | #6 |
| Kartu "Hubungi Admin" | WhatsApp / Telepon ke `kontakAdminPhone` office | profil (#6) — hanya bila terisi |
| Informasi Akun | `AccountInfoScreen`: email read-only, nomor HP read-only + tombol **Ubah Nomor HP** (OTP email), rekening | `phone-change/request-otp|verify|cancel` (#46–#48) |
| Dokumen Saya | `OnboardingDocumentsScreen(manageMode: true)`; badge bila ada dokumen ditolak | #19, #17, #20, #21 |
| Riwayat Kehadiran | `AllAttendanceHistoryScreen` | #16 |
| Riwayat Gaji | `SalaryScreen(isFromAccount: true)` | #28 |
| Notifikasi (switch) | disimpan (`SessionService.saveNotifEnabled`) dan dibaca `PushNotificationService.show` lewat `NotificationDelivery.decide`: mati = notifikasi umum tidak ditampilkan; pengingat absensi (saluran terpisah) tetap muncul | - |
| Notifikasi Suara | dialog Sound/Vibration/Silent, disimpan dan DIBACA `PushNotificationService` (saluran Android per mode: `hadirin_umum_sound/_vibration/_silent`, dst.) | - |
| Ubah Passcode | dialog passcode lama + baru + konfirmasi | `POST auth/staff/set-passcode` (#5) |
| Keunggulan Hadir-In | dialog statis | — |
| Logout | konfirmasi → `SessionService.clearSession()` → LoginScreen | `DELETE fcm-token` (#43) |
| Tema, Bahasa, Ukuran Teks, Panduan, Syarat & Ketentuan, Kebijakan Privasi | snackbar "akan segera tersedia" (`_showComingSoon`) | — |
| Ikon kamera di avatar | snackbar "Ganti foto profil!" saja (tidak ada fitur unggah foto profil) | — |

Rekening (`RekeningScreen`, dari Akun → Informasi Akun atau banner Home): isi/ganti rekening gaji → `PUT rekening` (#45). Validasi lokal: bank ≤ 100 karakter, nomor 5–20 digit (spasi/strip diabaikan), nama pemilik ≤ 150. Dialog "Ganti rekening gaji?" menyebut HRD akan diberi tahu, tetapi **tidak menyebut** bahwa server juga **mencabut Setujui Cair** semua slip `unpaid` staff itu (mobile-api #45).

## 7. Layar pendukung

| Layar | Fungsi |
|-------|--------|
| `CameraCheckinScreen` | kamera depan, deteksi wajah ML Kit ("ada wajah & di tengah"; bukan identitas), tantangan liveness kedip -> toleh -> lurus bila kebijakan mewajibkan (foto otomatis; fallback "Lanjut tanpa verifikasi gerak"), kartu lokasi/jarak, konfirmasi; shutter manual aktif bila wajah terdeteksi dan di tengah (liveness mati / fallback). Detail: [ABSENSI-SHIFT-RULES.md](ABSENSI-SHIFT-RULES.md) |
| `NotificationScreen` | daftar + filter + mark-read (#40, #41) |
| `OtpVerificationScreen` | halaman OTP 6 digit reusable; dipakai hanya untuk ganti nomor HP (login punya langkah OTP sendiri di `login_screen.dart`) |
| `SlipBuktiScreen` | penampil bukti transfer (gambar/PDF) |
| `AllAttendanceHistoryScreen` | rekap kehadiran per bulan |
| `SubordinateRequestsScreen`, `AllSubordinateLeaveHistoryScreen` | persetujuan & riwayat cuti/izin bawahan (`status=all`) |
| `StaffLogDialog` (widget) | popup naik jabatan / surat peringatan setelah masuk |
| `OpenSessionDialog`, `EarlyCheckoutDialog` (widget) | lihat ABSENSI-SHIFT-RULES |

## 8. Gerbang & mode khusus (ringkasan)

| Gerbang | Di mana | Perilaku |
|---------|---------|----------|
| Gerbang dokumen onboarding | `MainScreen._hydrateProfile` | blokir isi app sampai dokumen **wajib** (server: `completed`) pernah diajukan; BPJS/NPWP wajib hanya bila BPJS staff aktif; error jaringan = lolos |
| Passcode | `AuthWrapper` + `main()` | start dingin selalu minta passcode (`lockSession()`) |
| Sesi menggantung | FAB + kartu check-in | blokir check-in sampai `auto-checkout` (server menolak 409 bila dilewati) |
| Belum mulai bekerja (`joinDate`) | Home + server | kartu "Belum Mulai Bekerja"; server 403 |
| Hari libur | Home + server | kartu Hari Libur kecuali ada lembur hari libur disetujui |
| Mode testing | `TestingConfig` | GPS/jam palsu, hanya `--dart-define=TESTING_MODE=true` |
| 409 slip basi | `SalaryDetailScreen` | pesan server + tutup/segarkan layar |

## 9. Layar yatim, mock, dan "coming soon"

**Tidak terjangkau dari navigasi mana pun** (kelas dibuat, tak pernah diinstansiasi — diverifikasi dengan pencarian nama kelas di seluruh `lib/`):

| File | Catatan |
|------|---------|
| `landing_screen.dart` (`LandingScreen`) | satu-satunya yang memakai `LoginDestination.leaveRequest`, jadi mode "re-verifikasi passcode" di `login_screen.dart` (`!_isInitialLogin`) juga tak terjangkau |
| `profile_screen.dart` (`ProfileScreen`) | berisi `_EmployeeQrCard`; `SampleData.currentUser` |
| `checkin_screen.dart` (`CheckinScreen`) | check-in mock lama; `SampleData.morningShift` |
| `history_screen.dart` (`HistoryScreen`) | diimpor `account_tab.dart` & `home_tab.dart` tapi tidak dipakai; `SampleData.recentAttendance` |
| `all_leave_history_screen.dart` (`AllLeaveHistoryScreen`) | diimpor `leave_tab.dart` tapi tidak dipakai; `SampleData.leaveRequests` |
| `leave_choice_screen.dart` | seluruh isi file di-comment |
| `break_screen.dart` (`BreakScreen`) | diimpor `home_tab.dart` tapi tidak dipakai; teks dari `SampleData.breakMessages` |
| `manager_dashboard_tab.dart` (`AdminDashboardTab`) | hanya dirujuk cabang `UserRole.admin` yang mati; seluruh isi dari `SampleData.allUsers` (mock) |
| `home_tab.dart#AttendanceHistoryFullScreen` | kelas di dalam file Home, tak dipakai |
| `lib/theme/app_theme copy.dart` | salinan cadangan |

**`SampleData`** (`models.dart:1652`, data karangan): `SampleData.currentUser` hanya meneruskan ke `AppSession.currentUser`, yang diisi dari profil server (`AppSession.setStaff`) sebelum `MainScreen` menampilkan tab apa pun — jadi layar aktif (`HomeTab`, `LeaveTab`, `SalaryScreen`, `AccountTab`, `AllAttendanceHistoryScreen`) membaca data nyata dalam alur normal. Fallback `SampleData._users.first` (nama "Rina Kartika", mock) hanya muncul bila `currentUser` dibaca sebelum profil termuat (`models.dart:11`). Fungsi login mock lama (`AppSession.validateLogin`, `setUser*`, `findUserByPhone`) tidak dipakai alur login sekarang.

**Menu "coming soon"** (hanya snackbar): Tema, Bahasa, Ukuran Teks, Panduan Hadir-In, Syarat & Ketentuan, Kebijakan Privasi. Tidak ada layar staff untuk **Pindah Lokasi** (notifikasi `location_transfer_*` jatuh ke Home).

## 10. Known issues (layar)

- Tab "Tim" mock tak terjangkau; layar yatim (bagian 9) menambah beban baca kode.
- Komentar di `salary_screen.dart` build (rumus "Take Home Pay = Gaji Bersih + Tunjangan - Potongan") sudah basi; THP = `gajiNetto` server (lihat [SLIP-GAJI-FLOW.md](SLIP-GAJI-FLOW.md)).
