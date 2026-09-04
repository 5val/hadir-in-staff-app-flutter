# Mode Testing Absensi (lokasi & jam hardcode)

Dokumen ini menjelaskan **bagian mana yang perlu diubah** untuk berpindah antara
"sedang testing" (lokasi & jam di-hardcode) dan "data real / produksi".

Tidak ada kode asli yang dihapus. Logika GPS dan jam yang sebenarnya tetap utuh
di tempatnya; mode testing hanya **membelokkan dua sumber data** lewat satu file
konfigurasi.

---

## 1. Sakelar utama — compile-time flag, BUKAN literal di source

File: [lib/config/testing_config.dart](../lib/config/testing_config.dart)

Sejak Sprint 3 EPIC 1, `enabled` **tidak lagi** boleh diubah langsung di
source (`static const bool enabled = true;` yang ke-commit pernah bikin app
diam-diam kirim GPS & jam palsu ke backend produksi). Sekarang nilainya
dibaca dari `--dart-define` saat build/run, default-nya **selalu `false`**:

```dart
static const bool enabled = bool.fromEnvironment(
  'TESTING_MODE',
  defaultValue: false,
);
```

**Cara aktifkan mode testing (lokal, dev):**

```bash
flutter run --dart-define=TESTING_MODE=true
```

**Data real / produksi** — jalankan seperti biasa, TANPA flag apa pun:

```bash
flutter run
flutter build apk
```

Tidak ada baris kode yang perlu di-comment/di-uncomment. Saat dijalankan
tanpa `--dart-define=TESTING_MODE=true`, `enabled` selalu `false` dan seluruh
app otomatis memakai GPS asli dan jam asli perangkat — termasuk build
release, yang secara struktural tidak mungkin membawa mode testing walau
developer lupa mengubah apa pun di source.

### Sakelar per-bagian (opsional)

Berlaku hanya bila `enabled = true`:

| Konstanta | true | false |
|---|---|---|
| `fakeLocation` | Koordinat di-hardcode | GPS asli HP tetap dipakai |
| `fakeTime` | Jam check-in/out di-hardcode | Jam server/HP yang dipakai |

Contoh: mau menguji geofence asli tapi jamnya tetap dipalsukan →
`enabled = true`, `fakeLocation = false`, `fakeTime = true`.

---

## 2. Nilai yang bisa disetel saat testing

Semua di `lib/config/testing_config.dart`:

| Konstanta | Default | Fungsi |
|---|---|---|
| `useOfficeCoordinates` | `true` | Pakai koordinat kantor staff yang login → jarak 0 m, selalu lolos geofence kantor mana pun |
| `fallbackLatitude` / `fallbackLongitude` | `-6.2088` / `106.8456` | Dipakai bila `useOfficeCoordinates = false`, atau staff belum ditempatkan pada Lokasi |
| `fakeAccuracyMeters` | `5` | Akurasi GPS palsu |
| `checkInTime` | `'08:00'` | Jam yang **dikirim ke backend** saat check-in — ditentukan skenario |
| `checkOutTime` | `'17:00'` | Jam yang **dikirim ke backend** saat check-out — ditentukan skenario |
| `clockTime` | `'17:30'` | "Jam sekarang" versi testing untuk tampilan/gerbang UI — ditentukan skenario |

### Skenario absensi (`TESTING_SCENARIO`)

Jam check-in/check-out tidak lagi diubah dengan mengedit literal satu per satu.
Pilih **skenario** lewat flag CLI kedua:

```bash
flutter run --dart-define=TESTING_MODE=true --dart-define=TESTING_SCENARIO=lembur
```

Tanpa `TESTING_SCENARIO`, skenario yang dipakai adalah `normal` — persis sama
dengan perilaku sebelum skenario ada.

| Skenario | Check-in → Check-out | Hasil yang diharapkan |
|---|---|---|
| `normal` (default) | 08:00 → 17:00 | Status hadir, lembur 0 |
| `terlambat` | 09:30 → 17:00 | Terlambat 90 menit + denda, lembur 0 |
| `lembur` | 08:00 → 20:00 | **Lembur 180 menit (3 jam)**, hari itu layak diajukan lembur |
| `lemburTepatBatas` | 08:00 → 18:00 | Lembur 60 menit **tapi TIDAK layak diajukan** |
| `terlambatLembur` | 09:30 → 20:00 | Terlambat 90 menit **dan** lembur 180 menit sekaligus |

