# Build, Rilis, dan Environment

Diverifikasi terhadap kode 2026-11-06. **Status: belum siap rilis publik.** Tiga hambatan yang diketahui: host API `http://` ber-IP LAN yang di-hardcode, signing release memakai debug key, dan label aplikasi masih placeholder. Dokumen ini tidak mengubah kode; ia mencatat kondisi dan langkah yang perlu dilakukan pemilik rilis.

## 1. Host API (`lib/config/api_config.dart`)

```dart
static const String host = '10.10.3.12';
static const int port = 4000;
static const String baseUrl = 'http://$host:$port/api';
static const Duration timeout = Duration(seconds: 20);
```

- Semua request lewat `ApiClient` memakai `ApiConfig.baseUrl` (`api_client.dart`); timeout 20 detik per request.
- **Ganti manual** sesuai jaringan sebelum `flutter run`/build: emulator Android `10.0.2.2`; iOS Simulator `localhost`; HP fisik IP LAN komputer backend (HP dan komputer harus satu WiFi). Pesan error jaringan di app sendiri menyebut "pastikan HP dan komputer berada di jaringan WiFi yang sama" (`api_client.dart`).
- **Belum ada `--dart-define` untuk host.** Sumber kebenaran tunggal tetap konstanta di file ini; jangan menyebar URL di tempat lain.
- **`http://` plaintext** (known issue keamanan, juga tercatat di backend). Tidak ada konfigurasi cleartext/App Transport Security di `AndroidManifest.xml` maupun `ios/Runner/Info.plist` (diverifikasi dengan pencarian; Dart `http` memakai `dart:io` sehingga kebijakan cleartext platform tidak otomatis memblokir — **perlu dicek di perangkat**). Sebelum rilis: pindah ke HTTPS dan jadikan host konfigurasi build (mis. `String.fromEnvironment`). Belum ada deployment production; HTTPS ditunda sampai deploy ([ops/deployment.md](../../../hadir-in-api-backend-express-js/docs/ops/deployment.md)).
- Backend mengubah perilaku menurut `NODE_ENV` ([ops/deployment.md](../../../hadir-in-api-backend-express-js/docs/ops/deployment.md)): di non-production `devCode` OTP ikut dikembalikan bila email gagal, dan `body.time` check-in/out dihormati.

## 2. Flag `--dart-define`

| Flag | Default | Fungsi |
|------|---------|--------|
| `TESTING_MODE` | `false` | `true` = GPS & jam palsu untuk uji absensi (`TestingConfig.enabled`, `testing_config.dart:119`) |
| `TESTING_SCENARIO` | `lembur` | `normal`, `terlambat`, `lembur`, `lemburTepatBatas`, `terlambatLembur` — hanya berlaku bila `TESTING_MODE=true` |

```bash
flutter run --dart-define=TESTING_MODE=true --dart-define=TESTING_SCENARIO=terlambat
```

Build rilis tanpa flag ini selalu mode normal (compile-time constant; tidak ada literal di source yang perlu diubah). Wajib cek banner kuning "MODE TESTING" di Home **tidak** muncul pada build yang dibagikan. Detail & checklist: [../TESTING-ABSENSI.md](../TESTING-ABSENSI.md).

## 3. Identitas aplikasi

| Item | Nilai | Sumber |
|------|-------|--------|
| `applicationId` / `namespace` Android | `com.hadirin.staff` | `android/app/build.gradle.kts` |
| Bundle id iOS/macOS | `com.hadirin.staff` | `ios/Runner.xcodeproj` |
| Nama paket Dart | `hadirin_staff_app` | `pubspec.yaml` |
| Versi | `1.0.0+1` (`versionName` 1.0.0, `versionCode` 1) | `pubspec.yaml` `version:`; `build.gradle.kts` memakai `flutter.versionName/versionCode` |
| `minSdk` | 24 (di-pin eksplisit; Firebase ≥ 23) | `build.gradle.kts` |
| `targetSdk` / `compileSdk` | ikut Flutter (`flutter.targetSdkVersion/compileSdkVersion`) | idem |
| Java/Kotlin | 17; `isCoreLibraryDesugaringEnabled = true` (`desugar_jdk_libs 2.1.4`, wajib untuk `flutter_local_notifications`) | idem |

