# 📱 UI Design Guide — Hadir-In Staff App

> **Panduan desain komprehensif untuk tim developer dan designer.**
> Dokumen ini dibangun dari analisis langsung terhadap seluruh widget, layout, dan flow yang ada dalam codebase Flutter Hadir-In, bukan sekadar teori desain umum.
> Selalu merujuk pada `APP-UI-GUIDELINE.md` dan `COLOR-PALETTE.md` sebagai sumber otoritatif warna dan komponen dasar.

---

## Daftar Isi

1. [Design Philosophy](#1-design-philosophy)
2. [Layout Guidelines](#2-layout-guidelines)
3. [Typography Guidelines](#3-typography-guidelines)
4. [Component Design Rules](#4-component-design-rules)
5. [Color Usage Rules](#5-color-usage-rules)
6. [Natural UI Principles](#6-natural-ui-principles)
7. [Animation & Interaction](#7-animation--interaction)
8. [Screen-by-Screen Notes](#8-screen-by-screen-notes)
9. [UI Anti-Pattern List](#9-ui-anti-pattern-list)
10. [Final UI Standard Checklist](#10-final-ui-standard-checklist)

---

## 1. Design Philosophy

### Apa yang Hadir-In Kejar

Hadir-In adalah aplikasi HR dan absensi yang digunakan karyawan setiap hari, sering kali di pagi hari sebelum kerja atau di lokasi dengan kondisi tidak ideal (cahaya rendah, tangan sibuk, waktu terbatas). Desain harus mencerminkan alat kerja profesional yang **dipercaya**, bukan showcase estetika.

### Pilar Utama

| Pilar | Penjelasan |
|---|---|
| **Human-made** | UI terasa dibuat oleh manusia yang memikirkan alur penggunaan nyata. Tidak terasa di-generate dari template. |
| **Production-ready** | Setiap screen terasa sudah siap rilis, bukan prototype. Tidak ada elemen placeholder yang "akan diisi nanti". |
| **Calm & readable** | Warna tidak berteriak, font tidak berjejal, whitespace digunakan dengan niat. Nyaman dipakai 30 menit tanpa lelah mata. |
| **Functional-first** | Estetika mengikuti fungsi, bukan sebaliknya. Tombol check-in harus jelas sebelum cantik. |
| **Consistent without being robotic** | Konsistensi dalam spacing dan komponen, tetapi ada variasi alami antar section yang membuat UI terasa hidup. |

### Yang TIDAK Dikejar

- Tampilan yang "wow" pada screenshot pertama tapi membingungkan saat dipakai
- Gradien, glow, dan animasi yang memperlihatkan "kemampuan teknis" tapi tidak membantu pengguna
- Symmetry yang terlalu sempurna sehingga terasa di-generate oleh AI
- Layout yang bisa dipakai untuk aplikasi apa saja tanpa perubahan (terlalu generik)

---

## 2. Layout Guidelines

### 2.1 Page Structure

Setiap screen dalam Hadir-In mengikuti struktur hierarki berikut:

```
Scaffold (backgroundColor: AppColors.slate50)
├── SafeArea
│   ├── AppBar / Custom Header (backgroundColor: white, flat, border bottom slate200)
│   │   ├── Section label kecil (contoh: "HADIR-IN", "ATTENDANCE")
│   │   └── Page title (H2)
│   └── Body (ScrollView / ListView)
│       ├── Section utama (padding horizontal 20)
│       ├── Cards / SectionCard
│       └── Bottom padding 100 (jaga jarak dari BottomNav)
└── BottomNavigationBar / FloatingActionButton
```

**Mengapa `slate50` bukan putih?** Latar murni putih terasa steril dan melelahkan. `slate50` (`#F8FAFC`) memberi kedalaman visual yang halus sehingga card putih "mengambang" secara natural.

### 2.2 Spacing System

Gunakan sistem spacing berbasis 4px, dengan kelipatan yang umum dipakai:

| Token | Nilai | Penggunaan |
|---|---|---|
| `xs` | `4px` | Jarak antar teks label dan nilai, antar icon dan teks dalam satu baris |
| `sm` | `8px` | Jarak antar chip, jarak dalam komponen kecil |
| `md` | `12px` | Jarak antar elemen dalam satu card |
| `base` | `16px` | Jarak antar card dalam list, padding card standard |
| `lg` | `20px` | Screen edge padding (kiri-kanan layar), padding AppBar |
| `xl` | `24px` | Jarak antar section utama dalam satu screen |
| `2xl` | `32px` | Jarak visual besar, misalnya antara hero dan konten pertama |
| `bottom` | `100px` | Padding bawah scroll content (menghindari BottomNav) |

> **Catatan praktis:** Spacing tidak harus matematically perfect. Pada beberapa tempat, `14px` atau `18px` lebih natural dari `16px` atau `20px`. Lihat konteks visual, bukan hanya angka.

### 2.3 Screen Edge Padding

Seluruh konten layar menggunakan padding horizontal **20px** secara konsisten. Ini sudah diterapkan di hampir semua screen dan harus dipertahankan.

```dart
// KONSISTEN di seluruh app
padding: const EdgeInsets.fromLTRB(20, 16, 20, 100)
```

Pengecualian: komponen yang sengaja `full-bleed` (seperti hero card check-in, atau AppBar) boleh tidak menggunakan padding ini.

### 2.4 Section Hierarchy

Gunakan tiga level hierarki visual dalam satu screen:

1. **Level 1 — Section title:** Label uppercase kecil (contoh: `"HADIR-IN"`) + Judul besar H2. Identitas page.
2. **Level 2 — Group title:** H3 dengan icon kecil di kiri (contoh: `"Akun"`, `"Keamanan"`). Memisahkan kelompok fungsional.
3. **Level 3 — Item:** Konten di dalam card. Tidak boleh ada heading lagi di sini.

### 2.5 Card Grouping

- Elemen yang secara logika berhubungan **harus** berada dalam satu `SectionCard` yang sama
- Jangan memecah informasi terkait ke dalam dua card berbeda hanya karena alasan estetika
- Satu card = satu topik atau satu aksi
- Gunakan `AppDivider` untuk memisahkan item dalam satu card, bukan card terpisah

### 2.6 Visual Breathing Room

Setiap screen harus memiliki "ruang napas" yang cukup. Aturan praktis:

- Minimal `16px` antara dua card yang berbeda
- Minimal `12px` padding vertikal di dalam card
- Jangan pernah mengisi layar hingga terasa sesak — jika konten terlalu padat, pertimbangkan untuk memecah ke screen baru atau menggunakan accordion
- Section terakhir sebelum bottom padding harus memiliki `SizedBox(height: 24)` minimum

### 2.7 Scrolling Behavior

- Gunakan `ListView` dengan `shrinkWrap: false` untuk konten yang bisa scroll
- `SingleChildScrollView` hanya untuk screen yang kontennya predictable dan tidak terlalu panjang (seperti login form)
- `GridView` hanya untuk timeline atau data yang memang berbentuk grid (maksimal 2 kolom di mobile)
- Hindari nested scroll kecuali sangat diperlukan

### 2.8 Safe Area

Selalu wrap body dengan `SafeArea`. AppBar custom yang dibuat manual harus berada di dalam SafeArea agar tidak tertutup notch/status bar.

---

## 3. Typography Guidelines

### 3.1 Font Family

Seluruh app menggunakan **Google Fonts Inter** sebagai font utama. `JetBrains Mono` digunakan **khusus** untuk data numerik real-time (timer, jam kerja, format waktu digital).

```dart
// Teks umum
GoogleFonts.inter(...)

// Data numerik / monospace
GoogleFonts.jetBrainsMono(...)
```

### 3.2 Type Scale

| Role | Size | Weight | Color Default | Penggunaan |
|---|---|---|---|---|
| `headline1` | 26–28px | 800 | slate900 | Nama user di Home, judul halaman besar |
| `headline2` | 20–22px | 700–800 | slate900 | Page title utama |
| `headline3` | 16–18px | 700 | slate900 | Section title, modal title |
| `label` | 12–13px | 700 | brandNavy / slate700 | Label uppercase section, field label |
| `body1` | 14px | 500–600 | slate900 | Item title dalam list |
| `body2` | 12–13px | 400 | slate600 | Subtitle, deskripsi, caption utama |
| `caption` | 9–11px | 500–600 | slate400–slate600 | Timestamp, hint kecil, badge text |
| `button` | 13–14px | 700 | white / brandNavy | Label tombol |
| `monospace` | 22–28px | 700–800 | kontekstual | Timer, jam digital |

### 3.3 Aturan Readability

- **Line height minimum 1.4** untuk body text dan caption yang lebih dari satu baris
- **Letter spacing** hanya digunakan pada teks label uppercase kecil (maksimal `1.2`)
- **Jangan gunakan font size di bawah 9px** untuk teks yang harus dibaca pengguna
- **Jangan bold semua teks** — bold hanya untuk elemen yang benar-benar perlu menonjol
- **Hindari italic** — tidak ada konteks yang membutuhkan italic dalam app ini
- **Kontras minimum:** teks utama di atas background putih harus memiliki rasio kontras minimal 4.5:1

### 3.4 Text Density

- Satu screen tidak boleh memiliki lebih dari tiga ukuran font yang berbeda
- Jika ada informasi yang tidak cukup penting untuk ditampilkan dengan font 12px, pertimbangkan untuk tidak menampilkannya sama sekali
- Gunakan `maxLines` dan `overflow: TextOverflow.ellipsis` pada teks dinamis yang bisa sangat panjang

---

## 4. Component Design Rules

### 4.1 Buttons

#### Primary Button (GradientButton)
```
Height:      48–54px
Border Radius: 12–14px
Background:  brandNavy (atau warna semantik sesuai konteks)
Text:        white, 14px, weight 700
Icon:        20px, leading
Loading:     CircularProgressIndicator kecil, bukan text "Loading..."
Disabled:    slate300 background, slate700 text
```

**Aturan penggunaan:**
- Maksimal **satu primary button per screen section**. Jika ada dua aksi utama, salah satunya harus menjadi secondary/outlined.
- Primary button selalu berada di paling bawah section atau form
- Tombol check-in/check-out yang besar (full-width dengan padding vertikal 32px) adalah pengecualian khusus — hanya untuk aksi kritis utama di HomeTab

#### Secondary / Outlined Button
```
Border:      1px solid brandNavy atau warna kontekstual
Background:  transparent atau tinted (withOpacity 0.07)
Text:        brandNavy atau warna kontekstual, weight 700
Radius:      10px
```

#### Text Button
```
Digunakan hanya untuk aksi sekunder ringan (Lihat Semua, Reset)
Text:        11–12px, weight 700, brandNavy
Padding:     minimal
```

#### Danger Button
```
Background:  AppColors.danger (merah)
Hanya untuk aksi destruktif: Keluar, Tolak, Hapus
Selalu muncul berpasangan dengan tombol Batal
```

### 4.2 Cards (SectionCard)

```
Background:     white
Border Radius:  14–16px
Border:         1px solid slate200 (opsional, tergantung konteks)
Shadow:         BoxShadow(color: brandNavy.withOpacity(0.04–0.06), blurRadius: 8–12, offset: Offset(0, 2–4))
Padding:        16px semua sisi (default)
```

**Aturan:**
- Shadow harus **sangat subtle** — jika terlihat jelas, terlalu kuat
- Jangan gunakan card di dalam card
- Card dengan border lebih cocok untuk konten informasi; card tanpa border lebih cocok untuk action group
- `SectionCard` dengan warna custom (`color` parameter) digunakan untuk status alert — gunakan warna brand dengan opacity rendah (0.05–0.10), bukan warna solid

### 4.3 AppBar / Custom Header

Hadir-In menggunakan dua pola AppBar:

**Pola A — Tab Header (Home, Leave, Salary, Account):**
```dart
Container(
  color: AppColors.white,
  padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
  child: Column(
    children: [
      Text('SECTION NAME', /* 10px, weight 700, brandNavy, letterSpacing 1.2 */),
      Text('Page Title',   /* headline2, slate900 */),
    ],
  ),
)
// + Divider 1px slate200 di bawah
```

**Pola B — Push Screen Header (History, Salary Detail, dll):**
```dart
AppBar(
  backgroundColor: white,
  elevation: 0,
  leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: slate700)),
  title: Column(/* section label + page title */),
  bottom: PreferredSize(/* 1px divider slate200 */),
)
```

**Aturan:**
- Selalu gunakan `elevation: 0` dengan border bawah manual (`slate200`, tinggi 1px) — tidak menggunakan shadow default AppBar
- Icon back selalu `arrow_back_ios_new_rounded`, ukuran 18–20px, warna `slate700` atau `brandNavy`
- Tidak ada AppBar yang menggunakan background selain `white`

### 4.4 Bottom Navigation

```
Background:  white
Height:      60px
Elevation:   8 dengan shadowColor brandNavy.withOpacity(0.1)
Active:      brandNavy (icon + text)
Inactive:    slate400
Font:        10px, weight 700 (active) / 400 (inactive)
Icon size:   22px
Label:       selalu tampil
FAB notch:   CircularNotchedRectangle, notchMargin: 8
```

**Aturan:**
- Hanya 4 tab (selain FAB slot): Home, Cuti & Izin, Gaji, Akun
- Tidak ada badge angka di icon nav — notifikasi ditangani di dalam screen tersendiri
- FAB selalu berada di tengah (`FloatingActionButtonLocation.centerDocked`)

### 4.5 Floating Action Button (FAB)

FAB di Hadir-In bersifat **contextual dan stateful**, bukan ornamental:

| Status | Warna | Icon |
|---|---|---|
| notCheckedIn | brandNavy | fingerprint_rounded |
| checkedIn / breakEnded | brandNavy | fingerprint_rounded |
| onBreak | `#E67E22` (orange) | free_breakfast_rounded |
| checkedOut | slate400 | check_circle_rounded |

```
Size:        60x60px
Shape:       circle
Shadow:      fabColor.withOpacity(0.38), blurRadius 14, offset (0, 6)
```

### 4.6 Dialogs

```
Border Radius:  20px
Title padding:  fromLTRB(24, 24, 24, 8)
Content:        body2 style, slate600
Actions:        TextButton (batal) + ElevatedButton (konfirmasi)
Icon (opsional): emoji besar atau Icon widget dalam Container circle
```

**Aturan:**
- Selalu ada opsi "batal" sebelum aksi destruktif
- Gunakan emoji sebagai icon dialog untuk kesan yang lebih personal dan kurang "corporate" (contoh: `'⏰'`, `'🌙'`)
- Jangan gunakan `showGeneralDialog` — gunakan `showDialog` dengan `AlertDialog`

### 4.7 Form Fields

```
fillColor:       white
Filled:          true
Border radius:   10px (via OutlineInputBorder)
Border default:  slate200
Border focused:  brandNavy atau brandCyanDark
Hint text:       slate400
Prefix icon:     slate600 (default)
```

**Aturan:**
- Label field selalu berada di **atas** field (bukan sebagai floating label)
- Label: `AppText.label` style (12px, weight 700, slate700)
- Gap antara label dan field: `SizedBox(height: 6)`
- Jangan gunakan `TextFormField` tanpa validator jika field ada dalam form

### 4.8 Chips & Pills

Digunakan untuk filter, status tag, dan info tambahan:

```
Padding:       horizontal 8–14px, vertical 3–7px
Border Radius: 20px (selalu rounded pill)
Border:        opsional, 1px warna kontekstual dengan opacity
Font:          9–12px, weight 600–800
```

| Jenis | Background | Text |
|---|---|---|
| Status aktif/filter | brandNavy | white |
| Status normal | slate100–slate300 | slate600 |
| Success badge | brandLime.withOpacity(0.2) | brandLimeDark |
| Info badge | brandCyan.withOpacity(0.2) | brandCyanDark |
| Warning badge | warning.withOpacity(0.1) | warning |
| Danger badge | danger.withOpacity(0.1) | danger |

### 4.9 List Items & Tiles

**Settings/Menu item (dari AccountTab):**
```
Padding:   horizontal 16px, vertical 14px
Icon:      dalam Container 36x36px, radius 10px, background slate100
Icon size: 18px, warna slate600
Label:     14px, weight 600, slate900
Subtitle:  body2 (11px)
Trailing:  Icon chevron_right atau Switch atau custom widget
Divider:   AppDivider antara item (kecuali item terakhir)
```

**List item kehadiran (HistoryScreen):**
```
Container  white, radius 14px, border slate100, shadow subtle
Tanggal kotak: 48x52px, radius 10px, background brandNavy
Check-in/out:  column kecil label + value monospace
Status badge:  pill kecil di kanan
```

### 4.10 Bottom Sheet / Modal

```
Border radius:  vertical top Radius.circular(20)
Drag handle:    36x4px, radius 2px, slate300, di-center
Padding:        fromLTRB(24, 16, 24, 32)
Title:          headline3
Content:        body1/body2
```

**Aturan:**
- Selalu tampilkan drag handle
- Gunakan `isScrollControlled: true` jika modal berisi form (agar keyboard tidak menimpa)
- `SafeArea` atau `viewInsets.bottom` untuk jarak dari keyboard

### 4.11 Empty States

```
Icon:     48–64px, slate300 (tidak berwarna)
Text:     body2 atau headline3, slate600
Subtitle: body2, slate600
Action:   TextButton (opsional, hanya jika ada aksi yang bisa dilakukan)
```

**Aturan:**
- Jangan gunakan animasi lottie yang berlebihan — icon Material + teks sudah cukup
- Pesan harus spesifik, bukan generik "Tidak ada data"

### 4.12 Status Badge (StatusBadge widget)

```dart
StatusBadge(label: 'HADIR', color: AppColors.brandLimeDark)
// Background: color.withOpacity(0.15)
// Text: color, 9–10px, weight 700, letterSpacing 0.3–0.5
// Radius: 20px (pill)
// Padding: horizontal 8–10px, vertical 3–4px
```

---

## 5. Color Usage Rules

> Selalu merujuk pada `COLOR-PALETTE.md` untuk definisi warna penuh.

### 5.1 Hierarki Penggunaan Warna

```
Layer 1 (Background):   slate50  — latar layar
Layer 2 (Surface):      white    — card, AppBar, BottomNav
Layer 3 (Elevated):     white + shadow — modal, dialog
Layer 4 (Brand):        brandNavy — aksi utama, header, elemen identitas
Layer 5 (Accent):       brandCyan, brandLime — status, highlight, secondary action
```

### 5.2 Aturan Per Warna

**brandNavy (`#2D377F`)**
- Primary button background
- AppBar section label
- Active nav icon
- FAB (default state)
- Section icon color
- Heading text alternatif (jika dipakai sebagai teks, pastikan di atas background cerah)

**brandCyan (`#4DD0E1`)**
- Info badge background (dengan opacity)
- Interactive element highlight
- Izin/leave accent color
- Jangan gunakan sebagai teks di atas background putih (kontras tidak cukup)

**brandLime (`#9CCC65`) & brandLimeDark (`#7CB342`)**
- Success state: check-in berhasil, pengajuan disetujui, lokasi terverifikasi
- Positive metric
- FAB status "breakEnded"
- Badge "VERIFIED", "HADIR", "TEPAT WAKTU"

**slate50–slate300:** Backgrounds, borders, disabled, placeholder
**slate600–slate900:** Text pada berbagai level

**Semantic:**
| Warna | Hex | Penggunaan |
|---|---|---|
| `success` | `brandLimeDark` | Hadir, approved, verified |
| `warning` | `#FFC107` | Terlambat, pending, alert |
| `danger` | `#F44336` | Absen, rejected, error, logout |
| `info` | `brandCyanDark` | Info neutral, izin |

### 5.3 Aturan Opacity

Opacity digunakan untuk membuat variasi warna yang harmonis. Aturan:

| Konteks | Opacity |
|---|---|
| Background tinted card | 0.04–0.08 |
| Badge background | 0.10–0.20 |
| Border / garis tipis | 0.15–0.30 |
| Icon container background | 0.08–0.15 |
| Shadow | 0.04–0.10 |

> **Hindari opacity di bawah 0.04** — tidak terlihat. Hindari di atas 0.30 untuk background — terlalu mencolok.

### 5.4 Kombinasi yang Dilarang

- **Cyan text di atas background putih** — kontras tidak cukup (WCAG fail)
- **Lime text di atas background putih** — kontras tidak cukup
- **Dua warna brand mencolok berdampingan** (misalnya cyan button di sebelah lime button)
- **Navy background dengan cyan background** dalam satu card yang sama
- **Gradient yang tidak ada dalam `COLOR-PALETTE.md`**

---

## 6. Natural UI Principles

Ini adalah sekumpulan prinsip yang membedakan UI yang terlihat "dibuat manusia" dari UI yang terlihat "di-generate AI."

### 6.1 Asymmetry yang Disengaja

- Tidak semua section harus memiliki ukuran card yang sama
- Row yang berisi dua elemen tidak harus selalu 50/50 — gunakan `Expanded` + `Flexible` secara kontekstual
- Icon pada menu item tidak harus selalu ukuran dan warna yang identik jika konteks berbeda

### 6.2 Whitespace yang Bermakna

- Whitespace bukan "ruang kosong yang terbuang" — whitespace adalah bagian dari desain
- Section yang lebih penting boleh mendapat whitespace lebih besar di atasnya
- Jangan menambahkan elemen hanya karena ruang terasa kosong

### 6.3 Variasi Natural dalam Pengulangan

- List item memang harus konsisten secara struktur, tetapi boleh memiliki sedikit variasi pada detail (badge berbeda warna, icon berbeda) sesuai data
- Tidak semua card harus memiliki icon — terkadang teks saja cukup
- Tidak semua section harus memiliki "Lihat Semua" button

### 6.4 Hierarchy yang Terasa, Bukan Dihitung

- Ukuran font yang berbeda harus terasa berbeda secara visual, bukan hanya secara angka (28px vs 14px, bukan 14px vs 13px)
- Gunakan weight (bold vs regular) lebih agresif daripada menambah ukuran font
- Elemen yang paling penting di satu screen harus langsung menarik mata dalam 3 detik

### 6.5 Teks yang Bernyawa

- Gunakan bahasa yang natural dan personal (contoh sudah ada: `"Selamat Datang! 👋"`, `"Selamat bekerja kembali! 💪"`)
- Emoji diperbolehkan secara selektif untuk konteks yang tepat — bukan dekorasi, tapi ekspresi
- Pesan error/warning harus spesifik dan actionable, bukan generik

### 6.6 Komponen yang Merespons Konteks

- Warna tombol, teks, dan icon HARUS berubah sesuai state — contoh terbaik: FAB yang berubah warna sesuai status absensi
- Elemen disabled HARUS terlihat jelas disabled (slate300, bukan hanya opacity-reduce)
- Jangan tampilkan tombol yang tidak bisa diklik tanpa penjelasan

---

## 7. Animation & Interaction

### 7.1 Prinsip Animasi

- **Subtle:** Animasi tidak pernah menjadi pusat perhatian
- **Purposeful:** Setiap animasi harus memiliki fungsi (feedback, transisi, emphasis)
- **Fast:** Pengguna tidak menunggu animasi selesai untuk berinteraksi

### 7.2 Duration Guidelines

| Konteks | Duration |
|---|---|
| Micro interaction (button press, chip select) | 100–150ms |
| Component appear / disappear | 200–300ms |
| Page transition | 300–400ms |
| Complex animation (slide + fade masuk) | 400–600ms |
| Loop animation (mascot bounce, pulse) | 1000–1200ms |
| Deep research / loading yang lama | gunakan skeleton, bukan spinner |

### 7.3 Easing Curves

| Konteks | Curve |
|---|---|
| Elemen masuk ke layar | `Curves.easeOut` |
| Elemen keluar dari layar | `Curves.easeIn` |
| Bounce / elastic (logo masuk, mascot) | `Curves.elasticOut` |
| Timer / progress | `Curves.linear` |
| Accordion expand/collapse | `Curves.easeInOut` |

### 7.4 Transition yang Ada

Pertahankan pattern transisi yang sudah ada:

- **Login screen:** Slide + Fade (`Offset(0, 0.12)` → `Offset.zero`)
- **Logo/Mascot masuk:** Scale elastic + Fade
- **Notification list item:** Fade + Translate Y (staggered per item)
- **Break screen circular timer:** Pulse scale (0.96–1.04)
- **Accordion:** `AnimatedRotation` untuk chevron, `AnimatedContainer` untuk border

### 7.5 Feedback Haptic

```dart
HapticFeedback.heavyImpact()  // Alert penting (5 menit sebelum selesai istirahat)
HapticFeedback.mediumImpact() // Aksi selesai (break done)
// Jangan gunakan haptic untuk aksi rutin (button tap biasa)
```

### 7.6 Loading States

- **Inline loading (button):** `isLoading: true` → tampilkan `SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: white))`
- **Full screen loading:** Hanya untuk `AuthWrapper` (SplashScreen)
- **List loading:** Tidak ada skeleton UI saat ini — jika ditambahkan, gunakan `shimmer` dengan warna `slate100`→`slate200`
- **Jangan gunakan `showDialog` loading** — user tidak bisa membatalkan

---

## 8. Screen-by-Screen Notes

### 8.1 HomeTab

**Yang sudah baik:**
- Greeting card yang berubah dinamis sesuai status — natural dan personal
- Timeline 2×2 grid dengan info real-time — informatif dan ringkas
- Attendance history card yang kaya informasi namun tetap scannable

**Yang perlu diperhatikan:**
- `_buildCheckinBlockedAfterNoon()` terasa padat — pertimbangkan mengurangi teks instruksi dan memperbesar area visual
- History card berisi terlalu banyak info dalam satu baris — pada resolusi kecil bisa overflow. Tambahkan `overflow: TextOverflow.ellipsis` di tempat yang rentan.
- `_buildCurrentActivityCard()` bisa lebih menonjol secara visual untuk membedakan status "kerja aktif" vs "istirahat" — pertimbangkan background warna yang sedikit lebih dalam

**Hierarki yang perlu diperkuat:**
- Tombol Check-In (hero card besar) → sudah baik
- Tapi tombol "Istirahat" terlihat mirip disabled meskipun aktif — warna `slate100` terlalu mirip disabled state. Pertimbangkan `brandCyan` tinted saat break aktif.

### 8.2 LoginScreen

**Yang sudah baik:**
- Animasi mascot bounce yang looping — personal dan tidak berlebihan
- Slide + fade untuk form — smooth
- Re-verify mode yang berbeda dari initial login — logis

**Yang perlu diperhatikan:**
- Pada mode re-verify, terlalu banyak whitespace di atas form sebelum heading. Pertimbangkan mengurangi padding top.
- Banner info biru di bawah ("Gunakan ID Karyawan...") sedikit redundant jika sudah ada placeholder pada field — evaluasi apakah perlu.

### 8.3 LeaveTab (Cuti & Izin)

**Yang sudah baik:**
- Accordion pattern untuk Cuti dan Izin — menghindari layar yang terlalu panjang
- Verify gate yang bersih dan fungsional
- Supervisor accordion dengan pending count badge — informative

**Yang perlu diperhatikan:**
- Form Cuti dan Izin di dalam accordion terasa padat. Pertimbangkan sedikit menambah spacing antar elemen form (`SizedBox(height: 16)` → `20px`)
- Pills jenis izin pada accordion header menggunakan `slate100` background yang hampir tidak terlihat pada background putih card — tambahkan opacity atau border lebih jelas
- Section "Riwayat Pengajuanmu" sering tampil kosong (hanya 7 hari) — teks empty state perlu lebih explanatory

### 8.4 SalaryScreen

**Yang sudah baik:**
- Hero card navy dengan gaji bersih yang besar — visual yang kuat dan jelas
- Grid 2×2 untuk komponen gaji — efisien
- Month selector dropdown yang clean

**Yang perlu diperhatikan:**
- `SalaryDetailScreen` sangat padat. Tabel pendapatan dan potongan langsung berdampingan tanpa visual separator yang cukup — tambahkan `SizedBox(height: 24)` yang lebih konsisten antar tabel
- Tombol "Download PDF" di AppBar bersaing perhatian dengan konten — pertimbangkan memindahkan ke bawah konten sebagai tombol full-width
- Grid card gaji pokok di `_buildSalarySetting()` menggunakan `childAspectRatio: 1.1` — pada teks panjang bisa overflow. Gunakan nilai yang lebih longgar (0.95–1.0).

### 8.5 AccountTab

**Yang sudah baik:**
- Profile section dengan avatar inisial — clean
- Stat chips (ID, Sisa Cuti, Shift) — informatif tanpa berlebihan
- Section grouping dengan icon + label — hierarchi jelas

**Yang perlu diperhatikan:**
- Ada terlalu banyak section (Akun, Konten & Tampilan, Dukungan, Keamanan, Tentang). Pertimbangkan untuk collapse beberapa yang jarang digunakan atau gabungkan "Dukungan" dan "Tentang Aplikasi"
- Item menu dengan `showDivider: false` pada item terakhir sudah benar — pastikan konsisten di semua section
- "Keunggulan Hadir-In" bottom sheet menggunakan tuple `(String, String, String)` — pattern ini bisa diganti dengan class kecil agar lebih maintainable

### 8.6 HistoryScreen

**Yang sudah baik:**
- Filter dropdown + date range picker — powerful namun tidak overly complex
- "Reset" button yang muncul hanya saat ada filter aktif — contextual
- Result count banner — sangat membantu

**Yang perlu diperhatikan:**
- Filter row dengan dropdown dan date picker agak tight pada screen kecil. Pertimbangkan minimal `60px` height untuk masing-masing filter control.
- Warna status emoji sebagai icon container cukup menarik — pertahankan pattern ini

### 8.7 NotificationScreen

**Yang sudah baik:**
- Filter chip horizontal scroll — clean dan accessible
- Staggered animation per item — natural
- Swipe to dismiss — familiar pattern

**Yang perlu diperhatikan:**
- Background `slate300` untuk unread notification (bukan `slate50`) membuat kontrast terlalu gelap vs item yang sudah dibaca. Pertimbangkan menggunakan `brandNavy.withOpacity(0.04)` sebagai unread indicator, dan dot biru saja sudah cukup.
- Filter chip menggunakan `AppColors.slate300` sebagai background non-selected — ini lebih gelap dari biasanya. Pertimbangkan `slate100`.

### 8.8 BreakScreen

**Yang sudah baik:**
- Circular progress indicator yang besar sebagai countdown — visual yang tepat untuk screen ini
- Pulse animation — subtle dan sesuai
- 5-minute warning dialog — fungsional

**Yang perlu diperhatikan:**
- Screen ini cukup ideal — hindari menambahkan elemen. Satu catatan: mascot di atas timer sedikit bersaing perhatian dengan countdown. Evaluasi apakah mascot perlu ukurannya dikurangi (60px vs 80px saat ini).

### 8.9 CameraCheckinScreen

**Yang sudah baik:**
- Full-screen camera dengan overlay yang informatif namun tidak menghalangi
- Oval face guide — standard dan familiar
- Confirm overlay dengan detail lokasi — transparan dan informatif

**Yang perlu diperhatikan:**
- Confirm overlay menampilkan `Image.network(_capturedFile!.path)` — ini akan gagal di production karena XFile path bukan URL. Harus menggunakan `Image.file(File(_capturedFile!.path))`.
- Info bar bawah (waktu + lokasi) memiliki `Colors.black.withOpacity(0.42)` background — pastikan cukup kontras pada semua kondisi cahaya.

---

## 9. UI Anti-Pattern List

Daftar hal yang **WAJIB DIHINDARI** dalam pengembangan UI Hadir-In:

### ❌ Layout & Structure

- **Card di dalam card** — menambah visual noise tanpa nilai tambah
- **Lebih dari tiga level heading dalam satu screen** — membingungkan hierarki
- **Padding yang tidak konsisten** antara screen yang seharusnya sama pola
- **Column yang tidak dibungkus SingleChildScrollView** pada screen yang bisa overflow keyboard
- **Widget yang tidak ada SafeArea-nya** pada screen yang custom AppBar

### ❌ Warna & Visual

- **Gradient yang tidak ada dalam COLOR-PALETTE.md** — merusak brand consistency
- **Shadow yang terlihat jelas** (blurRadius > 20, opacity > 0.15 untuk card normal)
- **Dua warna brand solid berdampingan** (misalnya cyan button + lime button)
- **Warna background yang terlalu saturated** untuk area yang luas
- **Warna teks yang tidak memenuhi kontras WCAG AA** (4.5:1 untuk teks normal)
- **Opacity warna yang terlalu rendah** (< 0.04) sehingga tidak terlihat

### ❌ Typography

- **Lebih dari empat ukuran font berbeda dalam satu screen**
- **Font size di bawah 9px** untuk teks yang diharapkan dibaca
- **Teks tanpa overflow handling** untuk konten dinamis
- **Bold pada semua elemen** — kehilangan hierarki visual
- **Letter spacing pada body text** — hanya untuk uppercase label kecil

### ❌ Komponen

- **Primary button lebih dari satu per section**
- **Button tanpa loading state** untuk aksi yang membutuhkan waktu
- **Dialog tanpa tombol batal** untuk aksi destruktif
- **Form field tanpa validator** dalam Form widget
- **Icon yang terlalu besar** untuk konteks (>30px di dalam card kecil)
- **Disabled button tanpa penjelasan** mengapa disabled

### ❌ Animasi

- **Duration animasi > 600ms** untuk transisi UI biasa
- **Loop animation yang tidak bisa dihentikan** (selain timer/countdown)
- **Animasi yang menghalangi interaksi pengguna**
- **Haptic feedback pada aksi yang tidak kritis**

### ❌ Desain "AI Aesthetic"

- **Semua card berukuran identik** dalam sebuah screen
- **Spacing yang terlalu perfect** — setiap elemen berjarak sama persis
- **Setiap section memiliki icon, badge, dan divider** tanpa mempertimbangkan kebutuhan
- **Warna gradient yang terlalu kaya** (multi-stop, neon-like)
- **Terlalu banyak warna dalam satu screen** (> 4 warna berbeda)
- **Layout yang sama persis** antara semua list item tanpa variasi kontekstual

---

## 10. Final UI Standard Checklist

Gunakan checklist ini sebelum PR/merge untuk setiap screen baru atau perubahan UI signifikan.

### 🎨 Warna & Brand

- [ ] Warna yang digunakan ada dalam `COLOR-PALETTE.md`
- [ ] Text di atas background memenuhi kontras minimum WCAG AA
- [ ] Tidak ada warna baru yang ditambahkan tanpa alasan kuat
- [ ] Semantic color digunakan dengan benar (lime=success, danger=error, dll)

### 📐 Layout & Spacing

- [ ] Screen edge padding konsisten (20px horizontal)
- [ ] Bottom padding cukup untuk konten di atas BottomNav (min 100px)
- [ ] SafeArea digunakan dengan benar
- [ ] Tidak ada card di dalam card
- [ ] Whitespace terasa natural, tidak terlalu padat atau terlalu kosong

### 🔤 Typography

- [ ] Tidak lebih dari 4 ukuran font berbeda per screen
- [ ] Semua teks dinamis memiliki `maxLines` dan `overflow` handling
- [ ] Font weight digunakan untuk membangun hierarki
- [ ] Font size minimum 9px untuk teks yang dibaca user

### 🧩 Komponen

- [ ] AppBar mengikuti Pola A atau Pola B yang sudah ditetapkan
- [ ] Button primary hanya satu per section
- [ ] Semua button dengan aksi async memiliki loading state
- [ ] Form field memiliki validator
- [ ] Dialog destruktif selalu memiliki tombol batal
- [ ] Empty state ada untuk list yang bisa kosong

### 🎭 State Management

- [ ] Semua state visual (loading, empty, error, success) di-handle
- [ ] Disabled state jelas terlihat (slate300, bukan hanya opacity)
- [ ] Komponen merespons state dengan benar (warna, icon, teks berubah)

### ✨ Natural Feel

- [ ] UI tidak terasa seperti template — ada karakter yang sesuai konteks screen
- [ ] Teks menggunakan bahasa yang personal dan natural (bukan "No data found")
- [ ] Animasi subtle dan purposeful, tidak flashy
- [ ] Tidak ada elemen yang terasa "ditempatkan untuk mengisi ruang"

### 📱 Production Readiness

- [ ] Tidak ada debug print atau placeholder text
- [ ] Semua navigator pop/push menggunakan route yang benar
- [ ] Tidak ada hardcoded string yang seharusnya dinamis
- [ ] Screen berfungsi pada resolusi 360px width (small phone) dan 414px+ (large phone)
- [ ] Keyboard tidak menimpa form field penting

---

## Appendix: Quick Reference — AppText Styles

Berdasarkan analisis penggunaan di seluruh file dart, berikut ringkasan style teks yang konsisten:

```dart
// AppText (dari theme/app_theme.dart — referensi implementasi nyata)
AppText.headline2  → fontSize: ~20-22, fontWeight: w800, color: slate900
AppText.headline3  → fontSize: ~16-18, fontWeight: w700, color: slate900
AppText.label      → fontSize: 12, fontWeight: w700, color: slate700/brandNavy
AppText.body1      → fontSize: 14, fontWeight: w500-600, color: slate900
AppText.body2      → fontSize: 12-13, fontWeight: w400, color: slate600
AppText.caption    → fontSize: 10-11, fontWeight: w500-600, color: slate400-slate600
```

## Appendix: Quick Reference — Common Patterns

```dart
// Section header pattern (digunakan di AccountTab, HomeTab, dll)
Row(children: [
  Icon(icon, color: AppColors.brandNavy, size: 16),
  SizedBox(width: 6),
  Text(title, style: GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w700,
    color: AppColors.brandNavy, letterSpacing: 0.5,
  )),
])

// Page header pattern (semua tab utama)
Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text('SECTION NAME', style: GoogleFonts.inter(
    fontSize: 10, fontWeight: FontWeight.w700,
    color: AppColors.brandNavy, letterSpacing: 1.2,
  )),
  Text('Page Title', style: AppText.headline2.copyWith(color: AppColors.slate900)),
])

// AppDivider: 1px height, color: slate200
// SectionCard: white, radius 14-16px, subtle shadow
// StatusBadge: pill shape, kontekstual warna
```

---

*Dokumen ini diperbarui terakhir bersamaan dengan analisis codebase. Setiap penambahan screen atau komponen baru harus diikuti dengan update pada dokumen ini.*

*Versi: 1.0.0 | Project: Hadir-In Staff App Flutter*
