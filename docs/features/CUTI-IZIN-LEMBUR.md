# Cuti, Izin/Sakit, dan Lembur

Diverifikasi terhadap kode 2026-11-06. Kontrak: [mobile-api.md bagian 5, 6, 12](../../../hadir-in-api-backend-express-js/docs/mobile-api.md) (#22–#27, #49–#51). Aturan bisnis lembur (ambang, pembulatan, hari libur, batas): [ATURAN-BISNIS-PENGGAJIAN.md §6](../../../hadir-in-web-admin-react/docs/product/ATURAN-BISNIS-PENGGAJIAN.md). Kode: `lib/screens/leave_tab.dart` (3.6k baris), `subordinate_requests_screen.dart`, `all_subordinate_leave_history_screen.dart`, `lib/services/leave_service.dart`, `overtime_service.dart`, `subordinate_service.dart`, `lib/widgets/work_date_picker.dart`, `calendar_service.dart`. Test: `leave_request_duration_test.dart`, `work_date_picker_and_drive_guard_test.dart`, `holiday_overtime_test.dart`.

Prinsip: **server menegakkan semua aturan** (jendela tanggal, `joinDate`, periode gaji tertutup, hari libur, batas lembur). App memakai kalender kerja (#35) hanya untuk memfilter pilihan di date picker dan menghitung hari kerja untuk tampilan; kalau terlewat, server menolak (400) dan pesannya ditampilkan apa adanya.

## 1. Staff mengajukan

Tab **Cuti & Izin** (`LeaveTab`), sub-tab `Cuti | Izin | Lembur | Riwayat`. Tarik-refresh di semua sub-tab memuat ulang riwayat, hari lembur, dan (bila atasan) pengajuan tim.

### 1.1 Cuti
- Hanya **cuti tahunan**: `POST /staff/:id/leave` `{tipe: "Cuti", subTipe: "Cuti Tahunan", alasan, tanggalMulai, tanggalSelesai, jumlahHari}` (#24).
- Jendela tanggal (`_cutiRange`, harus sama dengan `leaveDateWindow` backend): **besok s/d +1 bulan** (`_addMonthsClamped`).
- Sisa cuti dari profil (`AppSession.staff.sisaCuti` / `totalCuti`); tombol Kirim mati bila `jumlah hari kerja > sisa` atau alasan kosong. Hari dihitung dengan `_workingDaysBetween` = hari kerja shift minus hari libur (`AppCalendar.isSelectable`); `jumlahHari` yang dikirim **diabaikan server** (dihitung ulang di `lib/leave-days.ts`). Tidak ada lampiran untuk cuti.
- Sukses → dialog "Pengajuan cuti telah dikirim ke admin"; notifikasi office `leave_request_submitted`.

### 1.2 Izin / Sakit
- Pilihan UI: **Sakit** (→ `tipe: "Sakit"`), **Seminar**, **Lainnya** (→ `tipe: "Izin"`, `subTipe` = pilihan). Server memetakan `Izin` ke enum DB `Ijin`. Tipe `Dinas` didukung server tetapi **tidak ada di UI**.
- Jendela tanggal (`_izinRange`): **−1 bulan s/d kemarin** (izin dicatat setelah kejadian). Dinas (server) bebas.
- **Lampiran foto**: kamera atau galeri (`image_picker`, `imageQuality: 75`, `maxWidth: 1600`), **maks 3** (`LeaveService.maxLampiran`, sama dengan `MAX_LAMPIRAN` backend). Dikirim sebagai `lampiran: [{base64, mimeType}]`; server menyimpan ke Google Drive dan URL-nya masuk `dokumen` yang dilihat admin. **Lampiran opsional di app** — `_canSubmit` hanya butuh jenis, rentang valid, dan alasan; foto tidak diwajibkan, untuk jenis apa pun termasuk Sakit.
- Foto tidak terbaca (`FileSystemException`) → snackbar "Foto tidak bisa dibaca. Hapus lalu pilih ulang."

### 1.3 Penolakan server yang umum (ditampilkan apa adanya sebagai snackbar)
Field wajib, tanggal selesai < mulai, di luar jendela, sebelum `joinDate`, **periode gaji sudah ditutup**, tanggal mulai/selesai jatuh di **hari libur** atau bukan hari kerja shift, lampiran > 3. Date picker (`showWorkDatePicker`, `work_date_picker.dart`) sudah menonaktifkan hari libur, bukan hari kerja, periode tertutup, dan sebelum `joinDate` (`isSelectableForSubmission`); `WorkCalendar.hasSelectableForSubmission` menggerbangi tombol bila seluruh rentang tertutup.

### 1.4 Riwayat
Sub-tab **Riwayat**: kartu "Riwayat Pengajuanmu" (cuti/izin) dan "Riwayat Pengajuan Lembur", filter jenis (Cuti/Sakit/Seminar/…) dan status via "Lihat Semua". Status: `pending` / `approved` / `rejected`. Untuk **lembur** yang ditolak, `alasanTolak` ditampilkan ("Alasan ditolak: …", `leave_tab.dart:1634`); untuk cuti/izin, `LeaveRequest.adminNote` ditampilkan sebagai "Alasan Ditolak" di detail pengajuan yang ditolak (`leave_tab.dart:2975`). Data: `GET /leave` (#22), `GET /lembur` (#26).

## 2. Lembur

### 2.1 Lembur hari biasa (diajukan SESUDAH check-out)
- Daftar hari: `GET /staff/:id/lembur/eligible-days` (#25). **Server menentukan** seluruh kelayakan (`bisaDiajukan`, `alasanTidakBisa`, `sudahDiajukan`, `statusPengajuan`); app tidak menghitung ulang H-3/hari libur/tutup gaji. Hari yang lembur-nya < 1 jam tidak dikirim server sama sekali.
- Kartu hari menampilkan check-in/out, jam pulang shift, "Kelebihan" (menit mentah `menitLewatJamPulang`), dan "Diajukan" = `jamLembur` (jam terbayar final dari server: ambang 60 menit, bulat ke bawah per jam, dipotong batas) dipotong sekali lagi ke `batasLemburJam` sebagai jaring pengaman.
- **Staff tidak mengetik durasi** (sejak 2026-09-05). Dialog "Ajukan Lembur" hanya meminta **alasan**; `jamMulai` = jam pulang shift (snapshot saat check-in) dan `jamSelesai` = `jamMulai + durasi terbayar`. `POST /staff/:id/lembur` `{tanggal, jamMulai, jamSelesai, alasan}` (#27).
- Batas: `min(Jabatan.maxExtraHour, 4)` jam/hari (`maxExtraHour = 0` → 4). Server menolak "Melebihi batas lembur legal 4 jam/hari" / batas jabatan. Batas 18 jam/minggu **tidak** ditegakkan (keputusan produk).
- Daftar dimuat ulang tepat saat check-out tercatat (`_onAttendanceChanged`) karena tab hidup di `IndexedStack`.

### 2.2 Lembur hari libur (diajukan SEBELUM harinya)
Kartu "Lembur di Hari Libur" → dialog `_HolidayOvertimeDialog` (pilih hari libur mendatang tanpa pengajuan aktif, jam mulai/selesai **rencana**, alasan) → `POST lembur`. Hari libur di **periode lembur tertutup** tidak ditawarkan (kartu menjelaskan alasan merah). Setelah **disetujui**, check-in di hari itu dibuka (Home & FAB, dengan dialog konfirmasi di FAB), **semua jam kerja = lembur**, tanpa batas 4 jam, tanpa uang makan/tunjangan harian. Jam final baru diketahui setelah check-out.

### 2.3 Status lembur
`pending` → `approved` / `rejected` (+ `alasanTolak`, termasuk penolakan sistem "Tidak diproses: gaji periode ini sudah dihitung"). Notifikasi `lembur_*` → tab Cuti & Izin.

## 3. Alur persetujuan atasan

Siapa yang melihatnya: hanya staff dengan `isApprover == true` dari `GET /staff/:id/subordinates/requests` (#49) — wewenang dari `AuthorityGrant` Manager/Supervisor lokasi (lihat [ROLE-MATRIX.md](ROLE-MATRIX.md), [authorization.md](../../../hadir-in-api-backend-express-js/docs/authorization.md)).

| Langkah | Layar / kode | Endpoint |
|---------|--------------|----------|
| Muat pengajuan pending | `LeaveTab` (badge di tombol "See My Team" = jumlah `leave` pending) | `GET .../subordinates/requests?status=pending` (#49) → `{isApprover, canApproveLembur, leave[], lembur[]}` |
| Buka daftar | tombol "See My Team" → `SubordinateRequestsScreen` ("Pengajuan Karyawan") | — |
| Setujui / Tolak cuti-izin | tombol di kartu → dialog konfirmasi "Setujui/Tolak pengajuan dari <nama>?" | `PATCH .../subordinates/leave/:id` `{action: "approve"\|"reject"}` (#50) |
| Riwayat tim | ikon riwayat → `AllSubordinateLeaveHistoryScreen` (filter jenis/status) | `GET ...?status=all` |

Aturan server (#50): Manager **atau** Supervisor di lokasi staff boleh memproses cuti/izin; tidak boleh memproses pengajuan sendiri (403 `Anda tidak bisa memproses pengajuan sendiri`) atau di luar lokasi yang diwenangi (403). Setujui memotong sisa cuti dan memicu notifikasi ke staff (fungsi approval yang sama dengan portal web).

**Yang TIDAK ada di UI app:**
- **Tolak tanpa alasan.** `SubordinateService.respondLeave` mendukung `alasanTolak`, tetapi dialog tidak punya kolom input.
- **Persetujuan lembur.** `SubordinateService.respondLembur` ada (hanya `action`) tetapi tidak dipanggil layar mana pun; field `lembur[]` dan flag `canApproveLembur` pada respons #49 tidak dipakai. Di server lembur hanya boleh **Manager** (Supervisor 403 `Hanya Manager yang berwenang menyetujui/menolak lembur`). Konsekuensi: perubahan backend 2026-11-06 (reject lembur menyimpan `alasanTolak`, mobile-api #51) tidak berdampak ke app — persetujuan lembur dilakukan di portal web.

## 4. RENCANA (belum di kode)

- **Lampiran bukti izin/sakit dapat dikonfigurasi per jenis** (Sakit/Izin/Dinas/Cuti: Tidak perlu / Opsional / Wajib, plus "wajib jika > N hari") oleh admin; validasi di backend, app mengikuti (keputusan 2026-11-06, [ATURAN-BISNIS §10.4](../../../hadir-in-web-admin-react/docs/product/ATURAN-BISNIS-PENGGAJIAN.md)). **Sekarang:** `lampiran[]` maks 3, tidak pernah wajib (mobile-api #24: "Rencana: setting wajib/opsional per jenis (belum ada)"). Dampak ke app nanti: UI Izin harus membaca setting (endpoint belum ada — **perlu kontrak backend baru**; flutter-dev tidak boleh menebak shapenya) dan menandai foto wajib.
- Persetujuan lembur oleh Manager di app: belum direncanakan di dokumen yang ditemukan (**perlu dicek**).

## 5. Known issues

- Tolak cuti/izin bawahan tanpa kolom alasan; persetujuan lembur tidak punya UI (bagian 3).
- Lampiran tak pernah wajib di app (sesuai server saat ini).
- `_buildEmployeeTab()` di `leave_tab.dart` adalah kode mati (versi lama "Pengajuan Karyawan" sebagai sub-tab); `AllLeaveHistoryScreen` yatim.
- Nama `_isSupervisor` di `leave_tab.dart:46` sebenarnya `isApprover`.
- Tidak ada UI pembatalan pengajuan oleh staff (tidak ada endpoint mobile untuk itu di mobile-api).
