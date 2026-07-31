# Sprint 2 EPIC 9 — Tugas sisi Flutter (staff app)

**Dibuat:** 2026-07-31. **Sumber kebenaran untuk sisi Flutter Sprint 2 EPIC 9** — kalau ada dokumen lain yang menyebut soal ini secara sekilas (PRD web-admin, contract doc backend), file INI yang jadi rujukan detail eksekusinya.

**Cara pakai dokumen ini:** ini ditulis supaya bisa dieksekusi tuntas hanya dengan membaca file ini — gak perlu baca histori chat/keputusan lain. Semua konteks bisnis yang relevan sudah dirangkum di bawah. Kalau ada bagian yang kurang jelas saat eksekusi, lebih baik tanya balik ke pemilik project daripada menebak.

**Scope:** HANYA `hadir-in-staff-app-flutter`. Backend (`hadir-in-api-backend-express-js`) dan web-admin (`hadir-in-web-admin-react`) untuk EPIC 9 SUDAH SELESAI dikerjakan dan sudah di-deploy ke database live (schema sudah di-push, endpoint sudah jalan) — jangan sentuh 2 repo itu, cukup baca kontraknya.

---

## 1. Konteks bisnis (kenapa ini perlu dikerjakan)

Backend baru saja mengubah formula perhitungan gaji (`gajiNetto`, alias "Take Home Pay"/THP) lewat 3 perubahan:

1. **Fasilitas (benefit barang, non-tunai)** sekarang bisa kena pajak sebagian (kalau nilainya di atas batas resmi per kategori — PP 55/2022 + PMK 66/2023), TAPI **tetap tidak pernah masuk ke angka THP** — sama seperti sebelumnya, cuma alasannya sekarang lebih presisi.
2. **Tunjangan yang bentuknya "barang" (bukan uang tunai)** — field `bentuk` ini sudah ada di data sejak awal, tapi sekarang efeknya diaktifkan: tunjangan barang tetap kena pajak, TAPI **tidak ikut masuk ke angka THP** (beda dari tunjangan bentuk uang yang tetap masuk THP seperti biasa).
3. **BPJS bisa "dipotong dari staff"**, bukan cuma "ditanggung perusahaan" seperti sebelumnya. Field `potonganBPJS` yang selama ini SELALU 0, sekarang bisa berisi angka asli kalau office itu mengatur BPJS-nya dengan skema split (sebagian ditanggung perusahaan, sebagian dipotong dari gaji staff).

Formula resmi (dari backend, `payroll-calc.ts`):
```
gajiNetto (Take Home Pay) = totalPendapatan + totalTunjanganUang
```
di mana `totalPendapatan` sudah memperhitungkan pajak DAN `potonganBPJS` di dalamnya, dan `totalTunjanganUang` HANYA menjumlah tunjangan yang `bentuk`-nya `"uang"` (bukan `"barang"`).

**Masalah nyata yang ditemukan di kode Flutter existing:** `SalarySlip.takeHomePay`/`netSalary` (di `lib/models/models.dart`) TIDAK membaca `gajiNetto` dari server sama sekali — app menghitung ULANG THP sendiri di client dengan menjumlah semua komponen breakdown (termasuk item yang seharusnya TIDAK masuk THP). Ini sebabnya:
- Angka THP yang ditampilkan ke staff **BISA BEDA** dari angka yang sebenarnya ditransfer HRD.
- Setiap kali backend mengubah formula (seperti yang baru saja terjadi), app HARUS ikut diubah manual — padahal server sudah menghitung angka yang benar dan sudah mengirimkannya di response, cuma app-nya tidak memakainya.

**Fix utama di dokumen ini: ganti app supaya PERCAYA angka `gajiNetto` dari server, jangan hitung ulang sendiri.** Ini juga otomatis membereskan 1 bug lama yang sudah diketahui: field `uangMakan` yang dijumlah live oleh endpoint mobile (`routes/mobile/gaji.ts`) TIDAK pernah dijumlahkan ke `gajiNetto` resmi di backend — kalau app baca `gajiNetto` langsung dari server (bukan hitung ulang dari breakdown termasuk `uangMakan`), angka yang tampil otomatis benar, tanpa perlu fix terpisah untuk uang makan.

