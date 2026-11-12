// State machine tantangan liveness: kedip 1x -> toleh kiri/kanan -> kembali
// lurus. MURNI Dart (tanpa Flutter/ML Kit) supaya bisa di-unit-test; layar
// kamera mengubah `Face` ML Kit menjadi [LivenessSample].
//
// Ini deteksi "ada gerakan nyata" (anti foto statis), BUKAN pencocokan
// identitas wajah.

/// Ambang -- semua bisa dituning di satu tempat.
class LivenessConfig {
  /// Mata dianggap TERTUTUP bila kedua probabilitas buka di bawah ini.
  final double eyeClosedBelow;

  /// Mata dianggap TERBUKA bila kedua probabilitas buka di atas ini.
  final double eyeOpenAbove;

  /// |headEulerAngleY| minimal (derajat) agar dianggap menoleh.
  final double turnAboveDeg;

  /// |headEulerAngleY| maksimal (derajat) agar dianggap kembali lurus.
  final double straightBelowDeg;

  /// Batas waktu satu percobaan (ms), dihitung sejak wajah valid pertama.
  final int attemptTimeoutMs;

  /// Setelah sekian percobaan gagal, tombol "Lanjut tanpa verifikasi gerak"
  /// muncul.
  final int maxAttempts;

  /// Yaw positif ML Kit (wajah menghadap ke KANAN gambar mentah kamera
  /// depan) = staff menoleh ke KIRI-nya sendiri, karena gambar mentah kamera
  /// depan tidak dicerminkan. Bila di perangkat nyata terbukti sebaliknya,
  /// cukup balik flag ini; kedua arah tetap lolos, hanya label langkah yang
  /// berubah. PERLU DIVERIFIKASI di perangkat.
  final bool positiveYawIsUserLeft;

  const LivenessConfig({
    this.eyeClosedBelow = 0.2,
    this.eyeOpenAbove = 0.6,
    this.turnAboveDeg = 25,
    this.straightBelowDeg = 10,
    this.attemptTimeoutMs = 10000,
    this.maxAttempts = 3,
    this.positiveYawIsUserLeft = true,
  });
}

/// Satu pengamatan frame.
class LivenessSample {
  /// trackingId ML Kit (null bila tracking mati / belum ada).
  final int? trackingId;
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// headEulerAngleY dalam derajat.
  final double? yaw;

  /// Jumlah wajah di frame (0 = hilang, >1 = ditolak).
  final int faceCount;
  final int timestampMs;

  const LivenessSample({
    this.trackingId,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.yaw,
    this.faceCount = 1,
    required this.timestampMs,
  });

  const LivenessSample.noFace(int timestampMs)
      : this(faceCount: 0, timestampMs: timestampMs);
}

enum LivenessPhase { blink, turn, straight, passed }

enum LivenessEvent {
  /// Tidak ada perubahan berarti.
  none,

  /// Satu langkah selesai (pindah fase).
  stepDone,

  /// Wajah hilang / ganti / lebih dari satu -- langkah diulang dari awal
  /// (jam percobaan tetap berjalan).
  reset,

  /// Percobaan habis waktu; percobaan baru dimulai.
  attemptTimedOut,

  /// Percobaan terakhir habis: tombol fallback boleh ditampilkan.
  fallbackAllowed,

  /// Seluruh tantangan lolos -> ambil foto.
  passed,
}

/// Payload `liveness` di body check-in/out (kontrak sprint3.md 2026-11-12).
class LivenessReport {
  static const statusLolos = 'lolos';
  static const statusDilewati = 'dilewati';
  static const statusTidakDidukung = 'tidak_didukung';
  static const versi = '1';

  final String status;
  final List<String> langkah;
  final int percobaan;
  final int durasiMs;

  const LivenessReport({
    required this.status,
    this.langkah = const [],
    this.percobaan = 0,
    this.durasiMs = 0,
  });

  /// Perangkat/platform tidak bisa menjalankan deteksi.
  const LivenessReport.unsupported()
      : status = statusTidakDidukung,
        langkah = const [],
        percobaan = 0,
        durasiMs = 0;

  Map<String, dynamic> toJson() => {
        'status': status,
        'langkah': langkah,
        // Batas server: 0..100 dan 0..600000.
        'percobaan': percobaan.clamp(0, 100),
        'durasiMs': durasiMs.clamp(0, 600000),
        'versi': versi,
      };
}

class LivenessChallenge {
  final LivenessConfig config;

  LivenessChallenge({this.config = const LivenessConfig()});

  LivenessPhase _phase = LivenessPhase.blink;
  LivenessPhase get phase => _phase;

  int _failedAttempts = 0;

  /// Jumlah percobaan yang habis waktu.
  int get failedAttempts => _failedAttempts;

  /// Nomor percobaan berjalan (mulai 1), dibatasi [LivenessConfig.maxAttempts].
  int get currentAttempt => _failedAttempts >= config.maxAttempts
      ? config.maxAttempts
      : _failedAttempts + 1;

  bool get passed => _phase == LivenessPhase.passed;

  /// Sudah gagal [LivenessConfig.maxAttempts]x -- boleh lanjut tanpa
  /// verifikasi gerak (tidak pernah memblokir staff).
  bool get fallbackAllowed => _failedAttempts >= config.maxAttempts;

  int? _trackingId;
  int? _attemptStartMs;
  int? _firstSampleMs;
  int? _finishedMs;

  // Sub-state langkah kedip.
  bool _sawOpen = false;
  bool _sawClosed = false;

  // Sisi toleh: 'toleh_kiri' | 'toleh_kanan'.
  String? _turnStep;

