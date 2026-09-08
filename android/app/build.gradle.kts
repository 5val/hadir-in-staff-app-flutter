plugins {
    id("com.android.application")
    //id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hadirin.staff"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications memakai API java.time; desugaring
        // WAJIB supaya build tidak gagal di minSdk yang dipakai app ini.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // applicationId FINAL produk (2026-09-08). Diturunkan dari domain
        // resmi hadir-in.com; tanda hubung tidak legal di segmen package Java
        // sehingga "hadir-in" ditulis "hadirin". JANGAN diubah lagi setelah
        // app terdaftar di Firebase Console / Google Play -- google-services.json
        // terikat mati ke nilai ini, dan Play Store menolak com.example.*.
        applicationId = "com.hadirin.staff"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Di-pin eksplisit, bukan flutter.minSdkVersion (2026-09-08). Firebase
        // Cloud Messaging / Firebase BoM mensyaratkan minSdk >= 23; nilai 24
        // dipilih karena itu default Flutter 3.44 saat ini -- menurunkannya ke
        // 23 akan MENGURANGI floor yang berlaku sekarang dan memicu warning
        // "minSdk lebih rendah dari yang didukung" dari Flutter Gradle plugin.
        // Pinning mencegah floor ikut bergeser diam-diam saat SDK Flutter di-upgrade.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// ── Firebase Cloud Messaging: plugin google-services ─────────────────────
// Menaruh google-services.json saja TIDAK cukup -- file itu baru dibaca
// (dan diubah jadi resource yang dipakai firebase_core saat runtime) kalau
// plugin ini ikut diterapkan. Classpath-nya dideklarasikan di
// android/settings.gradle.kts dengan `apply false`.
//
// Sengaja diterapkan BERSYARAT: google-services.json di-gitignore dan belum
// ada di repo (menunggu kredensial Firebase dari pemilik project, lihat
// hadir-in-web-admin-react/docs/product/SPRINT3-REMAINING-FCM-REQUIREMENT-*.md).
// Kalau plugin diterapkan tanpa file itu, SEMUA build gagal dengan
// "File google-services.json is missing" -- termasuk build developer lain
// yang tidak sedang menggarap FCM. Dengan guard ini repo tetap bisa
// di-build sekarang, dan FCM otomatis aktif begitu file-nya ditaruh.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "[hadir-in] android/app/google-services.json belum ada -- plugin " +
            "google-services dilewati, push FCM TIDAK akan jalan di build ini. " +
            "Taruh file dari Firebase Console (package: com.hadirin.staff) " +
            "untuk mengaktifkannya."
    )
}
