import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/attendance_provider.dart'; // ← shared state
import '../services/attendance_service.dart';
import '../services/profile_service.dart';
import '../services/document_service.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/calendar_service.dart';
import '../services/staff_log_service.dart';
import '../services/notification_service.dart';
import '../services/notification_menu_hints.dart';
import '../services/push_notification_service.dart';
import '../services/fcm_service.dart';
import '../services/document_draft_service.dart';
import '../widgets/staff_log_dialog.dart';
import '../widgets/open_session_dialog.dart';
import '../widgets/early_checkout_dialog.dart';
import '../screens/camera_checkin_screen.dart'; // ← halaman kamera
import '../models/models.dart';
import 'login_screen.dart';
import 'home_tab.dart';
import 'leave_tab.dart';
import 'salary_screen.dart';
import 'account_tab.dart';
import 'manager_dashboard_tab.dart';
import 'onboarding_documents_screen.dart';
import 'notification_screen.dart';

/// Bottom-nav wrapper — Home | Leave & Time Off | [FAB] | Salary | Account
///
/// Admin hanya punya 2 tab: Dashboard & List Absensi (no FAB)
///
/// FAB behaviour berdasarkan [AttendanceProvider._status] (untuk non-admin):
///  • notCheckedIn  → buka kamera (check-in)
///  • checkedIn     → buka kamera (check-out) — tombol istirahat ada di HomeTab
///  • onBreak       → alert "Selesai Istirahat?" (tanpa kamera)
///  • breakEnded    → buka kamera (check-out)
///  • checkedOut    → FAB disabled / info sudah selesai
class MainScreen extends StatefulWidget {
  final int initialTab;
  const MainScreen({super.key, this.initialTab = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _tab;

  /// Pemeriksa absensi: batas maksimal lembur terlewat, dan sesi yang
  /// belum di-checkout (lupa break-out/check-out).
  Timer? _guardTimer;

  /// Dialog "belum check-out" sedang tampil — mencegah timer menumpuknya.
  bool _openSessionDialogShown = false;

  /// AttendanceProvider diinisialisasi di sini agar bisa dibagikan ke
  /// seluruh widget tree melalui [InheritedAttendance].
  final AttendanceProvider _attendance = AttendanceProvider();

  // Status hidrasi profil staff dari backend.
  bool _loadingProfile = true;
  String? _profileError;

  /// Gerbang onboarding: true = dokumen wajib belum lengkap, app belum boleh
  /// dibuka. Lihat [_hydrateProfile].
  bool _needsOnboarding = false;

  bool get _isAdmin => AppSession.isAdmin;

  // ── Notifikasi: polling + candy-bar banner (2026-09-07, Fase 6 PHASE 1) ──
  //
  // Polling + banner in-app selagi app di-foreground. Sisi PUSH-nya (app
  // di-background/ditutup) sudah jalan sejak 2026-09-08 di
  // `services/fcm_service.dart`.
  //
  // Polling TETAP dipertahankan walau FCM sudah jalan (2026-09-08) --
  // bukan cuma soal push, polling juga satu-satunya sumber data untuk
  // layar Notifikasi & badge unread count, keduanya tidak lahir dari
  // event push. Notifikasi TRAY kembar antara kedua jalur dicegah lewat id
  // notifikasi yang sama (`PushNotificationService.idFor`); banner in-app
  // (SnackBar) di `_pollNotifications` di bawah punya pengecekan dedup-nya
  // SENDIRI (`NotificationCenter.isShown`, Fase 1.1) -- keduanya sengaja
  // dicek terpisah karena awalnya memang tidak saling kenal.
  Timer? _notifPollTimer;
  final Set<String> _seenNotifIds = {};
  bool _notifSeeded = false;

  void _startNotificationPolling() {
    // `_hydrateProfile` bisa dipanggil ulang (tombol "Coba Lagi" di
    // `_ProfileErrorView`) -- guard biar timer lama gak nyala dobel.
    if (_notifPollTimer != null) return;
    _pollNotifications(); // pull pertama: sekadar men-seed _seenNotifIds
    _notifPollTimer = Timer.periodic(
        const Duration(seconds: 45), (_) => _pollNotifications());
  }

  /// SATU penarikan notifikasi yang menyuapi DUA kanal:
  ///
  ///   • banner candy-bar in-app (kode di bawah) — terlihat saat staff
  ///     sedang memandangi app, hilang sendiri setelah 4 detik, dan
  ///   • notifikasi HP di status bar ([NotificationCenter]) — yang tetap
  ///     ada untuk dibuka nanti, termasuk saat app cuma di background.
  ///
  /// Keduanya sengaja tetap ada (transient vs persisten), tapi penarikan
  /// HTTP-nya cukup sekali: sebelum penggabungan ini ada dua timer terpisah
  /// (45 detik & 2 menit) yang memukul endpoint yang sama dengan jadwal
  /// berbeda. Penanda "sudah pernah dilihat"-nya memang beda dan itu
  /// disengaja — `_seenNotifIds` di memori berarti "baru sejak app dibuka"
  /// (untuk banner), sedangkan milik [NotificationCenter] tersimpan di disk
  /// dan berarti "belum pernah dimunculkan di HP ini sama sekali".
  Future<void> _pollNotifications() async {
    try {
      final result = await NotificationService.myNotifications();
      if (!mounted) return;

      if (!_notifSeeded) {
        // Backlog yang sudah ada saat app dibuka TIDAK di-banner-kan satu
        // per satu -- hanya notifikasi yang BENAR-BENAR baru muncul sejak
        // polling ini mulai jalan.
        _seenNotifIds.addAll(result.items.map((n) => n.id));
        _notifSeeded = true;
        await NotificationCenter.syncFromServer(prefetched: result);
        return;
      }

      final fresh =
          result.items.where((n) => !_seenNotifIds.contains(n.id)).toList();
      _seenNotifIds.addAll(result.items.map((n) => n.id));

      // 2026-09-08 (Fase 1.1) -- dicek SEBELUM syncFromServer, bukan
      // sesudah: syncFromServer sendiri menandai setiap id fresh "sudah
      // dilihat" begitu ia selesai (dipakai penarikan berikutnya), jadi
      // kalau baru dicek SESUDAH, hasilnya SELALU true untuk semua id
      // fresh -- yang terdeteksi jadinya cuma "abis ditandai sync barusan",
      // bukan "sudah tampil lewat push SEBELUM poll ini jalan" seperti yang
      // dimaksud. Urutan ini yang bikin deteksinya benar.
      final shownByPush = <String, bool>{};
      for (final n in fresh) {
        shownByPush[n.id] = await NotificationCenter.isShown(n.id);
      }

      // Notifikasi HP — memakai hasil penarikan yang sama.
      await NotificationCenter.syncFromServer(prefetched: result);
      if (!mounted) return;

      for (final n in fresh) {
        // Sudah tampil sebagai notifikasi tray lewat push FCM (foreground
        // listener `FcmService.onMessage` sudah memanggil
        // `NotificationCenter.markShown` untuk kejadian ini) -- jangan
        // banner-kan lagi, staff sudah lihat sinyalnya sekali.
        if (shownByPush[n.id] == true) continue;
        _showNotificationBanner(n);
      }
    } catch (_) {
      // Best-effort -- gagal polling (mis. jaringan) tidak boleh mengganggu
      // staff dengan error, cukup dicoba lagi di siklus berikutnya.
    }
  }

  void _showNotificationBanner(AppNotification n) {
    if (!mounted) return;
    final tabIndex = n.target.staffTabIndex;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(n.title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text(
                    // Petunjuk menu ditempel di sini juga supaya banner,
                    // notifikasi HP, dan layar Notifikasi menyebut tujuan
                    // yang sama persis.
                    NotificationMenuHints.withHint(n.message, n.rawType,
                        title: n.title),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.brandNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 4),
      action: (!_isAdmin && tabIndex != null)
          ? SnackBarAction(
              label: 'Lihat',
              textColor: AppColors.brandLime,
              onPressed: () => _onTabTap(tabIndex),
            )
          : null,
    ));
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    WidgetsBinding.instance.addObserver(this);
    // Rebuild FAB ketika status berubah
    _attendance.addListener(() => setState(() {}));

    // Notifikasi HP: siapkan saluran + minta izin (Android 13+/iOS) sedini
    // mungkin, lalu arahkan ketukan notifikasi ke layar Notifikasi.
    PushNotificationService.onNotificationTap = _handleNotificationTap;
    PushNotificationService.init();

    // Ketukan push yang MEMBUKA app dari keadaan tertutup sudah ditangkap
    // FcmService sebelum layar ini ada, jadi tujuannya masih menggantung di
    // sana. Ditebus setelah frame pertama karena `_handleNotificationTap`
    // memakai Navigator, yang belum tersedia selama initState.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => FcmService.flushPendingTap());

    _hydrateProfile();
  }

  /// Ketukan pada notifikasi HP.
  ///
  /// Payload-nya berbentuk `notification:<rawType>:<id>` (lihat
  /// [NotificationCenter.syncFromServer]) — `rawType`-nya dipakai untuk
  /// menempuh deep-link yang SAMA dengan tombol "Lihat Detail" di dalam
  /// app, lewat [notificationTargetFromRawType]. Yang tidak punya tujuan
  /// (peringatan absensi lokal, tipe yang belum dikenal) jatuh ke layar
  /// Notifikasi — tetap lebih berguna daripada sekadar membuka app di tab
  /// terakhir.
  void _handleNotificationTap(String? payload) {
    if (!mounted) return;

    final rawType = _rawTypeFromPayload(payload);
    if (rawType != null && !_isAdmin) {
      final tabIndex = notificationTargetFromRawType(rawType).staffTabIndex;
      if (tabIndex != null) {
        _onTabTap(tabIndex);
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationScreen(
          onNavigate: (target) {
            final tabIndex = target.staffTabIndex;
            if (tabIndex != null && !_isAdmin) _onTabTap(tabIndex);
          },
        ),
      ),
    );
  }

  /// `notification:<rawType>:<id>` → `<rawType>`. Null untuk payload lain
  /// (mis. `local:<key>` milik peringatan absensi) atau yang tidak berbentuk.
  static String? _rawTypeFromPayload(String? payload) {
    if (payload == null || !payload.startsWith('notification:')) return null;
    final parts = payload.split(':');
    if (parts.length < 3) return null;
    final rawType = parts[1];
    return rawType.isEmpty ? null : rawType;
  }

  /// Muat kalender kerja (hari libur + status hari ini + jam shift) lalu
  /// hidrasi AttendanceRules. Best-effort: kegagalan memuat TIDAK boleh
  /// memblokir app — `WorkCalendar.empty` menjawab "boleh absen" dan server
  /// tetap memvalidasi ulang saat check-in.
  Future<void> _loadWorkCalendar() async {
    try {
      final calendar = await CalendarService.load();
      AppCalendar.set(calendar);
      AttendanceRules.hydrateFromShift(
        jamMasuk: calendar.jamMasuk,
        jamPulang: calendar.jamPulang,
        jamIstirahatMulai: calendar.jamIstirahatMulai,
        jamIstirahatSelesai: calendar.jamIstirahatSelesai,
        toleransiPulangMenit: calendar.toleransiPulang,
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// Muat ulang kalender bila tanggalnya sudah berganti sejak terakhir
  /// dimuat — lihat [AppCalendar.isStale] untuk kenapa ini perlu.
  Future<void> _refreshCalendarIfStale() async {
    if (!AppCalendar.isStale) return;
    await _loadWorkCalendar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // App baru dibuka lagi: tarik notifikasi baru dan periksa apakah ada
    // absensi yang menggantung selagi app tertutup — dua hal yang paling
    // mungkin berubah tanpa sepengetahuan app. Kalender ikut disegarkan bila
    // tanggalnya sudah berganti (status "hari ini libur/tidak" milik
    // kemarin tidak boleh dipakai hari ini).
    _refreshCalendarIfStale();
    _pollNotifications();
    _runAttendanceGuards();
  }

  /// Ambil profil staff asli dari backend & sinkronkan ke AppSession sebelum
  /// menampilkan konten, agar seluruh tab menampilkan data nyata.
  Future<void> _hydrateProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      await ProfileService.loadAndCache();

      // ── GERBANG ONBOARDING ───────────────────────────────────────────
      //
      // BUGFIX: gerbang ini dulu HANYA dipasang di login_screen, sehingga
      // setiap jalur masuk lain melewatinya begitu saja:
      //   • buka app dengan sesi masih aktif (auth_wrapper → MainScreen),
      //   • buka kunci dengan passcode (passcode_unlock_screen → MainScreen),
      //   • baru selesai membuat passcode (passcode_unlock_screen → MainScreen).
      // Akibatnya staff yang keluar app di tengah layar unggah dokumen bisa
      // masuk penuh ke aplikasi hanya dengan mengetik passcode-nya.
      //
      // Sekarang pemeriksaannya di sini — satu-satunya pintu menuju isi app —
      // jadi jalur masuk mana pun (termasuk yang dibuat nanti) ikut tergerbang.
      // Aturannya tetap milik server (`completed`): dokumen WAJIB harus sudah
      // pernah diunggah. Penolakan HRD tidak mengunci app lagi, hanya memicu
      // notifikasi untuk mengunggah ulang.
      var blocked = false;
      try {
        blocked = !(await DocumentService.onboardingStatus()).completed;
      } on ApiException {
        // Gagal memeriksa (mis. jaringan) bukan alasan mengunci staff di luar
        // app — biarkan masuk, pemeriksaan diulang saat app dibuka lagi.
        blocked = false;
      }
      if (blocked) {
        if (!mounted) return;
        setState(() {
          _loadingProfile = false;
          _needsOnboarding = true;
        });
        return;
      }

      // Fase 8: muat kalender kerja (hari libur + jam shift) dari database,
      // lalu hidrasi AttendanceRules. Ini yang mengganti konstanta hardcode
      // `normalCheckoutHour = 24` dengan jam pulang shift yang sebenarnya.
      // Best-effort: gagal memuat kalender tidak boleh memblokir app.
      await _loadWorkCalendar();

      // Batas maksimal lembur staff ini (Jabatan.maxExtraHour), dipakai
      // kartu Aktivitas Hari Ini & peringatan "saatnya check-out".
      AttendanceRules.hydrateMaxLembur(AppSession.staff?.maxExtraHour);

      // Sinkronkan status absensi hari ini (best-effort, tidak memblokir).
      try {
        final today = await AttendanceService.today();
        _attendance.hydrateFromToday(today);
      } catch (_) {}

      if (!mounted) return;
      setState(() => _loadingProfile = false);

      // Notifikasi (banner + notifikasi HP) & pemeriksa absensi mulai
      // berjalan setelah profil ada — keduanya butuh staffId & jam shift.
      // Polling notifikasi jalan untuk staff MAUPUN admin, tapi tombol
      // "Lihat" pada banner hanya aktif untuk staff (Admin tidak punya tab).
      _startBackgroundWatchers();

      // Popup log (naik jabatan / surat peringatan) yang belum dibaca.
      _showPendingLogs();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = e.message;
      });
    }
  }

