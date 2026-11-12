# Slip Gaji — Sisi App Staff

Dokumen ini hanya menjelaskan **apa yang app lakukan** terhadap slip gaji. Aturan bisnis kanonik (state machine, rumus, tutup periode, lembur, PPh21, siapa boleh apa) ada di [ATURAN-BISNIS-PENGGAJIAN.md](../../../hadir-in-web-admin-react/docs/product/ATURAN-BISNIS-PENGGAJIAN.md) — jangan menduplikasinya di sini. Kontrak endpoint: [mobile-api.md bagian 7](../../../hadir-in-api-backend-express-js/docs/mobile-api.md) (#28–#34) dan `docs/api-contracts/sprint3.md`. Diverifikasi terhadap kode 2026-11-06.

Kode utama: `lib/screens/salary_screen.dart` (daftar `SalaryScreen`, detail `SalaryDetailScreen`, dialog), `lib/services/salary_service.dart`, `lib/models/models.dart` (`SalarySlip`, `SalaryComponent`), `lib/models/slip_filter.dart`, `lib/services/slip_deep_link.dart`, `lib/services/slip_drive_sync.dart`, `lib/screens/slip_bukti_screen.dart`. Test: `test/salary_slip_test.dart`, `slip_followup_test.dart`, `slip_and_rekening_screens_test.dart`.

## 1. Prinsip

1. **Server memutuskan status dan izin.** App membaca flag per slip dari respons (`bisaUnduh`, `bisaTolak`, `perluAksi`, `bisaBatalSetuju`, `adaBuktiBayar`, `buktiGabungan`) dan tidak menebak. Fallback turunan di `SalarySlip` (mis. `bisaBatalSetujuEfektif`) hanya untuk server lama.
2. **Take Home Pay = `gajiNetto` dari server**, tidak pernah dihitung ulang di client (`SalarySlip.takeHomePay`/`netSalary` → `gajiNetto`, `models.dart:1450,1462`). Kartu hero di detail menampilkan "Take Home Pay" = angka ini (`salary_screen.dart` `_buildHeroCard`).
3. **Versi yang dilihat staff dikunci.** Konfirmasi, Tolak, dan Batalkan persetujuan mengirim `dikirimKonfirmasiAt` (nilai dari slip yang sedang dilihat); bila HR memperbarui/menarik slip, server menjawab **409** dan app tidak mengubah status lokal.
4. Slip `draft` / `cancelled` **tidak terlihat** di app (server menyaringnya) — kecuali `draft` yang dikembalikan HR setelah staff menolak: `statusSlip == 'draft'` dari server hanya dikirim bila pernah ditolak, dan app memperlakukannya sebagai "sedang direvisi" (`SalarySlip.sedangDirevisi`).

## 2. Daftar slip (tab Gaji)

- Muat: `GET /staff/:id/gaji/slip?limit=500` (`SalaryService.mySlips`, `maxSlipLimit = 500`; default server 200 akan memotong "Semua periode"). Tarik-refresh = muat ulang senyap.
- **Filter periode** (`SlipFilter`): chip "Semua periode" + satu chip per slip bertipe periode **saat ini** (Harian/Mingguan/Bulanan; tipe saat ini = `Jabatan.periodeGaji` dari profil bila valid, kalau tidak slip terbaru). Slip bertipe periode lama (jabatan pernah pindah tipe) hanya terjangkau lewat "Semua periode". Periode terpilih yang hilang setelah muat ulang kembali ke "Semua". Urutan: awal periode terbaru dulu. Fungsi `filterSlipsByMonths` ada di file yang sama tetapi **tidak dipakai** siapa pun.
- **Kartu slip**: label periode, THP, chip status (lihat bagian 3). Slip `perluAksi` (menunggu konfirmasi) tampil menonjol: chip berkedip 3×, ikon lonceng, dan kartu berdenyut sekali per slip per sesi app (`AttentionPulse`, `_pulsedIds`; mati bila OS `disableAnimations`).
- **Auto-simpan Drive**: setiap muat daftar memanggil `SlipDriveSync.autoSyncLocked(list)` (lihat bagian 8).
- **Deep-link**: ketuk notifikasi slip → `SlipDeepLink.request(slipId)` → `SalaryScreen` memuat ulang senyap lalu membuka `SalaryDetailScreen` slip itu; id tak ditemukan → tinggal di daftar. Permintaan yang menggantung dibuang bila muat gagal.

## 3. Status yang ditampilkan ke staff

Label dari `SalarySlip.statusLabel` (`models.dart:1312`); urutan prioritas dari atas:

| Kondisi slip | Label kartu | Banner detail (`_buildStatusBanner` / `_buildPencairanBanner`) | Tombol di detail |
|--------------|-------------|------|------------------|
| `statusBayar == paid` | **Sudah dicairkan** | banner hijau "Sudah dicairkan" + waktu (`paidAt`) + "Dicairkan oleh" (`paidOleh`) | **Lihat bukti pembayaran** bila `adaBuktiBayar`; bila `buktiGabungan` hanya catatan "Bukti transfer gabungan disimpan oleh HR". Plus tombol unduh bila terkunci |
| `menunggu_konfirmasi` | **Perlu konfirmasi Anda** | biru "Mohon periksa slip ini" (atau hijau "Slip sudah direvisi HR" + daftar revisi bila `pernahDitolak`) | bar bawah: **Ada yang salah** (hanya bila `bisaTolak`) + **Konfirmasi, sudah benar** |
| `ditolak` atau `draft` | **Anda menolak — menunggu perbaikan HR** | merah "Anda menolak slip ini" (+ "HR sedang merevisi" bila `draft`) + `Alasan Anda: …` | tidak ada tombol |
| `terkunci`/`dikonfirmasi` + `siapDicairkanAt` terisi (`sedangDiprosesPencairan`) | **Sedang diproses pencairan** | kuning "Sedang diproses pencairan" | hanya unduh |
| `terkunci` / `dikonfirmasi` | **Disetujui** | hijau "Anda menyetujui slip ini — Slip sudah terkunci dan bisa diunduh" (hanya bila `bisaUnduh`) | **Unduh PDF**, **Simpan ke Google Drive**; kartu "Batalkan persetujuan" bila `bisaBatalSetujuEfektif` |

Ikon bantuan "Tahapan status slip gaji" di header detail menjelaskan urutan status (`key: slip-status-help`).

## 4. Konfirmasi ("Konfirmasi, sudah benar")

`POST .../konfirmasi` body `{dikirimKonfirmasiAt?}` (#31). Dialog konfirmasi lokal dulu ("Dengan mengonfirmasi, Anda menyatakan angka di slip … sudah benar"). Server mengubah `menunggu_konfirmasi` → **`terkunci` langsung** (bukan `dikonfirmasi`); app memakai `statusSlip`/`bisaUnduh` dari respons (`KonfirmasiResult.applyTo`), bukan hardcode. Bila `bisaUnduh` → snackbar "Slip dikonfirmasi dan sudah final", lalu simpan ke Drive di latar (diam bila akun Google belum tersambung). Respons lama tanpa `statusSlip` dianggap `dikonfirmasi` ("Menunggu HR mengunci slip") — jalur kompatibilitas.

## 5. Tolak ("Ada yang salah")

Dialog `_TolakSlipDialog` ("Apa yang salah?"):

- Daftar centang **hanya** bagian yang bisa ditindaklanjuti HR (`_tolakItems`): **Gaji Pokok** (`col:gajiPokok`), **Lembur** (`col:lemburTotal`), tiap **Tunjangan** (`tunjangan:<nama>`), tiap **Fasilitas** (`fasilitas:<kategori>`), dikelompokkan "Pendapatan Pokok / Tunjangan / Fasilitas". Bonus, THR, uang makan, pajak, potongan, kehadiran, dan THP **tidak bisa** ditolak.
- Kolom catatan (maks 300 karakter di UI; `alasan` server 5–500).
- `SalaryService.susunAlasanTolak` menyusun satu string: `Bagian yang salah: <label; label>. Catatan: <teks>` (dipotong ke 500).
- Body: `{alasan, dikirimKonfirmasiAt?, bagian?}` — `bagian` **hanya disertakan bila tidak kosong** (`SalaryService.tolakBody`).
- Setelah sukses: lokal `statusSlip: ditolak`, `bisaTolak: false`, `bagianTolak` terisi; snackbar "Slip ditolak. HR akan memeriksa dan merevisinya."
- **Tolak hanya sekali** per slip (`tolakDipakaiAt`; batal-setuju tidak memakainya, lihat bagian 6). Setelah HR memperbaiki dan mengirim ulang, tombol "Ada yang salah" hilang (`bisaTolak` false) dan staff hanya bisa Setujui. Bagian yang ditolak ditandai ikon ⓘ **merah**, bagian yang direvisi HR ⓘ **hijau** (ketuk untuk detail; daftar "Slip sudah direvisi HR" merangkum semua perubahan).

### R9 (diperbaiki 2026-11-08): kirim Tolak wajib centang + catatan

`_TolakSlipDialogState._valid` = `_checked.isNotEmpty && catatan.trim().length >= 5`: tombol **Kirim ke HR** hanya aktif bila **minimal satu bagian dicentang DAN catatan >= 5 karakter**; tanpa centang tampil helper "Centang minimal satu bagian yang salah." `SalaryService.tolakBody` selalu mengirim `bagian`. Alasan: server mewajibkan `bagian` minimal 1 sejak 2026-10-25 (`slipTolakSchema`, [sprint3.md "Penggajian follow-up 2026-10-25" #1](../../../hadir-in-api-backend-express-js/docs/api-contracts/sprint3.md)), request tanpa centang dulu berakhir 400. Test: `slip_and_rekening_screens_test.dart` (grup "tolak dialog" dan "reject dialog").

## 6. Batalkan persetujuan (BIZ-A05, 2026-11-12)

Kartu "Ada yang keliru? Selama kantor belum menyetujui pencairan, Anda bisa membatalkan persetujuan" + tombol **Batalkan persetujuan**, tampil bila `bisaBatalSetujuEfektif` (server: `terkunci`/`dikonfirmasi`, `unpaid`, belum Setujui Cair).

`BatalSetujuDialog(items: _tolakItems())`: staff **wajib mencentang minimal satu bagian** yang salah (daftar centang SAMA dengan dialog Tolak, widget bersama `SlipBagianChecklist` + `TolakItem`) **dan** menulis alasan **5-300 karakter** (UTF-16 sama dengan `.length` JS server; `Utf16LengthLimitingFormatter`). Tombol aktif hanya bila keduanya terpenuhi; tanpa centang tampil helper "Centang minimal satu bagian yang salah." Salinan dialog menjelaskan bahwa bagian yang dicentang adalah yang akan diperbaiki HR dan bahwa membatalkan persetujuan **tidak menghabiskan jatah "Ada yang salah"**. Boleh diulang berkali-kali (server mengizinkan sampai Setujui Cair), tanpa batas di client.

`POST .../batal-setuju` `{alasan, bagian: string[] (wajib, key sama dengan Tolak), dikirimKonfirmasiAt?}` (#34); tanpa `bagian` server 400 (`SalaryService.batalSetujuBody` selalu mengirimnya). Sukses: `SalaryService.batalSetuju` mengembalikan slip dari respons server (`SalarySlip?`, null bila respons kosong) dan layar memakainya; fallback lokal: `ditolak`, alasan `Persetujuan dibatalkan staff: <alasan>`, `bagianTolak` = centang, `ditolakAt` = sekarang, `bisaUnduh/bisaBatalSetuju/bisaTolak` false (status `ditolak`, belum menunggu konfirmasi), `tolakDipakaiAt` TIDAK disentuh. **409** (mis. "sudah disetujui untuk dicairkan") → pesan server apa adanya, layar tetap terbuka, slip disegarkan (`_refreshSlip`) agar tombol hilang.

**Jatah Tolak vs `ditolakAt`:** server punya dua kolom. `tolakDipakaiAt` = jatah Tolak sekali terpakai (hanya diisi Tolak sungguhan); `bisaTolak = menunggu_konfirmasi && !tolakDipakaiAt`. `ditolakAt` terisi juga oleh batal-setuju dan hanya menjadi jangkar diff revisi (`SlipLineRevision.sinceRejection`) / penanda `pernahDitolak`. Jadi setelah batal-setuju lalu HR mengirim ulang, tombol "Ada yang salah" MUNCUL lagi (satu kali) dan banner "Slip sudah direvisi HR" menyebutnya. Fallback model bila server lama tidak mengirim `bisaTolak` memakai `tolakDipakaiAt`, bukan `ditolakAt`.

## 7. Komponen slip, Fasilitas, "Di luar THP"

`SalarySlip.fromApi` (`models.dart:~1022-1100`) merakit komponen ke kelompok: **Pendapatan Pokok** (gaji pokok, bonus, lembur, THR), **Pajak** (PPh 21), **Tunjangan**, **Fasilitas**, **Potongan** (denda terlambat, alpha, BPJS staff, dll.).

- **Fasilitas** (`fasilitasBreakdown`, natura) adalah **bagian sendiri** di detail, di bawah Tunjangan (keputusan meeting 2026-11-05; test `slip_and_rekening_screens_test.dart`). Tidak ada Fasilitas → bagian tidak muncul. Selalu `excludedFromThp`.
- **Badge "Di luar THP"** (`_tdNote`) pada komponen yang tampil tetapi tidak menambah THP: Fasilitas, dan tunjangan `bentuk: "barang"` (catatan "Berbentuk barang").
- **Uang makan SUDAH masuk THP** (backend men-wire-nya ke `gajiNetto` sejak 2026-08-03; PMK 66/2023 — `col:uangMakan` tidak diberi badge). Dokumen lama (CLAUDE.md versi sebelumnya, arsip EPIC 9) yang berkata sebaliknya sudah basi.
- Tunjangan `periode == harian` diberi catatan "Dibayar per hari hadir". Identitas yang berlaku: `pendapatanPokok − totalDeduction + totalTunjanganUang == gajiNetto`.
- Kartu info kehadiran di atas rincian menampilkan statistik kehadiran periode (dari server).

## 8. Unduh PDF, Google Drive, bukti pembayaran

- **Unduh PDF**: hanya bila `bisaUnduh` (server: `terkunci`). `GET .../pdf` (#30) → `Printing.sharePdf(filename: Slip-Gaji-<periodeKey>.pdf)`. Selain `terkunci` server membalas 403 dan app tidak menawarkan tombol.
- **Simpan ke Google Drive** (`SlipDriveSync`): PDF dari server diunggah ke Drive **pribadi staff** (folder "Hadir-In - Slip Gaji", scope `drive.file`). Id slip yang sudah tersimpan dicatat di `SharedPreferences` (`slip_drive_saved_ids`) agar tidak diunggah ulang; `claimUpload/releaseUpload` mencegah unggah ganda bersamaan. **Otomatis** (`autoSyncLocked`, dari daftar dan setelah konfirmasi) tidak pernah memunculkan dialog login Google — bila belum ada sesi Google ia diam; **manual** (tombol, `interactive: true`) boleh login. Kegagalan otomatis ditelan.
- **Bukti pembayaran** (`SlipBuktiScreen`, `GET .../bukti` #33): tombol **Lihat bukti pembayaran** hanya bila `sudahDicairkan && !buktiGabungan && adaBuktiBayar`. Server membalas biner (jpg/png/webp/heic/pdf); `BuktiFile.isPdf` memakai content-type server, jatuh ke deteksi `%PDF` di 1024 byte pertama. 404 `Bukti pembayaran tidak tersedia` / `Bukti transfer gabungan disimpan oleh HR` ditampilkan apa adanya. `buktiBayarUrl` tidak pernah dikirim ke app (diakses lewat endpoint ber-auth).

## 9. Penanganan 409 dan error

| Situasi | Perilaku |
|---------|----------|
| Konfirmasi/Tolak → 409 (versi basi / tidak menunggu / sudah pernah ditolak) | snackbar pesan server; `_reloadIfStale` menutup layar detail (`maybePop`) sehingga daftar memuat ulang; status lokal tidak diubah |
| Batal-setuju → 409 | snackbar pesan server; layar tetap; `_refreshSlip` (`GET .../slip/:id`) |
| 400 Tolak tanpa bagian | tidak lagi bisa dari UI (tombol mati tanpa centang); bila terjadi tetap snackbar pesan server |
| Jaringan/401 | pesan dari `ApiClient` (`Sesi berakhir…` untuk 401, dll.) |

## 10. Notifikasi slip

Semua `rawType` berawalan `slip_`, `gaji_`, `pencairan_` membuka tab Gaji dan (bila `metadata.slipId`/data push `slipId` ada) detail slipnya. Tipe yang diberi petunjuk menu eksplisit: `gaji_slip_tersedia`, `slip_konfirmasi_diminta`, `slip_terkunci`, `gaji_dicairkan` ("Gaji > Slip Gaji"). Sumber event → penerima: ATURAN-BISNIS §9. Arsitektur: [NOTIFICATION-SYSTEM.md](../NOTIFICATION-SYSTEM.md).

## 11. Known issues (ringkas)

- Komentar di build `SalaryDetailScreen` ("Take Home Pay = Gaji Bersih + Tunjangan - Potongan") basi; angka THP = `gajiNetto` server.
- `filterSlipsByMonths` dead code.
- Dialog "Ganti rekening gaji?" kini menyebut (F8) bahwa slip yang sudah disetujui cair tetapi belum dibayar dibatalkan persetujuan cairnya (`rekeningReplaceWarning`; server: `rekening.ts` A9 `revokeSiapCairForStaff`, hanya bila bank/nomor/nama pemilik berubah).