---

## 2. Endpoint & shape data yang relevan (sudah live, tidak perlu diubah bentuknya)

`GET /api/mobile/staff/:staffId/gaji/slip` (list) dan `GET /api/mobile/staff/:staffId/gaji/slip/:slipId` (detail) — dua-duanya SUDAH mengirim field-field ini di response JSON (tidak perlu request perubahan ke backend, field-nya sudah ada):

```jsonc
{
  // ... field lain yang sudah ada (periode, gajiPokok, bonusTepat, dst) ...

  "gajiNetto": 4200000,          // ANGKA THP RESMI -- pakai ini langsung, jangan hitung ulang
  "totalTunjangan": 800000,      // SEMUA tunjangan (uang+barang) -- taxable total, BUKAN yang masuk THP
  "totalTunjanganUang": 500000,  // BARU. Cuma tunjangan bentuk "uang" -- inilah yang sudah difaktorkan ke gajiNetto di atas
  "tunjanganBreakdown": [
    { "nama": "Transport", "jumlah": 500000, "periode": "bulanan", "bentuk": "uang" },
    { "nama": "Sepatu Kerja", "jumlah": 300000, "periode": "bulanan", "bentuk": "barang" }
  ],
  "fasilitasBreakdown": [
    { "kategori": "MakananMinuman", "periode": "harian", "nominal": 50000 }
  ],
  "totalFasilitas": 50000,        // tidak berubah bentuknya, TAPI TIDAK PERNAH masuk gajiNetto (dulu maupun sekarang)
  "potonganBPJS": 150000,         // BARU BISA NONZERO -- dulu selalu 0, field-nya sudah ada dari awal
  "totalPotongan": 950000,        // sudah termasuk potonganBPJS di dalamnya

  "uangMakan": 300000,            // TIDAK berubah -- field lama, live-summed, MASIH TIDAK termasuk di gajiNetto
  "uangMakanDays": 15
}
```

Catatan penting:
- `tunjanganBreakdown` item **SUDAH PUNYA** field `bentuk` (`"uang"` atau `"barang"`) sejak lama — Flutter yang belum pernah membacanya.
- Gak ada field yang DIHAPUS. Semua perubahan di atas ADDITIVE (field baru) atau perubahan NILAI pada field yang sudah ada (`potonganBPJS`, `gajiNetto`) — jadi parsing lama gak akan crash, cuma hasil angkanya jadi kurang akurat kalau gak di-update sesuai bagian 3 di bawah.

---

## 3. Yang harus diedit di `hadir-in-staff-app-flutter`

### 3.1. `lib/models/models.dart` — class `SalarySlip` (sekitar baris 607-791)

**A. Tambah field baru ke class + constructor + factory:**
- `final int gajiNetto;` — parse dari `gi('gajiNetto')` (helper `gi()` sudah ada di dalam `fromApi`, baca `int` dari JSON, default 0 kalau null).
- (Opsional tapi disarankan) `final int totalTunjanganUang;` — parse dari `gi('totalTunjanganUang')`, kalau mau dipakai buat validasi/debug tampilan. Tidak wajib dipakai di UI, tapi enak buat sanity-check.

**B. Ganti getter `takeHomePay` dan `netSalary` (baris ~785 & ~790) supaya baca field baru, BUKAN hitung ulang:**

Sebelum (SALAH, jangan dipakai lagi):
```dart
int get takeHomePay => gajiBersih + totalTunjangan - totalPotongan;
// ...
int get netSalary => takeHomePay;
```

Sesudah (BENAR):
```dart
/// TAKE HOME PAY = gajiNetto dari server, BUKAN hitung ulang di client.
/// Server sudah menghitung dengan formula yang benar (termasuk aturan
/// Fasilitas/Tunjangan-barang yang tidak masuk THP, dan potongan BPJS
/// staff kalau ada) -- app hanya menampilkan, tidak boleh menduplikasi
/// logika ini karena setiap backend ganti formula, app akan Salah lagi
/// kalau masih hitung manual.
int get takeHomePay => gajiNetto;
int get netSalary => gajiNetto;
```