  void _startBackgroundWatchers() {
    _guardTimer?.cancel();

    // Notifikasi (banner + notifikasi HP) punya timernya sendiri di
    // [_startNotificationPolling] — satu penarikan tiap 45 detik untuk
    // kedua kanal.
    _startNotificationPolling();
    _runAttendanceGuards();

    // 3 menit: kejadian yang dijaga di sini berskala jam (jam pulang, batas
    // lembur, absensi kemarin), jadi tidak perlu presisi detik — cukup
    // muncul tanpa staff harus membuka tab tertentu. Pemeriksaan langsung
    // juga dilakukan setiap app di-resume, jadi kasus paling umum (HP dibuka
    // pagi berikutnya) tidak menunggu timer sama sekali.
    _guardTimer = Timer.periodic(
        const Duration(minutes: 3), (_) => _runAttendanceGuards());
  }

  /// Pemeriksa absensi — sumber dari dua notifikasi HP yang tidak ada di
  /// backend, karena keduanya soal apa yang TIDAK dilakukan staff:
  ///
  ///  1. batas maksimal lembur terlewat tapi belum check-out, dan
  ///  2. istirahat/absensi yang tidak pernah ditutup (termasuk yang
  ///     terbawa sampai hari berikutnya).
  Future<void> _runAttendanceGuards() async {
    if (!mounted || _loadingProfile || _needsOnboarding || _isAdmin) return;

    // App staff sering dibiarkan terbuka semalaman. Begitu tanggal berganti,
    // status "hari ini libur/boleh absen" milik kemarin harus dibuang dulu
    // sebelum guard & pengingat di bawah memakai kalender itu.
    await _refreshCalendarIfStale();
    if (!mounted) return;

    // (2) Sesi menggantung dari HARI SEBELUMNYA — diperiksa lebih dulu
    // karena ia menutupi pertanyaan lembur: kalau kemarin belum ditutup,
    // batas lembur hari ini tidak relevan.
    //
    // 2026-09-09 (product decision) — popup "Anda Belum Check-Out" HANYA
    // untuk `isPreviousDay` (staff genuinely lupa bermalam, harus ditutup
    // dulu sebelum bisa check-in lagi). Sesi HARI INI yang cuma lewat batas
    // lembur (`open != null` tapi bukan `isPreviousDay`) TIDAK memicu popup
    // ini — staff masih bisa lanjut kerja/istirahat/check-out manual kapan
    // pun, jadi jatuh ke pengingat (1) di bawah (notifikasi saja, tanpa
    // popup, tanpa auto-checkout).
    await _attendance.refreshOpenSession();
    final open = _attendance.openSession;
    if (open != null && open.isPreviousDay) {
      await NotificationCenter.alertOnce(
        key: 'open_session_${open.tanggal}',
        title: 'Anda Belum Check-Out',
        body: openSessionExplanation(open),
        type: 'attendance_missing_checkout',
      );
      await _promptCloseOpenSession(open);
      return;
    }

    // (1) Batas maksimal lembur.
    final stillWorking = _attendance.status != AttendanceProviderStatus.notCheckedIn &&
        _attendance.status != AttendanceProviderStatus.checkedOut;
    if (stillWorking && AttendanceRules.isPastOvertimeLimit) {
      await NotificationCenter.alertOnce(
        key: 'overtime_limit',
        title: 'Batas Maksimal Lembur Terlewat',
        body: 'Batas maksimal lembur sudah lewat, ini saatnya check-out dan '
            'istirahat. Lembur Anda hari ini sudah melewati '
            '${AttendanceRules.maxLemburJam} jam sejak jam pulang '
            '${AttendanceRules.jamPulangLabel}.',
        type: 'attendance_overtime_limit',
      );
    }

    // Sedang istirahat padahal jam pulang sudah lewat — pengingat lebih awal
    // supaya skenario "lupa break-out" tidak sampai jatuh ke auto-checkout.
    if (_attendance.isOnBreak && AttendanceRules.isAfterNormalCheckout) {
      await NotificationCenter.alertOnce(
        key: 'break_open_after_checkout',
        title: 'Istirahat Belum Ditutup',
        body: 'Anda masih tercatat istirahat padahal jam pulang '
            '${AttendanceRules.jamPulangLabel} sudah lewat. Tekan Break Out '
            'lalu Check-Out sebelum meninggalkan kantor.',
        type: 'break_reminder',
      );
    }

    await _runShiftReminders();
  }

