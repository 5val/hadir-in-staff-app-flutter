# Dokumentasi

Index dokumentasi untuk **Hadir-In Staff App** (Flutter/Dart). Terakhir disinkronkan dengan kode: 2026-11-06 (branch `sprint3`).

Konvensi label di semua dokumen: tanpa label = perilaku kode sekarang · **RENCANA** = keputusan yang belum ada di kode · **perlu dicek** = tidak bisa dibuktikan dari kode. Kode adalah sumber kebenaran; kalau dokumen dan kode berbeda, kodenya yang benar.

## Mulai dari sini

| Dokumen | Isi |
|---------|-----|
| [../README.md](../README.md) | Ringkasan proyek, quickstart, `--dart-define`, berkas Firebase |
| [../CLAUDE.md](../CLAUDE.md) | Arsitektur, struktur folder, konvensi, known issues ringkas (untuk developer/agent) |

## Fitur & alur (`features/`)

| Dokumen | Isi |
|---------|-----|
| [features/APP-FEATURES.md](features/APP-FEATURES.md) | Peta per layar: navigasi/tab, siapa yang melihat, aksi, gerbang, endpoint, status; daftar layar yatim/mock dan menu "coming soon" |
| [features/ROLE-MATRIX.md](features/ROLE-MATRIX.md) | Staff vs atasan (`isApprover`) vs supervisor vs `UserRole.admin` (tidak terpakai) |
| [features/AUTH-LOGIN-FLOW.md](features/AUTH-LOGIN-FLOW.md) | Login, OTP via email, passcode, lupa passcode, ganti nomor HP, penyimpanan sesi, logout |
| [features/ABSENSI-SHIFT-RULES.md](features/ABSENSI-SHIFT-RULES.md) | Geofence, batas deteksi wajah, GPS palsu, check-in/out/istirahat, shift malam, lembur, sesi menggantung, mode testing, bug yang diketahui |
| [features/CUTI-IZIN-LEMBUR.md](features/CUTI-IZIN-LEMBUR.md) | Pengajuan cuti/izin/lembur oleh staff dan alur persetujuan atasan |
| [features/SLIP-GAJI-FLOW.md](features/SLIP-GAJI-FLOW.md) | Sisi app dari alur penggajian: status, tombol, Tolak/Batalkan persetujuan, Fasilitas, THP, bukti, Drive |
| [features/ONBOARDING-DOKUMEN.md](features/ONBOARDING-DOKUMEN.md) | Gerbang dokumen, draft lokal, "Ajukan Dokumen", pakai ulang dokumen |

## Sistem & panduan

| Dokumen | Isi |
|---------|-----|
| [NOTIFICATION-SYSTEM.md](NOTIFICATION-SYSTEM.md) | Arsitektur notifikasi: FCM + polling + peringatan lokal, dedup, deep-link |
| [guides/FCM-SETUP.md](guides/FCM-SETUP.md) | Berkas Firebase, kondisi build tanpa kredensial, cara menguji push |
| [guides/BUILD-RELEASE-ENV.md](guides/BUILD-RELEASE-ENV.md) | Host API, `--dart-define`, signing (TODO), versi, izin platform, `applicationId` |
| [TESTING.md](TESTING.md) | Peta berkas test dan aturan "test baru harus terbukti gagal di kode lama" |
| [TESTING-ABSENSI.md](TESTING-ABSENSI.md) | Mode testing absensi (GPS & jam palsu), skenario, checklist rilis |

## Panduan UI & Desain

| Dokumen | Isi |
|---------|-----|
| [APP-UI-GUIDELINE.md](APP-UI-GUIDELINE.md) | Terjemahan color palette web ke Dart/Flutter (`AppColors`), typography, layout spacing, dan komponen dasar |
| [UI-DESIGN-GUIDE.md](UI-DESIGN-GUIDE.md) | Panduan desain komprehensif — layout, tipografi, komponen, animasi, anti-pattern, checklist sebelum PR |
| [COLOR-PALETTE.md](COLOR-PALETTE.md) | Palet warna resmi Hadir-In (Navy, Cyan, Lime) |

## Arsip

| Dokumen | Status |
|---------|--------|
| [SPRINT2-EPIC9-FLUTTER-TASKS.md](SPRINT2-EPIC9-FLUTTER-TASKS.md) | **Diarsipkan** — pekerjaan Sprint 2 EPIC 9 sudah selesai (2026-08-01); checklist di dalamnya tidak diperbarui dan nomor baris basi |

## Tautan lintas repo

- [Backend — mobile-api.md](../../hadir-in-api-backend-express-js/docs/mobile-api.md) — kontrak lengkap `/api/mobile/*` (49 route), keadaan sekarang. App ini mengonsumsinya lewat `lib/services/`.
- [Backend — authorization.md](../../hadir-in-api-backend-express-js/docs/authorization.md) — matriks peran (Admin, Manager, Supervisor, Staff) dan rencana peran Direktur.
- Backend — log kontrak per sprint: [sprint2.md](../../hadir-in-api-backend-express-js/docs/api-contracts/sprint2.md), [sprint3.md](../../hadir-in-api-backend-express-js/docs/api-contracts/sprint3.md) (slip gaji, notifikasi, dan perubahan terbaru ada di sprint3).
- Backend — [NOTIFICATION-SYSTEM.md](../../hadir-in-api-backend-express-js/docs/NOTIFICATION-SYSTEM.md) — sisi server push FCM.
- [Web Admin — ATURAN-BISNIS-PENGGAJIAN.md](../../hadir-in-web-admin-react/docs/product/ATURAN-BISNIS-PENGGAJIAN.md) — aturan bisnis penggajian kanonik (status slip, rumus, lembur, shift malam). Dokumen Flutter menautkan ke sini, tidak menduplikasinya.
- [Web Admin — design-system.md](../../hadir-in-web-admin-react/docs/design/design-system.md) dan [mobile-ui-guideline.md](../../hadir-in-web-admin-react/docs/design/mobile-ui-guideline.md) — sumber brand color dan panduan UI Flutter dari sisi web.