`gajiBersih`, `pendapatanPokok`, `totalTunjangan`, `totalPotongan`, `_sum()` dkk BOLEH tetap ada (masih dipakai untuk breakdown tampilan per section — "Pendapatan Pokok", "Tunjangan", "Potongan" di UI tetap perlu daftar per-item), yang PENTING cuma angka TOTAL/HEADLINE besar (`takeHomePay`/`netSalary`) yang harus berhenti dihitung ulang dan langsung pakai `gajiNetto`.

**C. Update parsing `tunjanganBreakdown` (di dalam `fromApi`, sekitar baris 712-721) — baca field `bentuk` dan beri catatan yang jelas kalau `barang`:**

Sebelum:
```dart
final tunjanganRaw = j['tunjanganBreakdown'];
if (tunjanganRaw is List) {
  for (final item in tunjanganRaw.whereType<Map>()) {
    final nama = (item['nama'] ?? 'Tunjangan').toString();
    final jumlah = (item['jumlah'] as num?)?.toInt() ?? 0;
    final periode = (item['periode'] ?? '').toString();
    add(SalaryGroup.tunjangan, nama,
        periode == 'harian' ? 'Dibayar per hari hadir' : '', jumlah);
  }
}
```

Sesudah — tambahkan pengecekan `bentuk`, catatan beda kalau barang:
```dart
final tunjanganRaw = j['tunjanganBreakdown'];
if (tunjanganRaw is List) {
  for (final item in tunjanganRaw.whereType<Map>()) {
    final nama = (item['nama'] ?? 'Tunjangan').toString();
    final jumlah = (item['jumlah'] as num?)?.toInt() ?? 0;
    final periode = (item['periode'] ?? '').toString();
    final bentuk = (item['bentuk'] ?? 'uang').toString();
    final isBarang = bentuk == 'barang';
    final note = [
      if (periode == 'harian') 'Dibayar per hari hadir',
      if (isBarang) 'Barang — tidak termasuk Take Home Pay',
    ].join(', ');
    add(SalaryGroup.tunjangan, nama, note, jumlah);
  }
}
```
(Kalau `SalaryComponent` butuh flag boolean terpisah buat styling badge khusus di UI — misal warna beda buat item non-cash — boleh tambah field `bool isNonCash` di `SalaryComponent` dan isi dari `isBarang` di sini, plus dari Fasilitas juga (lihat 3.1.D). Ini soal preferensi tampilan, bebas dipilih implementer selama informasinya sampai ke user.)

**D. Update catatan Fasilitas (sekitar baris 723-730) — konsisten dengan tunjangan-barang, kasih catatan yang sama jelasnya:**
```dart
final fasilitasRaw = j['fasilitasBreakdown'];
if (fasilitasRaw is List) {
  for (final item in fasilitasRaw.whereType<Map>()) {
    final kategori = (item['kategori'] ?? 'Fasilitas').toString();
    final nominal = (item['nominal'] as num?)?.toInt() ?? 0;
    add(SalaryGroup.tunjangan, kategori,
        'Fasilitas — tidak termasuk Take Home Pay', nominal);
  }
}
```

**E. Uang makan (baris ~732-734) — TIDAK PERLU diubah secara fungsional**, tapi disarankan perjelas notenya biar staff gak bingung kenapa uang makan gak nambah ke total:
```dart
add(SalaryGroup.tunjangan, 'Uang Makan',
    '${gi('uangMakanDays')} hari memenuhi syarat — belum termasuk Take Home Pay',
    gi('uangMakan'));
```
(Catatan ini jujur soal batasan saat ini — uang makan memang belum diputuskan kena pajak atau tidak oleh klien, jadi belum di-wire ke `gajiNetto` backend. Kalau nanti backend sudah wire uang makan ke `gajiNetto`, note ini harus dihapus lagi — tapi karena `takeHomePay` sekarang baca `gajiNetto` server langsung, TIDAK ADA fix tambahan yang perlu dilakukan di Flutter saat itu terjadi, angkanya otomatis benar.)