  /// Sprint 3 Fase 4 (2026-09-08) — pengingat time-driven sepanjang hari
  /// kerja: sebelum check-in (T-15/T-5/tepat jam masuk/sudah telat), separuh
  /// shift belum istirahat, dan mendekati/lewat jam pulang. Dipisah dari
  /// [_runAttendanceGuards] karena guard di atas menjaga hal yang TIDAK
  /// dilakukan staff (sesi menggantung/lembur), sementara ini murni
  /// pengingat jadwal — keduanya jalan di timer/poll yang sama tapi tidak
  /// saling exclude satu sama lain.
  ///
  /// Tidak berlaku sama sekali (return awal) di 3 kondisi: hari libur, bukan
  /// hari kerja shift staff, atau staff sedang cuti/izin hari ini —
  /// mengulang jadwal kerja yang memang tidak berlaku hari itu cuma bikin
  /// notifikasi sampah.
  Future<void> _runShiftReminders() async {
    final now = DateTime.now();
    if (AppCalendar.instance.isHoliday(now) ||
        !AppCalendar.instance.isShiftWorkday(now)) {
      return;
    }
    if (_attendance.today?.status == AttendanceStatus.leave) return;

    final todayKey = WorkCalendar.dateKey(now);

    // ── Sebelum check-in: T-15, T-5, tepat jam masuk, sudah telat ──
    if (_attendance.status == AttendanceProviderStatus.notCheckedIn) {
      final untilMasuk = AttendanceRules.timeUntilMasuk;
      if (untilMasuk != null) {
        if (untilMasuk <= const Duration(minutes: 15) &&
            untilMasuk > const Duration(minutes: 5)) {
          await NotificationCenter.alertOnce(
            key: 'checkin_t15_$todayKey',
            title: '15 Menit Lagi Jam Masuk',
            body: 'Jam masuk shift Anda ${AttendanceRules.jamMasukLabel}. '
                'Bersiap check-in ya.',
            type: 'attendance_reminder_checkin',
          );
        } else if (untilMasuk <= const Duration(minutes: 5)) {
          await NotificationCenter.alertOnce(
            key: 'checkin_t5_$todayKey',
            title: '5 Menit Lagi Jam Masuk',
            body: 'Jam masuk shift Anda ${AttendanceRules.jamMasukLabel}. '
                'Segera menuju lokasi kerja.',
            type: 'attendance_reminder_checkin',
          );
        }
      }

      final late = AttendanceRules.lateSinceMasuk;
      if (late != null) {
        if (late <= const Duration(minutes: 10)) {
          await NotificationCenter.alertOnce(
            key: 'checkin_ontime_$todayKey',
            title: 'Sekarang Waktunya Check-In',
            body: 'Jam masuk shift Anda ${AttendanceRules.jamMasukLabel} '
                'sudah tiba. Jangan lupa check-in.',
            type: 'attendance_reminder_checkin',
          );
        } else if (late >= const Duration(minutes: 15)) {
          await NotificationCenter.alertOnce(
            key: 'checkin_late_$todayKey',
            title: 'Anda Belum Check-In',
            body: 'Jam masuk shift Anda ${AttendanceRules.jamMasukLabel} '
                'sudah lewat dan Anda belum check-in. Segera check-in.',
            type: 'attendance_reminder_late',
          );
        }
      }
    }

    // ── Separuh shift lewat, belum istirahat sama sekali ──
    if (_attendance.status == AttendanceProviderStatus.checkedIn &&
        (_attendance.today?.breakMinutes ?? 0) == 0 &&
        AttendanceRules.isPastHalfShift) {
      await NotificationCenter.alertOnce(
        key: 'halfshift_no_break_$todayKey',
        title: 'Belum Istirahat',
        body: 'Sudah separuh jam kerja hari ini dan Anda belum istirahat. '
            'Jangan lupa Break In saat sempat.',
        type: 'attendance_reminder_break',
      );
    }

    // ── Mendekati/pas/lewat jam pulang (push version dari kartu Home) ──
    // Sengaja EXCLUDE onBreak -- kasus itu sudah punya push sendiri
    // (`break_open_after_checkout` di atas) dengan pesan yang lebih spesifik
    // ("tutup istirahat dulu"), dobel notif buat kondisi yang sama kalau
    // disatukan.
    final workingStatuses = {
      AttendanceProviderStatus.checkedIn,
      AttendanceProviderStatus.breakEnded,
    };
    if (workingStatuses.contains(_attendance.status) &&
        AttendanceRules.isAfterNormalCheckout) {
      await NotificationCenter.alertOnce(
        key: 'checkout_reminder_$todayKey',
        title: 'Waktunya Check-Out',
        body: 'Jam pulang shift Anda ${AttendanceRules.jamPulangLabel} sudah '
            'tiba. Jangan lupa absen pulang.',
        type: 'attendance_reminder_checkout',
      );
    }
  }