  /// Langkah yang sudah selesai pada percobaan berjalan.
  List<String> get completedSteps {
    final steps = <String>[];
    if (_phase == LivenessPhase.blink) return steps;
    steps.add('kedip');
    if (_phase == LivenessPhase.turn) return steps;
    steps.add(_turnStep ?? 'toleh_kiri');
    return steps;
  }

  /// Petunjuk untuk staff pada fase sekarang.
  String get instruction {
    if (fallbackAllowed && !passed) {
      return 'Verifikasi gerak belum berhasil';
    }
    switch (_phase) {
      case LivenessPhase.blink:
        return 'Kedipkan mata satu kali';
      case LivenessPhase.turn:
        return 'Toleh ke kiri atau kanan';
      case LivenessPhase.straight:
        return 'Sekarang hadap lurus ke kamera';
      case LivenessPhase.passed:
        return 'Verifikasi berhasil';
    }
  }

  /// 0..3 langkah selesai (untuk indikator progres).
  int get stepsDone {
    switch (_phase) {
      case LivenessPhase.blink:
        return 0;
      case LivenessPhase.turn:
        return 1;
      case LivenessPhase.straight:
        return 2;
      case LivenessPhase.passed:
        return 3;
    }
  }

  void _resetSteps() {
    _phase = LivenessPhase.blink;
    _sawOpen = false;
    _sawClosed = false;
    _turnStep = null;
    _trackingId = null;
  }

  /// Cek batas waktu tanpa frame baru (dipanggil timer UI).
  LivenessEvent tick(int nowMs) => _checkTimeout(nowMs);

  LivenessEvent _checkTimeout(int nowMs) {
    if (passed || fallbackAllowed) return LivenessEvent.none;
    final start = _attemptStartMs;
    if (start == null || nowMs - start < config.attemptTimeoutMs) {
      return LivenessEvent.none;
    }
    _failedAttempts++;
    _resetSteps();
    _attemptStartMs = null;
    return fallbackAllowed
        ? LivenessEvent.fallbackAllowed
        : LivenessEvent.attemptTimedOut;
  }

  /// Masukkan satu frame. Setelah lolos / fallback tersedia, frame diabaikan
  /// (setelah fallback tersedia tantangan tidak berjalan lagi).
  LivenessEvent feed(LivenessSample s) {
    if (passed) return LivenessEvent.none;
    _firstSampleMs ??= s.timestampMs;

    final timeout = _checkTimeout(s.timestampMs);
    if (timeout != LivenessEvent.none) return timeout;
    if (fallbackAllowed) return LivenessEvent.none;

    // Wajah hilang / lebih dari satu -> ulang langkah (jam jalan terus).
    if (s.faceCount != 1) {
      final had = _phase != LivenessPhase.blink || _sawOpen || _sawClosed;
      _resetSteps();
      return had ? LivenessEvent.reset : LivenessEvent.none;
    }

    // Jam percobaan dimulai pada wajah valid pertama.
    _attemptStartMs ??= s.timestampMs;

    // Wajah harus orang yang sama sepanjang tantangan.
    if (s.trackingId != null) {
      if (_trackingId == null) {
        _trackingId = s.trackingId;
      } else if (_trackingId != s.trackingId) {
        _resetSteps();
        _trackingId = s.trackingId;
        return LivenessEvent.reset;
      }
    }

    switch (_phase) {
      case LivenessPhase.blink:
        return _feedBlink(s);
      case LivenessPhase.turn:
        return _feedTurn(s);
      case LivenessPhase.straight:
        return _feedStraight(s);
      case LivenessPhase.passed:
        return LivenessEvent.none;
    }
  }

  LivenessEvent _feedBlink(LivenessSample s) {
    final l = s.leftEyeOpen;
    final r = s.rightEyeOpen;
    if (l == null || r == null) return LivenessEvent.none;
    final open = l > config.eyeOpenAbove && r > config.eyeOpenAbove;
    final closed = l < config.eyeClosedBelow && r < config.eyeClosedBelow;
    if (!_sawOpen) {
      if (open) _sawOpen = true;
      return LivenessEvent.none;
    }
    if (!_sawClosed) {
      if (closed) _sawClosed = true;
      return LivenessEvent.none;
    }
    if (open) {
      _phase = LivenessPhase.turn;
      return LivenessEvent.stepDone;
    }
    return LivenessEvent.none;
  }

  LivenessEvent _feedTurn(LivenessSample s) {
    final yaw = s.yaw;
    if (yaw == null || yaw.abs() <= config.turnAboveDeg) {
      return LivenessEvent.none;
    }
    final userLeft = config.positiveYawIsUserLeft ? yaw > 0 : yaw < 0;
    _turnStep = userLeft ? 'toleh_kiri' : 'toleh_kanan';
    _phase = LivenessPhase.straight;
    return LivenessEvent.stepDone;
  }

  LivenessEvent _feedStraight(LivenessSample s) {
    final yaw = s.yaw;
    if (yaw == null || yaw.abs() >= config.straightBelowDeg) {
      return LivenessEvent.none;
    }
    _phase = LivenessPhase.passed;
    _finishedMs = s.timestampMs;
    return LivenessEvent.passed;
  }

  /// Laporan untuk body check-in/out.
  ///
  /// [status] `lolos` hanya valid bila [passed]. Untuk `dilewati` (staff
  /// memilih lanjut setelah gagal) [nowMs] menutup durasi.
  LivenessReport buildReport(String status, {required int nowMs}) {
    final end = _finishedMs ?? nowMs;
    final start = _firstSampleMs ?? end;
    final lolos = status == LivenessReport.statusLolos;
    return LivenessReport(
      status: status,
      langkah: completedSteps,
      percobaan: lolos ? _failedAttempts + 1 : _failedAttempts,
      durasiMs: (end - start).clamp(0, 600000),
    );
  }
}
