# Mode Testing Absensi (lokasi & jam hardcode)

Dokumen ini menjelaskan **bagian mana yang perlu diubah** untuk berpindah antara
"sedang testing" (lokasi & jam di-hardcode) dan "data real / produksi".

Tidak ada kode asli yang dihapus. Logika GPS dan jam yang sebenarnya tetap utuh
di tempatnya; mode testing hanya **membelokkan dua sumber data** lewat satu file
konfigurasi.

---

## 1. Sakelar utama — satu baris

File: [lib/config/testing_config.dart](../lib/config/testing_config.dart)

```dart
// MODE TESTING (lokasi & jam hardcode)
static const bool enabled = true;

// DATA REAL / PRODUKSI (GPS asli + jam asli HP)
static const bool enabled = false;
```

**Itu saja.** Tidak ada baris lain di file mana pun yang perlu di-comment atau
di-uncomment. Saat `enabled = false`, seluruh app otomatis kembali memakai GPS
asli dan jam asli perangkat.

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
| `checkInTime` | `'08:00'` | Jam yang **dikirim ke backend** saat check-in |
| `checkOutTime` | `'17:00'` | Jam yang **dikirim ke backend** saat check-out |
| `clockTime` | `'17:30'` | "Jam sekarang" versi testing untuk tampilan/gerbang UI |

### Skenario uji yang berguna

| Yang mau diuji | Setel |
|---|---|
| Hadir tepat waktu | `checkInTime = '08:00'` (≤ `Shift.jamMasuk` + toleransi) |
| Status **terlambat** + denda | `checkInTime = '09:30'` |
| Pulang normal | `checkOutTime = '17:00'` |
| **Lembur** 2 jam | `checkOutTime = '19:00'` |
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

1. `lib/config/testing_config.dart` → `enabled = false`.
2. Jalankan app, pastikan banner kuning "MODE TESTING" di halaman Home **tidak
   muncul**.
3. Pastikan `lib/config/api_config.dart` → `host` menunjuk server yang benar.
4. Bersihkan record `attendance` hasil pengujian dari database.