Angka lembur di atas mengasumsikan `Shift.jamPulang` staff = **17:00**; backend
menghitungnya relatif terhadap jam pulang shift staff yang bersangkutan
(`lembur = checkOut − jamPulang`), jadi kalau shift-nya berbeda, selisihnya
ikut bergeser.

**Kenapa ada `lemburTepatBatas`.** Gerbang kelayakan lembur di backend adalah
`checkOut − jamPulang > 60` menit — bukan `>=` (lihat
`isLemburEligible` di `lib/attendance-payroll.ts` pada repo backend). Skenario
ini duduk PAS di 60 menit, jadi ia harus menghasilkan lembur yang tercatat
tapi belum bisa diajukan. Kalau suatu hari gerbang itu berubah jadi `>=`,
skenario inilah yang menangkapnya.

Banner mode testing di HomeTab menampilkan nama skenario **beserta hasil yang
diharapkan**, supaya penguji tidak perlu menghitung sendiri dan langsung sadar
kalau data yang tersimpan ternyata berbeda.

### Hal lain yang berguna diuji

| Yang mau diuji | Setel |
|---|---|
| **Di luar radius** (ditolak server) | `useOfficeCoordinates = false` + koordinat jauh dari kantor |

---

## 3. Apa yang terjadi di balik layar

| Bagian | Mode testing | Mode real |
|---|---|---|
| `LocationService.current()` ([lib/services/location_service.dart](../lib/services/location_service.dart)) | Langsung mengembalikan `fakePosition()` — GPS HP tidak disentuh | Baca GPS asli + urus izin lokasi |
| `AttendanceService.checkIn/checkOut` ([lib/services/attendance_service.dart](../lib/services/attendance_service.dart)) | Menambahkan field `time` ke body request | Field `time` **tidak dikirim** → backend memakai jam server |
| `AttendanceRules.isAfterNormalCheckout` ([lib/services/attendance_provider.dart](../lib/services/attendance_provider.dart)) | Bandingkan `clockTime` dengan jam pulang shift | Bandingkan jam asli HP |
| Jam di HomeTab & layar kamera | Menampilkan `clockTime` | Menampilkan jam asli |
| Banner kuning "MODE TESTING" di Home | Muncul | Hilang sendiri |

`LocationService.current()` adalah **satu-satunya** pintu masuk lokasi di app —
home tab, layar kamera, dan FAB di `main_screen.dart` semuanya lewat sana. Karena
itu cukup dibelokkan di satu tempat.

---

## 4. Backend tidak perlu diubah

Tidak ada satu baris pun di `hadir-in-api-backend-express-js` yang perlu
di-comment:

- Endpoint `POST /api/mobile/staff/:staffId/attendance/check-in` & `check-out`
  memang **sudah** menerima field opsional `time` (format `"HH:mm"`) dan
  memakainya untuk menghitung keterlambatan/lembur. Bila tidak dikirim, server
  memakai jamnya sendiri.
- Geofence (`src/lib/geo.ts`) tetap aktif dan tetap memutuskan. Yang berubah
  hanya **koordinat yang dikirim app**, bukan aturannya — jadi pengujian tetap
  melewati jalur kode yang sama persis dengan produksi.

> Konsekuensinya: data absensi yang tercatat selama mode testing **masuk ke
> database sungguhan**. Hapus baris `attendance` hasil uji coba sebelum dipakai
> untuk demo/penggajian.

---

## 5. Checklist sebelum rilis / demo data real

1. Jalankan/build TANPA `--dart-define=TESTING_MODE=true` (default sudah
   `false` — tidak ada lagi literal di source yang perlu diubah).
2. Jalankan app, pastikan banner kuning "MODE TESTING" di halaman Home **tidak
   muncul**.
3. Pastikan `lib/config/api_config.dart` → `host` menunjuk server yang benar.
4. Bersihkan record `attendance` hasil pengujian dari database.
