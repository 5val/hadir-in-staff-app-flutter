# Absensi, Shift, dan Lembur — Aturan dari Sisi App

Apa yang **app** lakukan dan tidak lakukan untuk absensi. Prinsip dasar: **server adalah hakim** (geofence, jam, lembur, status); app menampilkan, mengumpulkan foto + GPS, dan memberi peringatan dini. Aturan bisnis lintas repo (ambang lembur, pembulatan, shift malam, auto-checkout, hari libur): [ATURAN-BISNIS-PENGGAJIAN.md §6–§7](../../../hadir-in-web-admin-react/docs/product/ATURAN-BISNIS-PENGGAJIAN.md). Kontrak: [mobile-api.md bagian 3](../../../hadir-in-api-backend-express-js/docs/mobile-api.md) (#9–#16, #35). Diverifikasi terhadap kode 2026-11-06.

Kode utama: `lib/screens/home_tab.dart`, `lib/screens/main_screen.dart` (FAB + penjaga), `lib/screens/camera_checkin_screen.dart`, `lib/services/attendance_service.dart`, `attendance_provider.dart` (`AttendanceProvider` + `AttendanceRules`), `location_service.dart`, `calendar_service.dart`, `lib/widgets/open_session_dialog.dart`, `early_checkout_dialog.dart`, `lib/config/testing_config.dart`. Test: `test/attendance_rules_test.dart`, `holiday_overtime_test.dart`, `join_date_gate_test.dart`.

## 1. Alur satu hari

```
[Home / FAB]  ► (sesi menggantung? ► OpenSessionDialog ► auto-checkout)
              ► kamera depan + deteksi wajah ► foto ► konfirmasi (hanya aktif bila dalam radius)
              ► GPS segar (LocationService.current) ► POST check-in {lat,lng,accuracy,fotoMasuk(base64),time?}
   ... Break In (POST break-in) ⇄ Break Out (POST break-out) boleh berkali-kali ...
              ► kamera ► POST check-out {lat,lng,accuracy,fotoKeluar,time?}
```

Status diturunkan dari satu record (`GET attendance/today`) di `AttendanceProvider.hydrateFromToday`: `checkOut` terisi → `checkedOut`; sedang istirahat → `onBreak`; sudah check-in dan `breakMinutes > 0` → `breakEnded`; sudah check-in → `checkedIn`; selain itu `notCheckedIn`. Tidak ada jalur lain yang menebak status.

## 2. Geofence

- **Yang mengikat adalah server** (`lib/geo.ts` backend): check-in/out di luar radius → HTTP 403 dengan pesan jarak & radius, ditampilkan apa adanya. Akurasi GPS dikirim (`accuracy`) sebagai toleransi tambahan di server.
- **App hanya menampilkan & menggerbangi UI.** Jarak dihitung `Geolocator.distanceBetween` ke titik `lokasiLatitude/Longitude` staff (dari profil); dianggap dalam radius bila `jarak <= lokasiRadius + clamp(accuracy, 0, 50)` (radius default 100 m bila kosong). Di Home hasilnya mengaktifkan/mematikan kartu Check-In/Check-Out; di layar kamera tombol konfirmasi (`onPressed: inRange ? _confirm : null`, `camera_checkin_screen.dart:1653`) hanya aktif bila dalam radius.
- **Staff tanpa lokasi kerja** (`lat/lng` null, mis. lapangan): tidak ada geofence — app menganggap "dalam area" dan server melewati pemeriksaan.
- **Izin & GPS** (`LocationService.current`): cek layanan lokasi → minta izin → `getCurrentPosition(accuracy: high, timeLimit: 20 dtk)`. Kegagalan dipetakan ke pesan khusus (`GpsFailure`: GPS mati / izin ditolak / ditolak permanen / timeout / lainnya). Koordinat dibaca ulang segar tepat sebelum kirim (bukan hasil cek beberapa menit lalu).

## 3. Batas deteksi wajah (JANGAN diklaim sebagai verifikasi identitas)

`CameraCheckinScreen` memakai ML Kit `FaceDetector` dengan `performanceMode: fast`, `enableClassification/Landmarks/Contours/Tracking: false`, `minFaceSize: 0.15` (`camera_checkin_screen.dart:149-157`). Tombol shutter aktif hanya bila `_faceDetected && _faceInCenter` (pusat kotak wajah dalam ±28% dari pusat frame, `_isFaceCentered`). Artinya:

- Yang diperiksa: **ada wajah (≥ 15% frame) dan berada di tengah**. Wajah terbesar yang dipakai.
- **Tidak ada**: liveness (kedip/gerak), pencocokan identitas, deteksi foto-dari-layar. Foto orang lain / foto dari foto lolos.
- Di Web (`kIsWeb`) shutter aktif tanpa deteksi wajah.
- Kamera: kamera **depan**, portrait terkunci. Foto dikirim sebagai base64 (`fotoMasuk`/`fotoKeluar` + `fotoMimeType`), disimpan server ke Google Drive; path file lokal tidak diterima server.
- Bila `takePicture()` melempar, kode **tetap melanjutkan** tanpa file (`catch (_) {}`, komentar "untuk demo / device tanpa kamera") → `imagePath` null → request dikirim **tanpa foto** (server menerima foto opsional). Perilaku ini mungkin tidak diinginkan di produksi (**perlu keputusan produk**).

## 4. GPS palsu (mock location)

Home membaca `Position.isMocked` (geolocator, Android) dan menolak mengaktifkan kartu Check-In/Out bila true (`_locationInRange = inRange && !pos.isMocked`, `home_tab.dart:326-328`), serta menampilkan peringatan "fake location terdeteksi". Keterbatasan:

- Pemeriksaan **hanya ada di Home**. Jalur **FAB** (`MainScreen._onFabTap`) dan layar kamera **tidak** memeriksa `isMocked`; server pun tidak menerima/menimbang flag itu. GPS palsu karenanya bisa lolos lewat FAB.
- `isMocked` hanya terdeteksi di Android; tidak ada deteksi lain (root, developer options, emulator).
- Di mode testing `fakePosition()` sengaja `isMocked: false`.

## 5. Check-in

1. Gerbang UI (kartu Home, bergantian dengan kartu pengganti): "Belum Mulai Bekerja" bila sebelum `joinDate`; kartu **Hari Libur** (nama + alasan server) bila `hariIni.bolehAbsen == false`; selain itu kartu Check-In.
2. Sebelum kamera: `refreshOpenSession()`; bila ada sesi menggantung → `OpenSessionDialog` (lihat bagian 8) dan **tidak** lanjut.
3. FAB saja: bila `hariIni.kerjaHariLibur` → dialog "Hari libur: … Seluruh jam kerja dihitung sebagai lembur. Uang makan dan tunjangan harian tidak berlaku" sebelum kamera (`_confirmHolidayWorkCheckIn`).
4. Setelah kamera: GPS segar; gagal → snackbar pesan `GpsFailure`. Lalu `POST check-in`; error server (geofence 403, `joinDate` 403, gerbang libur 403, "sudah check-in" 400, 409 sesi menggantung) ditampilkan apa adanya.
5. Penentuan terlambat dan denda sepenuhnya di server (dari jam server + `Shift.jamMasuk` + toleransi, wrap-aware untuk shift malam). App tidak punya angka toleransi keterlambatan — pesan "Anda sudah terlambat!" di Home dibandingkan dengan `jamMasuk + 15 menit` hanya untuk sapaan (`_greetingMsg`), bukan aturan.

## 6. Istirahat

- Tidak ada jendela jam: staff boleh Break In kapan pun **setelah check-in dan sebelum check-out** (`_canStartBreak`); yang dicatat server adalah **durasi** (`breakDurasi`, akumulatif bila berkali-kali). `POST break-in` / `break-out` tanpa body; server mencatat waktunya.
- Break Out lewat tombol di Home atau lewat FAB (status `onBreak` → dialog "Selesai Istirahat?" tanpa kamera).
- Hitung mundur istirahat bila Shift punya `jamIstirahatSelesai` (`AttendanceRules.breakEndTargetToday` / `secondsUntilBreakEnd`); negatif = lewat jam selesai ("+MM:SS"). Layar `BreakScreen` lama adalah layar yatim.
- Pengingat lokal: istirahat belum ditutup padahal jam pulang lewat (`break_reminder`); separuh shift lewat tanpa istirahat (`attendance_reminder_break`).

## 7. Check-out

- Tombol/kartu check-out aktif bila sudah check-in dan belum check-out **dan** GPS dalam radius (Home).
- **FAB saja**: sebelum kamera, `refreshToday()` lalu, bila belum `isAfterEarliestCheckout` (jam pulang − toleransi pulang, memakai **snapshot shift saat check-in** bila ada) → dialog **"Belum Jam Pulang!"** (`showEarlyCheckoutDialog`). Tidak ditampilkan di hari libur kerja. **Kartu Home melewati dialog ini** (known issue: dua pintu tidak setara).
- Server menolak check-out sebelum jamnya (`Belum bisa check-out. Check-out baru bisa dilakukan mulai pukul HH:mm`, 400) — jadi dialog di app adalah pengingat, server yang menegakkan.
- Record hasil check-out (field `uangMakan`) → snackbar "Uang makan hari ini didapat" bila `uangMakan > 0` (app membaca `AttendanceRecord.uangMakan`, bukan blok `uangMakanInfo` dari respons).
- Lembur dihitung server **sekali saat check-out** dan ditulis ke `Attendance.lembur` (jam terbayar final). App tidak menghitung lembur terbayar sendiri; yang dihitung app hanya timer tampilan (bagian 9).

## 8. Sesi menggantung dan auto-checkout

Absensi yang tidak ditutup (lupa Break Out / Check-Out), termasuk yang terbawa ke hari berikutnya:

- `GET attendance/open-session` (#12) → `OpenAttendanceSession{tanggal, jamPulangShift, batasLemburJam, reason ("hari_sebelumnya" | "lewat_batas_lembur"), lupaBreakOut}`.
- App memeriksa: tiap start (`_runAttendanceGuards`, timer 3 menit, saat resume) dan sebelum check-in (FAB & kartu Home).
- **Popup "Anda Belum Check-Out"** hanya untuk `isPreviousDay` (keputusan produk 2026-09-09). Sesi **hari ini** yang cuma lewat batas lembur tidak memicu popup — hanya notifikasi `attendance_overtime_limit`; staff tetap boleh lanjut/ check-out manual.
- `OpenSessionDialog` tidak bisa ditutup dengan ketuk latar dan tak punya tombol "nanti": satu-satunya aksi "Check-Out Sekarang" → `POST auto-checkout` (#13). Alasannya: selama baris terbuka, check-in berikutnya ditolak server 409.
- **Jam yang dicatat** (kode backend `routes/mobile/attendance.ts` auto-checkout; selaras teks `openSessionExplanation`): absensi **hari sebelumnya** → dipatok ke **jam pulang shift** (`shiftTerms.jamPulang`, snapshot bila ada); absensi **hari ini** → **jam sekarang**. **Lembur selalu 0** pada kedua kasus (ini lupa check-out, bukan lembur). Catatan: ATURAN-BISNIS-PENGGAJIAN §6.4 menyebut "jam keluar dipaku ke jam pulang shift" tanpa membedakan hari ini/kemarin — sedikit tidak presisi untuk kasus hari ini (lihat laporan).
- Pesan kegagalan: snackbar `ApiException.message`.

## 9. Lembur sisi app

- **Batas harian**: `AttendanceRules.maxLemburJam` = `min(Jabatan.maxExtraHour, 4)`; `maxExtraHour` 0/null → 4 (`hydrateMaxLembur`, `attendance_provider.dart:~535`). Sama dengan server (`resolveBatasLemburJam`); batas mingguan 18 jam **tidak** ditegakkan di mana pun (keputusan produk).
- **Timer Home**: sebelum jam pulang → hitung mundur `remainingWorkTime` (dijepit ke jam masuk: datang awal tidak menambah sisa jam); setelah jam pulang → timer lembur naik dari 00:00:00 (`overtimeElapsed`). Setelah lewat batas → peringatan "saatnya check-out" (kartu merah + notifikasi `attendance_overtime_limit`, sekali per hari).
- **Pengajuan lembur** dilakukan **setelah** check-out dari tab Cuti & Izin → Lembur (hari yang `bisaDiajukan` dari `lembur/eligible-days`), kecuali **lembur hari libur** yang harus diajukan & disetujui **sebelum** hari H. Detail: [CUTI-IZIN-LEMBUR.md](CUTI-IZIN-LEMBUR.md).
- Daftar hari lembur dimuat ulang tepat saat check-out tercatat (`LeaveTab._onAttendanceChanged`), karena tab hidup di `IndexedStack`.

## 10. Shift malam (overnight) — yang dilihat app

- Penanda `Shift.jamPulangHariBerikutnya` datang dari server lewat kalender (`#35`) dan dipakai `AttendanceRules.computePulangTarget`; bila tidak ada, app menebak `jamPulang <= jamMasuk`. Aturan target: shift biasa → jam pulang **hari ini**; shift malam → jika `jam sekarang < jam masuk` target = jam pulang hari ini (ekor shift semalam atau jeda siang), jika `>= jam masuk` target = jam pulang **besok**.
- **Server**: baris absensi dicatat pada **tanggal shift dimulai** (check-in 00:30 untuk shift 22:00 tetap baris kemarin); keterlambatan wrap-aware; `GET attendance/today` memakai `findRelevantRecord` = baris terbuka kemarin/hari ini dulu, kalau tak ada baru baris hari ini (`routes/mobile/attendance.ts:117-128`).
- **Snapshot shift**: `jamMasukShiftSnapshot`, `jamPulangShiftSnapshot`, `toleransiPulangSnapshot` dari record hari ini dihidrasi ke `AttendanceRules` (`_hydrateCheckoutSnapshot`) agar dialog "Belum Jam Pulang!" menilai terhadap shift yang berlaku saat check-in, bukan shift yang mungkin diedit admin di tengah hari.
- **Batas yang diakui kode** (komentar `computePulangTarget`): jeda siang `[jamPulang, jamMasuk)` pada shift malam ambigu — "lupa check-out berjam-jam" tak dapat dibedakan dari "check-in lebih awal untuk shift malam nanti" karena kelas hanya menyimpan jam shift statis, bukan jam check-in aktual. Dipilih jawaban konservatif.
- Pengingat pra-check-in memakai `computeNextMasukTarget` (di jeda siang menunjuk jam masuk malam ini, bukan kemarin) agar tidak ada alert "sudah telat" palsu.

### Bug terbuka (milik rekan; temuan audit 2026-11-06)

Setelah absensi shift malam **ditutup sesudah lewat tengah malam**, `GET attendance/today` tidak lagi punya baris "terbuka"; ia jatuh ke `findTodayRecord` (baris bertanggal **hari ini**) yang bisa `null`, sehingga Home bisa kembali menampilkan **"belum check-in"** padahal shift kemarin baru saja selesai (dan kartu Check-In aktif lagi). Mekanisme di atas adalah **dugaan dari pembacaan kode backend** (`findRelevantRecord`) — **perlu dicek** dengan reproduksi; perbaikannya milik rekan satu tim (backend/`/today`), tidak dikerjakan di dokumen ini.

## 11. Hari libur, `joinDate`, periode tertutup (kalender kerja)

`CalendarService.load()` → `GET hari-libur` (#35) → `WorkCalendar` + `AppCalendar.instance` (di-refresh bila tanggal berganti, `isStale`). Satu sumber untuk gerbang Home, date picker cuti/izin/lembur, dan guard pengingat. Fail-open: bila gagal dimuat, `WorkCalendar.empty` menjawab "boleh absen" dan server tetap memvalidasi. Field `hariIni`: `isLibur`, `namaLibur`, `bolehAbsen`, `alasan`, `belumMulaiBekerja`, `mulaiBekerja`, `kerjaHariLibur` (lembur hari libur disetujui) + jendela jam rencana lembur. Daftar `periodeTertutup[]`/`periodeLemburTertutup[]` memblokir pemilihan tanggal pengajuan.

## 12. Mode testing

`TestingConfig.enabled = bool.fromEnvironment('TESTING_MODE', defaultValue: false)` (`testing_config.dart:119`). Aktif hanya dengan `--dart-define=TESTING_MODE=true`: `LocationService.current()` mengembalikan koordinat kantor palsu (jarak 0 m, `isMocked: false`), jam tampil/kirim memakai skenario (`TESTING_SCENARIO`: `normal | terlambat | lembur | lemburTepatBatas | terlambatLembur`, **default `lembur`**), `time` ("HH:mm") ikut dikirim di body check-in/out, banner kuning "MODE TESTING" di Home. **Server hanya menghormati `time` bila `NODE_ENV != production`** (mobile-api bagian 3) — build produksi ke backend produksi mengabaikannya. Data uji tetap masuk DB sungguhan (bersihkan sebelum demo/penggajian). Detail & checklist: [TESTING-ABSENSI.md](../TESTING-ABSENSI.md).

## 13. Known issues

- Pemeriksaan GPS palsu hanya di Home (bagian 4); FAB tidak memeriksa.
- Dialog "Belum Jam Pulang!" dan konfirmasi hari libur hanya di FAB; kartu Home melewatinya.
- Foto opsional secara efektif bila `takePicture()` gagal (bagian 3).
- Face detection bukan verifikasi identitas/liveness.
- Bug `/today` null setelah shift malam ditutup (bagian 10; perlu dicek).
- `_checkoutAllowed`/`_checkinAllowed` di `camera_checkin_screen.dart` konstanta `true` (sisa guard jam lama) dan branch `if (_canCheckout) return _buildCheckinBlockedAfterNoon()` di status `notCheckedIn` Home tak pernah jalan (kode mati dengan nama menyesatkan "setelah jam 12").
