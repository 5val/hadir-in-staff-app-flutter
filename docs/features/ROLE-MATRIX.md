# Matriks Peran di App Staff

Diverifikasi terhadap kode 2026-11-06. Matriks peran seluruh sistem (Admin, Manager, Supervisor, Staff, rencana Direktur) milik backend: [authorization.md](../../../hadir-in-api-backend-express-js/docs/authorization.md). Dokumen ini hanya menjawab "apa yang **app Flutter** bedakan antar peran".

## Ringkasan

App tidak punya login per-peran. Semua orang masuk lewat endpoint yang sama (nomor HP + passcode/OTP) dan mendapat JWT bertipe `staff`. Perbedaan perilaku hanya datang dari **dua sinyal**:

| Sinyal | Sumber | Efek di app |
|--------|--------|-------------|
| `isApprover` (bool) | `GET /staff/:id/subordinates/requests` (#49) — server memeriksa `AuthorityGrant` (Manager/Supervisor lokasi) | memunculkan tombol **"See My Team"** di header tab Cuti & Izin dan badge jumlah pending (`leave_tab.dart:46,309`) |
| `Jabatan.isSupervisor` (bool) | profil `jabatan.isSupervisor` → `UserRole.supervisor` (`models.dart:2170,2302`) | hanya mengaktifkan toggle "Diri Sendiri / Tim" di layar Notifikasi (`notification_screen.dart:35`) — dan sisi "Tim" selalu kosong |

Penting: `Jabatan.isSupervisor` (atribut jabatan) **bukan** wewenang persetujuan. Wewenang persetujuan hanya `AuthorityGrant`, yang tercermin di `isApprover`. Keduanya bisa berbeda untuk satu orang.

## Matriks kemampuan

| Kemampuan di app | Staff biasa | Atasan (`isApprover` = true; Manager atau Supervisor lokasi) | `UserRole.admin` |
|------------------|:-----------:|:------------------------------------------------------------:|:----------------:|
| Absensi (check-in/out, istirahat), riwayat kehadiran | ya | ya | — |
| Ajukan cuti / izin / sakit / lembur sendiri | ya | ya | — |
| Lihat & konfirmasi/tolak/batalkan slip gaji sendiri | ya | ya | — |
| Dokumen onboarding, rekening, ganti nomor HP, passcode | ya | ya | — |
| Tombol "See My Team" → setujui/tolak **cuti & izin** bawahan | tidak | **ya** (Manager *dan* Supervisor, per server) | — |
| Riwayat pengajuan bawahan (`status=all`) | tidak | ya | — |
| Setujui/tolak **lembur** bawahan | tidak | **server: hanya Manager; app: tidak ada UI** | — |
| Tab "Tim" (`AdminDashboardTab`) | tidak | tidak | **tidak pernah tampil** |

### Detail persetujuan atasan (apa yang benar-benar ada di UI)

- Layar: `SubordinateRequestsScreen` (daftar pending, tombol **Setujui** / **Tolak**, dialog konfirmasi) dan `AllSubordinateLeaveHistoryScreen` (riwayat). Hanya memuat `data.leave` — field `lembur` pada respons #49 diabaikan.
- Endpoint: `PATCH /staff/:id/subordinates/leave/:leaveId` `{action: "approve"|"reject"}` (#50). Server menolak pengajuan sendiri (403 `Anda tidak bisa memproses pengajuan sendiri`) dan pengajuan di luar lokasi yang diwenangi (403).
- **Tolak tanpa alasan**: dialog hanya meminta konfirmasi Ya/Batal; `alasanTolak` didukung `SubordinateService.respondLeave` tetapi tidak ada kolom input di UI, jadi staff yang ditolak tidak mendapat alasan dari jalur app ini.
- **Lembur bawahan tidak punya UI.** `SubordinateService.respondLembur` (`subordinate_service.dart:134`) ada, tetapi tidak dipanggil dari layar mana pun; `SubordinateRequests.canApproveLembur` dibaca dari server tetapi tidak dipakai. Konsekuensinya, perubahan backend 2026-11-06 ("reject lembur bawahan sekarang menyimpan `alasanTolak`", mobile-api #51) **tidak berdampak ke app ini**: app tidak pernah mengirim `alasanTolak` untuk lembur. Persetujuan lembur dilakukan lewat portal web.
- Pemuatan: `SubordinateService.load()` dipanggil `LeaveTab` saat dibuat dan saat tarik-refresh; `isApprover=false` untuk staff tanpa grant (server membalas 200 kosong, bukan error).

## `UserRole.admin` — tidak terpakai

`enum UserRole { staff, supervisor, admin }` (`models.dart:262`). `StaffProfile.toUserProfile()` hanya menghasilkan `supervisor` atau `staff` (`models.dart:2302`); tidak ada kode yang memetakan respons API ke `admin`. `AppSession.isAdmin` (`models.dart:14`) hanya bisa true pada data `SampleData` (mock, user `admin` / `ADM-2024-001`), yang tidak pernah dipakai sebagai `currentUser` setelah login nyata. Akibatnya:

- `MainScreen._isAdmin` selalu false → `_buildAdminLayout()`, `AdminDashboardTab`, dan label bottom-nav "Tim" tidak pernah tampil.
- `AdminDashboardTab` (`manager_dashboard_tab.dart`) membaca `SampleData.allUsers` — data karangan. Jangan jadikan acuan perilaku.
- Cabang `user.role != UserRole.admin` di `account_tab.dart` selalu true (menu Riwayat Gaji, kartu Sisa Cuti selalu tampil).

Pelaku yang "mengelola" (Admin/HRD, Manager sebagai pengelola) bekerja di **portal web**, bukan app ini. Atasan di app = staff biasa + `AuthorityGrant`.

## RENCANA (belum di kode)

- **Direktur** (disetujui 2026-11-06, [authorization.md](../../../hadir-in-api-backend-express-js/docs/authorization.md)): peran baru untuk Setujui Cair slip. **Web-only** — tidak ada perubahan di app staff yang direncanakan; Direktur yang juga staff tetap memakai app sebagai staff biasa. Jangan menambah peran Direktur di app tanpa keputusan baru.
- Persetujuan lembur oleh Manager di app: belum direncanakan di dokumen mana pun yang saya temukan (**perlu dicek** dengan pemilik produk bila diinginkan).

## Known issues

- Tab "Tim" mock + cabang `UserRole.admin` adalah kode mati; menyesatkan saat membaca.
- Persetujuan lembur atasan tidak punya UI (service sudah ada).
- Tolak cuti/izin bawahan tanpa kolom alasan.
- Toggle "Diri Sendiri / Tim" di Notifikasi untuk `Jabatan.isSupervisor` selalu menampilkan sisi Tim kosong (`AppNotification.isTeam` tidak pernah true dari API, `models.dart:1534`).
- Nama `_isSupervisor` di `leave_tab.dart:46` sebenarnya berarti `isApprover` (menyesatkan).