**F. Potongan BPJS** — kalau ada baris terpisah untuk `potonganBPJS` di breakdown Potongan (cek `add(SalaryGroup.potongan, 'BPJS', ...)` sekitar baris 740), pastikan itu tetap merender walau nilainya sekarang bisa nonzero (jangan ada kondisi tersembunyi yang nge-skip render kalau dulu `amount == 0` dianggap "gak usah tampil").

### 3.2. `lib/screens/salary_screen.dart`

**TIDAK PERLU diubah untuk bagian THP** — semua tempat yang menampilkan Take Home Pay (`slip.takeHomePay` di baris ~782, ~991, ~1104, dan `slip.netSalary` di baris ~337, ~1690) otomatis benar begitu getter di `models.dart` diperbaiki (poin 3.1.B), karena semua titik itu cuma MEMBACA getter, tidak menghitung sendiri.

**Yang PERLU dicek (bukan wajib diubah, tergantung selera tampilan):** kalau mau menonjolkan item non-cash (tunjangan barang / fasilitas) dengan visual beda (misal badge abu-abu kecil "Non-tunai"), cari fungsi yang me-render tiap baris `SalaryComponent` di tabel Tunjangan (kemungkinan nama fungsinya `_buildSalaryTable`/`_buildSalaryRow`, cek definisi persis di file ini) dan tambahkan badge kecil kalau `note` mengandung "tidak termasuk Take Home Pay" (atau pakai field `isNonCash` kalau memilih opsi di 3.1.C). Ini polish visual, bukan correctness bug — kalau waktu terbatas, boleh diskip dulu (note text-nya sendiri sudah cukup informatif tanpa badge).

### 3.3. PDF export (kalau ada, terlihat ada kode `pw.Table`/`summaryRow` di sekitar baris 770-795 salary_screen.dart untuk cetak PDF slip)

Sama seperti 3.2 — `slip.takeHomePay`/`gajiBersih`/`totalTunjangan`/`totalPotongan` di situ juga cuma membaca getter/field yang sudah diperbaiki di 3.1, jadi otomatis ikut benar. Cek saja tidak ada angka yang di-hardcode terpisah dari model (`_fmt(slip.takeHomePay)` dkk sudah benar selama getter-nya sudah difix).

---

## 4. Yang HARUS DIVERIFIKASI setelah edit (acceptance criteria)

- [ ] `flutter analyze` bersih, `flutter test` (kalau ada test relevan) tetap hijau.
- [ ] Buka layar Slip Gaji (`salary_screen.dart`) untuk staff yang slip-nya punya Fasilitas DAN tunjangan bentuk barang — angka "Take Home Pay" yang tampil harus SAMA PERSIS dengan field `gajiNetto` di response API (cek lewat network inspector/log, bandingkan manual).
- [ ] Item tunjangan `bentuk: "barang"` dan semua item Fasilitas tetap MUNCUL di daftar breakdown (jangan disembunyikan), tapi ada catatan/indikasi jelas bahwa itu tidak termasuk Take Home Pay.
- [ ] Staff yang office-nya pakai BPJS split (potongan staff > 0): baris "Potongan BPJS" di layar tetap muncul dengan angka yang benar, tidak ke-skip.
- [ ] PDF export slip (kalau dites) angkanya konsisten dengan layar.
- [ ] Tidak ada tempat lain di codebase yang MASIH menghitung take-home-pay manual dari komponen — cari referensi lain ke `gajiBersih + totalTunjangan` atau pola serupa selain yang sudah diperbaiki di atas (grep `gajiBersih` dan `totalTunjangan` di seluruh `lib/` untuk memastikan tidak ada duplikat logika di file lain).

---

## 5. Yang TIDAK perlu dikerjakan di Flutter untuk EPIC 9 ini

- Uang makan (EPIC 5b) — keputusan pajak masih menunggu meeting klien, backend belum wire ke `gajiNetto`. Tidak ada task Flutter tambahan soal ini di luar poin 3.1.E di atas (yang notenya opsional).
- Fasilitas/BPJS batas nominal/setting — itu semua diatur HRD lewat web-admin, tidak ada UI setting terkait di app staff.
- Tidak ada perubahan endpoint/kontrak API yang perlu diminta ke backend — semua field yang dibutuhkan sudah dikirim.