  /// Tampilkan dialog penutup absensi yang menggantung, lalu tutup absensi
  /// itu bila staff menyetujuinya. Isi & aturannya ada di
  /// `widgets/open_session_dialog.dart` — dipakai bersama HomeTab supaya
  /// kedua pintu menuju check-in memberi penjelasan yang sama persis.
  Future<void> _promptCloseOpenSession(OpenAttendanceSession open) async {
    if (_openSessionDialogShown || !mounted) return;
    _openSessionDialogShown = true;
    final closed = await showOpenSessionDialog(context, _attendance, open);
    _openSessionDialogShown = false;
    if (!mounted || !closed) return;
    _showSuccessSnackbar(
        'Absensi ${open.tanggal} ditutup pada ${open.jamPulangShift}. '
        'Sekarang Anda bisa check-in kembali.');
  }

  /// Fase 8 — popup setelah login berhasil.
  ///
  /// Membaca `log_pesan` yang BELUM di-read (backend hanya mengembalikan
  /// yang itu), lalu menampilkannya berurutan: ucapan selamat naik jabatan
  /// dan/atau surat peringatan. Setelah ditutup, log ditandai read sehingga
  /// tidak muncul lagi.
  ///
  /// Best-effort: kegagalan memuat log tidak boleh mengganggu masuknya staff
  /// ke aplikasi.
  Future<void> _showPendingLogs() async {
    try {
      final logs = await StaffLogService.unread();
      if (!mounted || logs.isEmpty) return;
      await StaffLogDialog.showAll(context, logs);
    } catch (_) {}
  }