**`applicationId` FINAL — jangan diubah** (2026-09-08): terikat mati ke `google-services.json` dan listing Play Store; mengubahnya berarti mendaftar ulang app di Firebase Console. `AndroidManifest.xml` sengaja tidak punya atribut `package` (tidak didukung sejak AGP 8).

**Naikkan versi** dengan mengubah `version:` di `pubspec.yaml` (`nama+build`); `build` menjadi `versionCode` Android / `CFBundleVersion` iOS. Belum ada skrip/otomasi versi.

**Label aplikasi masih placeholder:** `android:label="app_staff_flutter"` (`AndroidManifest.xml`), `CFBundleDisplayName` = "App Staff Flutter" (`Info.plist`). Nama yang terlihat di launcher belum "Hadir-In" (known issue branding).

Ikon launcher: `dart run flutter_launcher_icons` (konfigurasi di `pubspec.yaml`, sumber `assets/icon/`) bila logo berubah.

## 4. Signing (TODO)

`android/app/build.gradle.kts`, blok `buildTypes.release`:

```kotlin
// TODO: Add your own signing config for the release build.
signingConfig = signingConfigs.getByName("debug")
```

Build release saat ini **ditandatangani dengan debug key** — tidak dapat diunggah ke Play Store sebagai rilis produksi dan keystore-nya bukan milik tim. Yang perlu dilakukan pemilik rilis (belum dikerjakan): buat upload keystore, simpan di luar repo, tambahkan `key.properties` (di-gitignore) dan `signingConfigs.release`, dan daftarkan SHA-1/SHA-256 di Firebase Console (Google Sign-In & FCM). Status minify/proguard: tidak dikonfigurasi (**perlu dicek** saat membuat build rilis). iOS: signing/provisioning belum didokumentasikan.

## 5. Izin platform

**Android** (`android/app/src/main/AndroidManifest.xml`):

| Izin | Untuk |
|------|-------|
| `CAMERA` (+ `uses-feature camera required=false`) | selfie absensi, foto dokumen/lampiran |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | GPS geofence |
| `INTERNET` | API |
| `POST_NOTIFICATIONS` | notifikasi (izin runtime Android 13+) |
| `VIBRATE` | notifikasi |
| `WRITE_EXTERNAL_STORAGE` (maks SDK 29), `READ_MEDIA_IMAGES` | galeri |

Manifest juga menunjuk `com.google.firebase.messaging.default_notification_channel_id = hadirin_umum` dan ikon notifikasi default `@mipmap/ic_launcher`.

**iOS** (`ios/Runner/Info.plist`): `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` (teks Indonesia). Tidak ada `CFBundleURLTypes` untuk Google Sign-In dan `GoogleService-Info.plist` tidak ada di working tree → Google Sign-In (simpan slip ke Drive) dan push FCM di iOS **perlu dicek / belum dikonfigurasi**.

## 6. Firebase / Google

Berkas kredensial (di-gitignore, minta ke pemilik project, **jangan commit**): `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`. Plugin `com.google.gms.google-services` (classpath di `android/settings.gradle.kts`, v4.4.2) diterapkan **bersyarat** di `build.gradle.kts` hanya bila `google-services.json` ada; tanpa file itu Gradle mencetak `[hadir-in] android/app/google-services.json belum ada -- ... push FCM TIDAK akan jalan` dan build tetap sukses. Jangan ubah jadi tanpa syarat. Langkah setup dan uji push: [FCM-SETUP.md](FCM-SETUP.md).

Google Sign-In/Drive (`google_drive_service.dart`, scope `drive.file`): di Android memakai `google-services.json` (tanpa `clientId`); `clientId` hanya untuk Web.

## 7. Perintah umum

```bash
flutter pub get
flutter analyze
flutter test
flutter run [--dart-define=...]
flutter build apk            # saat ini signed debug — jangan dibagikan sebagai rilis
flutter build appbundle      # setelah signing release dibuat
```

## 8. Checklist sebelum membagikan build

1. `host` di `api_config.dart` menunjuk server yang benar (dan HTTPS bila tersedia).
2. Tanpa `--dart-define=TESTING_MODE=true`; banner MODE TESTING tidak muncul.
3. `google-services.json` ada bila push dibutuhkan; paket `com.hadirin.staff` cocok.
4. Signing release sudah benar (bagian 4) bila untuk Play Store.
5. Label aplikasi dan versi sudah sesuai.
6. Bersihkan data absensi hasil uji di DB bila sebelumnya memakai mode testing.
