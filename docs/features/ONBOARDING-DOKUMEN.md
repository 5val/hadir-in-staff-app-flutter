# Onboarding Dokumen (Gerbang Dokumen)

Diverifikasi terhadap kode 2026-11-06. Kontrak: [mobile-api.md bagian 4](../../../hadir-in-api-backend-express-js/docs/mobile-api.md) (#17–#21). Kode: `lib/screens/onboarding_documents_screen.dart`, `lib/services/document_service.dart`, `document_draft_service.dart`, `lib/widgets/uploaded_file_image.dart`, gerbang di `lib/screens/main_screen.dart#_hydrateProfile`. Pemicu pembukaan ulang: ganti nomor HP ([AUTH-LOGIN-FLOW.md §7](AUTH-LOGIN-FLOW.md)).

## 1. Dokumen apa saja

App melacak 4 jenis (enum `DocumentJenis`, harus sama dengan `StaffDocumentJenis` di Prisma): **Pas Foto** (`PasFoto`), **KTP**, **BPJS**, **NPWP**. Backend juga mengenal jenis `Lainnya` (+ `jenisLainKeterangan`), tetapi **app tidak menawarkannya**.

Mana yang **wajib** ditentukan **server** per staff (`OnboardingDocument.required`): Pas Foto dan KTP selalu wajib; BPJS dan NPWP wajib hanya bila BPJS staff itu aktif (komentar `requiredDocuments`: "2 atau 4"). Layar tetap menampilkan keempatnya; yang tidak wajib ditandai OPSIONAL dan boleh diisi kapan saja lewat Akun → Dokumen Saya.

## 2. Gerbang masuk app

Satu tempat: `MainScreen._hydrateProfile` memanggil `GET /staff/:id/onboarding-status` (#19) setelah profil termuat. `completed == false` → `MainScreen` menampilkan `OnboardingDocumentsScreen` **sebagai layar pengganti** (bukan navigasi, supaya tidak ada route MainScreen setengah terbuka yang bisa dikembalikan tombol back). Semua jalur masuk (login, buka kunci passcode, sesi aktif) ikut tergerbang karena semuanya lewat `MainScreen`. `LoginScreen._finishLogin` juga memeriksa dan langsung mengarahkan ke layar dokumen supaya staff baru tidak melihat kilatan MainScreen; pemeriksaan di sana tidak dianggap gerbang (gagal cek = lanjut).

Aturan gerbang (milik server, `completed`): semua dokumen **wajib** sudah pernah **diajukan** (status apa pun: `pending`, `approved`; unggahan sebelum `documentsResetAt` tidak dihitung). **Penolakan HRD tidak mengunci app lagi** — hanya memicu notifikasi `document_rejected` dan badge "DITOLAK" di Akun → Dokumen Saya untuk mengunggah ulang. **Gagal memeriksa (jaringan/server) = fail-open**: staff dibiarkan masuk dan pemeriksaan diulang saat app dibuka lagi.

## 3. Layar `OnboardingDocumentsScreen`

Dua mode:

| | `manageMode: false` (gerbang) | `manageMode: true` (Akun → Dokumen Saya) |
|--|--|--|
| Judul | "Lengkapi Data Diri" | "Dokumen Saya" |
| Tombol kembali | tidak ada; ada tombol **Keluar** (logout) | ada |
| Lompat otomatis ke app | ya, bila **semua** dokumen terkirim (`allSubmitted`) dan tak ada draft | tidak |
| Tombol bawah | "Masuk ke Aplikasi" / "Lanjut ke Aplikasi (lengkapi nanti)" saat dokumen wajib sudah terkirim dan tak ada draft | "Selesai" |

Status kartu per dokumen (label): **BELUM DIPILIH**, **SIAP DIAJUKAN** (ada draft lokal — menang atas status server), **MENUNGGU REVIEW** (`pending`), **DISETUJUI** (`approved`), **DITOLAK** (`rejected`; menampilkan "Catatan HRD: …" dari `latestCatatanAdmin`). Pratinjau berkas lewat `UploadedFileImage` (URL Drive privat dibuka lewat proxy ber-auth `GET /api/mobile/files/:fileId`, #44).

## 4. Draft lokal — berkas TIDAK diunggah saat dipilih

Aturan penting (jangan dikembalikan ke unggah per kartu): memilih berkas hanya **menyalin** ke folder privat app lewat `DocumentDraftService` (`<documents>/document_drafts/`, indeks di `SharedPreferences` kunci `document_drafts_v1`; bertahan walau app ditutup). Alasannya: dulu satu ketukan langsung menaruh berkas di Google Drive dan membuat baris `staff_document` pending yang tidak bisa dibatalkan staff.

Langkah per dokumen:
1. Ketuk kartu → pilih **Kamera** atau **Galeri** (`image_picker`, `imageQuality: 85`, `maxWidth: 2000` supaya < 8 MB).
2. Sheet opsional **Catatan untuk <dokumen>** (mis. "Nama saya salah, seharusnya …") → disimpan sebagai `catatanStaff`; "Lewati" boleh.
3. Draft tersimpan; kartu "SIAP DIAJUKAN". Draft bisa dihapus (`_removeDraft`) sebelum diajukan.

Hanya **gambar** yang ditawarkan di UI (kamera/galeri). Server sebenarnya menerima juga PDF (`_mimeFromPath` mengenali `.pdf`), tetapi tidak ada pemilih berkas PDF di app.

## 5. "Ajukan Dokumen" — satu-satunya pengiriman

`_submitAll` (dari tombol tunggal "Ajukan Dokumen" / "Ajukan Ulang Dokumen" bila ada yang menggantikan berkas sebelumnya):
- Berurutan menurut `pickedAt`; per draft: berkas baru → `POST /staff/:id/documents` `{jenis, fileBase64, fileMimeType, catatanStaff?}` (#17, 201; backend menyimpan ke Google Drive office dan mengirim notifikasi office `document_submitted`); draft "pakai ulang" → `POST /documents/reuse {jenis}` (#21).
- Sukses → draft dihapus. **Kegagalan satu dokumen tidak membatalkan yang lain**; draft gagal tetap di HP untuk dicoba lagi tanpa memotret ulang. Toast ringkas: "N dokumen berhasil diajukan. Menunggu review HRD." / "N dokumen terkirim. Gagal: … — coba ajukan lagi."
- Selesai → `_load()` ulang status.

## 6. Pembukaan ulang gerbang (ganti nomor HP) dan pakai-ulang dokumen

Setelah `phone-change/verify` sukses, server mengisi `documentsResetAt`; `OnboardingStatus.isResubmission` true → layar menampilkan banner "Nomor HP Anda baru saja diganti … dokumen identitas perlu diajukan ulang. Dokumen yang sudah pernah disetujui bisa dipakai lagi tanpa memotret ulang." App memanggil `GET /documents/previous` (#20) — satu dokumen lama per jenis (bukan `rejected`) — dan per kartu menawarkan **pakai berkas sebelumnya** (`ReusableDocument`, label "Sudah disetujui" / "Menunggu review"). Pilihan itu juga hanya draft sampai "Ajukan Dokumen" ditekan; barulah `POST /documents/reuse`.

## 7. Logout dari layar ini

Tombol **Keluar** (hanya `manageMode: false`) memanggil `SessionService.clearSession()` saja — tidak membersihkan draft dokumen (lihat known issue di [AUTH-LOGIN-FLOW.md §9](AUTH-LOGIN-FLOW.md)): staff berikutnya di HP yang sama bisa mewarisi draft berkas staff sebelumnya (`DocumentDraftService.all()` tidak dikunci per staff).

## 8. Notifikasi terkait

`document_submitted`, `document_approved`, `document_rejected` → petunjuk menu "Akun > Dokumen Saya" (`NotificationMenuHints`). Tipe `document_*` tidak punya tab tujuan (`NotificationTarget.none`), jadi mengetuk notifikasi HP-nya membuka layar Notifikasi.

## 9. Known issues

- Draft dokumen tidak dibersihkan di logout selain `MainScreen._logout` (bagian 7).
- Jenis `Lainnya` tidak terjangkau dari app.
- Hanya gambar; tidak bisa memilih PDF walau server mengizinkan.
- RENCANA (bukan dokumen identitas, tetapi bersangkutan dengan lampiran berkas): lampiran bukti izin/sakit akan dapat dikonfigurasi per jenis oleh admin — lihat [CUTI-IZIN-LEMBUR.md](CUTI-IZIN-LEMBUR.md).
