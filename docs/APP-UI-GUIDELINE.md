# 📱 Hadir-In Staff App - UI & Layout Guideline

> **Panduan UI, Styling, dan Layout untuk Aplikasi Mobile Staff Hadir-In (Flutter) berdasarkan Official Color Palette Web Admin.**

Dokumen ini berfungsi sebagai referensi utama dalam membangun antarmuka (Front-End) untuk aplikasi mobile Hadir-In agar senada (konsisten) dengan dashboard Web Admin.

---

## 🎨 1. Color Palette (Flutter Implementation)

Warna-warna berikut merupakan terjemahan dari `COLOR-PALETTE.md` ke dalam format kode Dart/Flutter. Sangat disarankan untuk membuat satu file khusus (misalnya `app_colors.dart`) untuk mendefinisikan seluruh warna ini.

### **Primary Brand Colors**
```dart
import 'package:flutter/material.dart';

class AppColors {
  // 1. Navy Blue (Primary) - Trust & Professionalism
  static const Color brandNavy = Color(0xFF2D377F);
  static const Color brandNavyDark = Color(0xFF1E285A);
  static const Color brandNavyLight = Color(0xFF4A5599);

  // 2. Cyan Blue (Secondary) - Modern & Tech feel, Interactive elements
  static const Color brandCyan = Color(0xFF4DD0E1);
  static const Color brandCyanLight = Color(0xFF64E6F5);
  static const Color brandCyanDark = Color(0xFF00ACC1);

  // 3. Lime Green (Accent/Success) - Positivity, Success states
  static const Color brandLime = Color(0xFF9CCC65);
  static const Color brandLimeLight = Color(0xFFC5E1A5);
  static const Color brandLimeDark = Color(0xFF7CB342);
}
```

### **Neutral / Supporting Colors**
Gunakan warna-warna netral untuk background, border, dan teks.
```dart
class AppColors {
  // ... (brand colors di atas)

  // Background Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color slate50 = Color(0xFFF8FAFC);  // Light background utama aplikasi
  static const Color slate100 = Color(0xFFF1F5F9); // Tanda/Hover/Background field
  static const Color slate200 = Color(0xFFE2E8F0); // Borders dan Divider
  static const Color slate300 = Color(0xFFCBD5E1); // Disabled states

  // Text Colors
  static const Color slate900 = Color(0xFF0F172A); // Primary text (Heading)
  static const Color slate800 = Color(0xFF1E293B); // Secondary text
  static const Color slate700 = Color(0xFF334155); // Body text
  static const Color slate600 = Color(0xFF475569); // Muted / Subtitle text
  static const Color slate400 = Color(0xFF94A3B8); // Placeholder text

  // Semantic Colors
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFFC107);
}
```

### **Gradients (Opsional untuk Hero/Header)**
Jika membutuhkan gradient senada di Flutter:
```dart
final LinearGradient primaryGradient = LinearGradient(
  colors: [AppColors.brandNavy, AppColors.brandCyan],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
```

---

## 🔤 2. Typography

Gunakan font modern dan bersih (seperti **Inter** atau **Poppins** melalui package `google_fonts`).

### **Panduan Styling Teks:**
- **Headings (H1, H2, H3):** Warna `brandNavy` atau `slate900`, Font Weight **Bold** (700) atau **SemiBold** (600).
- **Body / Paragraf:** Warna `slate700`, Font Weight **Regular** (400) atau **Medium** (500).
- **Subtitle / Keterangan Kecil:** Warna `slate600` atau `slate400`, ukuran font lebih kecil (12px - 14px).

---

## 📐 3. Layouting Standar

Untuk memastikan aplikasi terasa lega, profesional, dan nyaman digunakan, ikuti aturan spacing dan layout berikut:

### **Padding & Margin Utama**
- **Screen Edge Padding (Kiri & Kanan layar):** `16.0` atau `20.0` atau `24.0` pixels konstan. 
  ```dart
  const EdgeInsets.symmetric(horizontal: 20.0);
  ```
- **Spacing Antar Komponen Vertikal (Sizing):** Gunakan kelipatan 8, seperti `8.0`, `16.0`, `24.0`, atau `32.0`.
  ```dart
  const SizedBox(height: 16.0);
  ```

### **Struktur Layar Tembus Ruang (Scaffold Default)**
- **Background Color:** Gunakan `AppColors.slate50` agar tidak murni putih polos, memberi kesan lembut dan modern.
- **AppBar:**
  - **Opsi 1 (Bersih):** Background putih (`white`), Teks/Icon warna Navy (`brandNavy`), Elevasi `0.0` (flat) dengan garis border tipis di bawah warna `slate200`.
  - **Opsi 2 (Bold):** Background Navy (`brandNavy`) dengan teks Putih.
- **Bottom Navigation Bar:** Background Putih, Active Icon warna Navy (`brandNavy`) atau Cyan (`brandCyan`), Inactive Icon warna Slate (`slate400`).

---

## 🧩 4. Komponen UI (Widgets)

### **A. Buttons (Tombol)**
Buat custom widget atau atur di `ElevatedButtonThemeData`.
- **Primary Button (Aksi Utama / Absen Sekarang):**
  - Background: `AppColors.brandNavy`
  - Text: Putih, Font Semi-Bold.
  - Border Radius: `8.0` atau `12.0`
- **Secondary Button:**
  - Background: Murni putih (`white`) atau transparan dengan border (Outline) warna `brandNavy` atau `brandCyan`.
- **Success Button (Misal: Tombol Selesai):**
  - Background: `AppColors.brandLime`
  - Text: Navy Dark atau Putih.

### **B. Cards (Kartu Informasi)**
Digunakan untuk menampung data riwayat absen, profil singkat, atau rincian absensi hari ini.
- **Styling Card Utama:**
  - Box Decoration / Card Widget di Flutter:
  - Background: `AppColors.white`
  - Border Radius: `12.0` atau `16.0`
  - Border: Tipis `1.0` width dengan warna `AppColors.slate200` (Opsional jika ingin flat style).
  - Shadow (Soft): 
    ```dart
    BoxShadow(
      color: AppColors.brandNavy.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    )
    ```

### **C. Status Badges (Label Status)**
Digunakan untuk menandakan status absensi (Hadir, Izin, Sakit, Terlambat).
- **Badge Sukses (Hadir / Disetujui):**
  - Background: `AppColors.brandLime.withOpacity(0.2)`
  - Text Color: `AppColors.brandLimeDark`
- **Badge Info (Berjalan / Sedang Kerja):**
  - Background: `AppColors.brandCyan.withOpacity(0.2)`
  - Text Color: `AppColors.brandCyanDark`
- **Badge Warning/Error (Terlambat / Ditolak):**
  - Background: Merah terang/Kuning transparan.

### **D. TextFields (Form Input)**
Digunakan untuk form login atau form pengajuan cuti/izin.
- **Sleek Input Field:**
  - Filled: `true` dengan `fillColor: AppColors.white`
  - Border Radius: `8.0` atau `12.0`
  - OutlineInputBorder default: warna `AppColors.slate200`
  - OutlineInputBorder focused: warna `AppColors.brandCyan` atau `AppColors.brandNavy`
  - Hint Text: warna `AppColors.slate400`


Semua element ini jika dipadukan menggunakan palet warna dan guideline margin di atas, akan menciptakan aplikasi Flutter yang *pixel-perfect* senada dan terasa satu kesatuan (ecosystem) dengan Sistem Hadir-In Web Admin.