  Future<void> _logout() async {
    // Berkas dokumen yang belum diajukan dan penanda notifikasi terikat pada
    // staff yang sedang login — keduanya dibersihkan supaya tidak bocor ke
    // staff berikutnya yang memakai HP yang sama.
    await DocumentDraftService.clear();
    await NotificationCenter.reset();
    await SessionService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) =>
              const LoginScreen(destination: LoginDestination.landing)),
      (r) => false,
    );
  }

  @override
  void dispose() {
    _notifPollTimer?.cancel();
    _guardTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    PushNotificationService.onNotificationTap = null;
    _attendance.dispose();
    super.dispose();
  }

  void _onTabTap(int i) => setState(() => _tab = i);

  // ── FAB tap handler ──────────────────────────────────────────
  Future<void> _onFabTap() async {
    final status = _attendance.status;

    // Sudah check-out → tidak ada aksi
    if (status == AttendanceProviderStatus.checkedOut) {
      _showInfoSnackbar('Kamu sudah check-out hari ini. Sampai besok! 🌙');
      return;
    }

    // Sedang istirahat → alert selesai istirahat (tanpa kamera)
    if (status == AttendanceProviderStatus.onBreak) {
      await _showEndBreakDialog();
      return;
    }

    // Absensi hari sebelumnya belum ditutup → check-in baru tidak boleh
    // dilakukan (server pun menolaknya dengan 409). Tutup dulu hari itu.
    if (status == AttendanceProviderStatus.notCheckedIn) {
      await _attendance.refreshOpenSession();
      final open = _attendance.openSession;
      if (open != null) {
        await _promptCloseOpenSession(open);
        return;
      }
    }

    // Tentukan tipe kamera
    final actionType = (status == AttendanceProviderStatus.notCheckedIn)
        ? CameraActionType.checkIn
        : CameraActionType.checkOut;

    // 2026-09-09 -- peringatan "Belum Jam Pulang!" SEBELUM kamera dibuka,
    // bukan sesudah foto diambil (perilaku lama, lihat
    // widgets/early_checkout_dialog.dart's doc comment). Staff yang batal
    // di sini tidak pernah membuka kamera sama sekali.
    if (actionType == CameraActionType.checkOut &&
        !AttendanceRules.isAfterEarliestCheckout) {
      final proceed = await showEarlyCheckoutDialog(context);
      if (!mounted || !proceed) return;
    }

    // Buka halaman kamera
    final result = await Navigator.push<CameraResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CameraCheckinScreen(actionType: actionType),
      ),
    );

    if (!mounted || result == null || !result.confirmed) return;

    // Fase 8: koordinat GPS wajib menyertai absensi — server yang memutuskan
    // apakah posisinya di dalam radius Lokasi staff (lib/geo.ts).
    final gps = await LocationService.current();
    if (!mounted) return;
    if (!gps.ok) {
      _showInfoSnackbar(gps.failure!.message);
      return;
    }

    // Simpan ke backend sesuai aksi.
    try {
      if (result.actionType == CameraActionType.checkIn) {
        await _attendance.checkInRemote(
          fotoPath: result.imagePath,
          latitude: gps.position!.latitude,
          longitude: gps.position!.longitude,
          accuracy: gps.position!.accuracy,
        );
        if (!mounted) return;
        _showSuccessSnackbar('Check-in berhasil! Selamat bekerja 💪');
      } else {
        await _attendance.checkOutRemote(
          fotoPath: result.imagePath,
          latitude: gps.position!.latitude,
          longitude: gps.position!.longitude,
          accuracy: gps.position!.accuracy,
        );
        if (!mounted) return;
        final uangMakan = _attendance.uangMakan;
        _showSuccessSnackbar(uangMakan > 0
            ? 'Check-out berhasil! Uang makan hari ini didapat 🌙'
            : 'Check-out berhasil! Istirahat yang baik 🌙');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showInfoSnackbar(e.message);
    }
  }

  // ── Dialog selesai istirahat ─────────────────────────────────
  Future<void> _showEndBreakDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        title: Row(
          children: [
            const Text('☕', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text('Selesai Istirahat?',
                style: GoogleFonts.inter(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Apakah kamu sudah siap untuk kembali bekerja?',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Belum',
                style: GoogleFonts.inter(color: AppColors.slate700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Ya, Kembali Bekerja',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    try {
      await _attendance.endBreakRemote();
      if (!mounted) return;
      _showSuccessSnackbar(
          'Selamat bekerja kembali! Total istirahat ${_attendance.breakMinutes} menit 💪');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showInfoSnackbar(e.message);
    }
  }

  void _showSuccessSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: AppColors.brandNavy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showInfoSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
      backgroundColor: AppColors.slate600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Memuat profil staff dari backend.
    if (_loadingProfile) {
      return const Scaffold(
        backgroundColor: AppColors.slate50,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.brandNavy),
        ),
      );
    }

    // Gagal memuat profil (mis. jaringan / sesi habis).
    if (_profileError != null) {
      return _ProfileErrorView(
        message: _profileError!,
        onRetry: _hydrateProfile,
        onLogout: _logout,
      );
    }

    // Dokumen wajib belum lengkap → app belum boleh dibuka. Ditampilkan
    // sebagai layar, bukan navigasi, supaya tidak ada route MainScreen
    // "setengah terbuka" yang bisa dikembalikan dengan tombol back.
    if (_needsOnboarding) {
      return const OnboardingDocumentsScreen();
    }

    // Admin: tampilan khusus (hanya dashboard, tidak ada FAB)
    if (_isAdmin) {
      return _buildAdminLayout();
    }

    // Staff / Supervisor: tampilan normal
    return _buildStaffLayout();
  }

  // ── Admin Layout (hanya 2 tab, no FAB) ───────────────────────
  Widget _buildAdminLayout() {
    return InheritedAttendance(
      provider: _attendance,
      child: Scaffold(
        backgroundColor: AppColors.slate50,
        body: const AdminDashboardTab(),
      ),
    );
  }

  // ── Staff/Supervisor Layout ───────────────────────────────────
  Widget _buildStaffLayout() {
    final isManager = AppSession.currentUser.role == UserRole.admin;
    return InheritedAttendance(
      provider: _attendance,
      child: Scaffold(
        backgroundColor: AppColors.slate50,
        body: IndexedStack(
          index: _tab,
          children: [
            HomeTab(
              onNavigateToAccount: () => _onTabTap(4),
              attendance: _attendance,
              onNavigateToTab: _onTabTap,
            ),
            isManager
                ? const AdminDashboardTab()
                : LeaveTab(attendance: _attendance),
            // slot 2 kosong — FAB menangani kamera secara push, bukan IndexedStack
            const SizedBox.shrink(),
            const SalaryScreen(isFromAccount: false),
            const AccountTab(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(isManager),
        floatingActionButton: _buildFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildBottomNav(bool isManager) {
    return BottomAppBar(
      color: AppColors.white,
      elevation: 8,
      shadowColor: AppColors.brandNavy.withOpacity(0.1),
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: _tab == 0,
              onTap: () => _onTabTap(0),
            ),
            if (isManager)
              _NavItem(
                icon: Icons.groups_rounded,
                label: 'Tim',
                selected: _tab == 1,
                onTap: () => _onTabTap(1),
              )
            else
              _NavItem(
                icon: Icons.event_note_rounded,
                label: 'Cuti & Izin',
                selected: _tab == 1,
                onTap: () => _onTabTap(1),
              ),
            const SizedBox(width: 56), // spacer FAB
            _NavItem(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Gaji',
              selected: _tab == 3,
              onTap: () => _onTabTap(3),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Akun',
              selected: _tab == 4,
              onTap: () => _onTabTap(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    final status = _attendance.status;
    final isDone = status == AttendanceProviderStatus.checkedOut;
    final isBreak = status == AttendanceProviderStatus.onBreak;

    // Warna FAB
    Color fabColor;
    IconData fabIcon;
    if (isDone) {
      fabColor = AppColors.slate400;
      fabIcon = Icons.check_circle_rounded;
    } else if (isBreak) {
      fabColor = const Color(0xFFE67E22); // orange
      fabIcon = Icons.free_breakfast_rounded;
    } else {
      fabColor = AppColors.brandNavy;
      fabIcon = Icons.camera_alt_outlined;
    }

    return GestureDetector(
      onTap: _onFabTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: fabColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: fabColor.withOpacity(0.38),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(fabIcon, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Tampilan error saat gagal memuat profil ──────────────────────
class _ProfileErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  const _ProfileErrorView({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 56, color: AppColors.slate400),
                const SizedBox(height: 16),
                Text('Gagal memuat data',
                    style: AppText.headline3
                        .copyWith(color: AppColors.slate900)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center, style: AppText.body2),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onLogout,
                  child: Text('Keluar',
                      style: GoogleFonts.inter(color: AppColors.slate600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── InheritedWidget untuk share AttendanceProvider ───────────────
class InheritedAttendance extends InheritedWidget {
  final AttendanceProvider provider;

  const InheritedAttendance({
    super.key,
    required this.provider,
    required super.child,
  });

  static AttendanceProvider of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InheritedAttendance>()!
        .provider;
  }

  @override
  bool updateShouldNotify(InheritedAttendance old) => provider != old.provider;
}

// ── Nav Item ─────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brandNavy : AppColors.slate400;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
