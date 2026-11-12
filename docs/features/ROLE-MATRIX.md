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
| Setujui/tolak **lembur** bawahan | tidak | **ya, hanya Manager** (UI di `SubordinateRequestsScreen` bila `canApproveLembur`; Supervisor 403 dari server) | — |
| Tab "Tim" (`AdminDashboardTab`) | tidak | tidak | **tidak pernah tampil** |

### Detail persetujuan atasan (apa yang benar-benar ada di UI)

- Layar: `SubordinateRequestsScreen` (daftar pending cuti/izin + bagian "Pengajuan Lembur" bila `canApproveLembur`, tombol **Setujui** / **Tolak**, dialog konfirmasi dengan alasan tolak opsional) dan `AllSubordinateLeaveHistoryScreen` (riwayat).
- Endpoint: `PATCH /staff/:id/subordinates/leave/:leaveId` `{action, alasanTolak?}` (#50) dan `.../lembur/:id` (#51). Server menolak pengajuan sendiri (403 `Anda tidak bisa memproses pengajuan sendiri`) dan pengajuan di luar lokasi yang diwenangi (403).
- Pemuatan: `SubordinateService.load()` dipanggil `LeaveTab` saat dibuat dan saat tarik-refresh; `isApprover=false` untuk staff tanpa grant (server membalas 200 kosong, bukan error).

## `UserRole.admin` — tidak terpakai

`enum UserRole { staff, supervisor, admin }` (`models.dart:262`). `StaffProfile.toUserProfile()` hanya menghasilkan `supervisor` atau `staff` (`models.dart:2302`); tidak ada kode yang memetakan respons API ke `admin`. `AppSession.isAdmin` (`models.dart:14`) hanya bisa true pada data `SampleData` (mock, user `admin` / `ADM-2024-001`), yang tidak pernah dipakai sebagai `currentUser` setelah login nyata. Akibatnya:

- `MainScreen._isAdmin` selalu false → `_buildAdminLayout()`, `AdminDashboardTab`, dan label bottom-nav "Tim" tidak pernah tampil.
- `AdminDashboardTab` (`manager_dashboard_tab.dart`) membaca `SampleData.allUsers` — data karangan. Jangan jadikan acuan perilaku.
- Cabang `user.role != UserRole.admin` di `account_tab.dart` selalu true (menu Riwayat Gaji, kartu Sisa Cuti selalu tampil).

Pelaku yang "mengelola" (Admin/HRD, Manager sebagai pengelola) bekerja di **portal web**, bukan app ini. Atasan di app = staff biasa + `AuthorityGrant`.

## Rework peran web (Direktur, 2026-11)

- Akun **Direktur** dan **Admin** hanya ada di portal web. Staff yang tertaut ke akun Direktur/Admin tetap memakai app sebagai staff biasa.
- Cuti/lembur mereka diproses Manager/Supervisor lokasinya, atau Admin di web.
- "Setujui Cair" slip dilakukan Direktur atau Admin sesuai pengaturan office; Manager Lokasi view-only di payroll. App tidak berubah: yang tampil ke staff hanya `paidOleh` ("Dicairkan oleh ...") dan teks netral "kantor".
- Pindah lokasi tidak punya layar di app. Staff hanya mendapat notifikasi saat disetujui; saat ditolak tidak ada notifikasi (berubah 2026-11-11).

## RENCANA (belum di kode)

- **Direktur** (sudah dikerjakan di web, lihat bagian di atas; disetujui 2026-11-06, [authorization.md](../../../hadir-in-api-backend-express-js/docs/authorization.md)): peran baru untuk Setujui Cair slip. **Web-only** — tidak ada perubahan di app staff yang direncanakan; Direktur yang juga staff tetap memakai app sebagai staff biasa. Jangan menambah peran Direktur di app tanpa keputusan baru.
- Persetujuan lembur oleh Manager di app: belum direncanakan di dokumen mana pun yang saya temukan (**perlu dicek** dengan pemilik produk bila diinginkan).

## Known issues

- Tab "Tim" mock + cabang `UserRole.admin` adalah kode mati; menyesatkan saat membaca.
- Toggle "Diri Sendiri / Tim" di Notifikasi kini hanya muncul bila ada notifikasi `isTeam` sungguhan (API belum pernah mengirimnya, jadi praktis tersembunyi).
- Nama `_isSupervisor` di `leave_tab.dart:46` sebenarnya berarti `isApprover` (menyesatkan).
