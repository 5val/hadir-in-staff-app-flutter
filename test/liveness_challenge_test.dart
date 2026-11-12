import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/liveness_challenge.dart';

/// Pembangun sampel: waktu maju otomatis supaya tes mudah dibaca.
class Feeder {
  final LivenessChallenge c;
  int t = 0;
  Feeder(this.c);

  LivenessEvent face({
    int? id = 7,
    double? l = 0.9,
    double? r = 0.9,
    double? yaw = 0,
    int count = 1,
    int dt = 100,
  }) {
    t += dt;
    return c.feed(LivenessSample(
        trackingId: id,
        leftEyeOpen: l,
        rightEyeOpen: r,
        yaw: yaw,
        faceCount: count,
        timestampMs: t));
  }

  LivenessEvent none({int dt = 100}) {
    t += dt;
    return c.feed(LivenessSample.noFace(t));
  }

  /// Lewati langkah kedip.
  void blink({int? id = 7}) {
    face(id: id); // terbuka
    face(id: id, l: 0.05, r: 0.05); // tertutup
    face(id: id); // terbuka lagi
  }
}

void main() {
  group('kedip', () {
    test('buka -> tutup -> buka = langkah kedip selesai', () {
      final f = Feeder(LivenessChallenge());
      expect(f.face(), LivenessEvent.none);
      expect(f.face(l: 0.05, r: 0.05), LivenessEvent.none);
      expect(f.face(), LivenessEvent.stepDone);
      expect(f.c.phase, LivenessPhase.turn);
      expect(f.c.completedSteps, ['kedip']);
    });

    test('mata tertutup terus (tanpa membuka lagi) tidak dianggap kedip', () {
      final f = Feeder(LivenessChallenge());
      f.face();
      f.face(l: 0.05, r: 0.05);
      f.face(l: 0.05, r: 0.05);
      f.face(l: 0.05, r: 0.05);
      expect(f.c.phase, LivenessPhase.blink);
    });

    test('satu mata saja tertutup bukan kedip', () {
      final f = Feeder(LivenessChallenge());
      f.face();
      f.face(l: 0.05, r: 0.9);
      f.face();
      expect(f.c.phase, LivenessPhase.blink);
    });

    test('mata setengah menutup (di atas ambang tutup) tidak dihitung', () {
      final f = Feeder(LivenessChallenge());
      f.face();
      f.face(l: 0.4, r: 0.4);
      f.face();
      expect(f.c.phase, LivenessPhase.blink);
    });

    test('foto statis (mata selalu terbuka) tidak pernah lolos kedip', () {
      final f = Feeder(LivenessChallenge());
      for (var i = 0; i < 20; i++) {
        f.face(yaw: i.isEven ? 0 : 40);
      }
      expect(f.c.phase, LivenessPhase.blink);
    });

    test('probabilitas mata null (klasifikasi tak tersedia) diabaikan', () {
      final f = Feeder(LivenessChallenge());
      f.face(l: null, r: null);
      f.face(l: null, r: null);
      expect(f.c.phase, LivenessPhase.blink);
    });
  });

  group('toleh & lurus', () {
    test('toleh ke sisi positif -> toleh_kiri; kembali lurus -> lolos', () {
      final f = Feeder(LivenessChallenge());
      f.blink();
      expect(f.face(yaw: 30), LivenessEvent.stepDone);
      expect(f.c.phase, LivenessPhase.straight);
      expect(f.face(yaw: 20), LivenessEvent.none); // belum lurus
      expect(f.face(yaw: 3), LivenessEvent.passed);
      expect(f.c.passed, isTrue);
      expect(f.c.completedSteps, ['kedip', 'toleh_kiri']);
    });

    test('toleh ke sisi negatif juga lolos (toleh_kanan)', () {
      final f = Feeder(LivenessChallenge());
      f.blink();
      f.face(yaw: -32);
      f.face(yaw: -2);
      expect(f.c.passed, isTrue);
      expect(f.c.completedSteps, ['kedip', 'toleh_kanan']);
    });

    test('flag positiveYawIsUserLeft=false membalik label saja', () {
      final f = Feeder(LivenessChallenge(
          config: const LivenessConfig(positiveYawIsUserLeft: false)));
      f.blink();
      f.face(yaw: 30);
      f.face(yaw: 0);
      expect(f.c.completedSteps, ['kedip', 'toleh_kanan']);
    });

    test('yaw kecil (<= ambang) bukan toleh', () {
      final f = Feeder(LivenessChallenge());
      f.blink();
      f.face(yaw: 24);
      expect(f.c.phase, LivenessPhase.turn);
    });

    test('tetap menoleh tidak dianggap kembali lurus', () {
      final f = Feeder(LivenessChallenge());
      f.blink();
      f.face(yaw: 35);
      f.face(yaw: 35);
      f.face(yaw: 12);
      expect(f.c.passed, isFalse);
      expect(f.c.phase, LivenessPhase.straight);
    });

    test('toleh sebelum kedip tidak melompati langkah', () {
      final f = Feeder(LivenessChallenge());
      f.face(yaw: 40);
      f.face(yaw: 0);
      expect(f.c.phase, LivenessPhase.blink);
    });
  });

  group('reset', () {
    test('trackingId berubah di tengah tantangan -> reset ke awal', () {
      final f = Feeder(LivenessChallenge());
      f.blink(id: 7);
      expect(f.c.phase, LivenessPhase.turn);
      expect(f.face(id: 9, yaw: 30), LivenessEvent.reset);
      expect(f.c.phase, LivenessPhase.blink);
      expect(f.c.failedAttempts, 0); // reset bukan percobaan gagal
    });

    test('wajah hilang di tengah tantangan -> reset', () {
      final f = Feeder(LivenessChallenge());
      f.blink();
      expect(f.none(), LivenessEvent.reset);
      expect(f.c.phase, LivenessPhase.blink);
      expect(f.c.failedAttempts, 0);
    });

    test('lebih dari satu wajah -> reset, tidak ada kemajuan', () {
      final f = Feeder(LivenessChallenge());
      f.blink();
      expect(f.face(count: 2, yaw: 30), LivenessEvent.reset);
      expect(f.c.phase, LivenessPhase.blink);
    });

    test('trackingId baru dipakai sebagai acuan setelah reset', () {
      final f = Feeder(LivenessChallenge());
      f.face(id: 7);
      f.face(id: 9); // ganti -> reset, acuan jadi 9
      f.blink(id: 9);
      expect(f.c.phase, LivenessPhase.turn);
    });

    test('tanpa wajah di awal (belum ada kemajuan) bukan event reset', () {
      final f = Feeder(LivenessChallenge());
      expect(f.none(), LivenessEvent.none);
    });
  });

  group('timeout & fallback', () {
    test('timeout 10 dtk dihitung sejak wajah valid pertama', () {
      final f = Feeder(LivenessChallenge());
      f.none(dt: 20000); // tanpa wajah lama: jam belum jalan
      expect(f.c.failedAttempts, 0);
      f.face(dt: 100); // jam mulai
      expect(f.face(dt: 9000), LivenessEvent.none);
      expect(f.face(dt: 2000), LivenessEvent.attemptTimedOut);
      expect(f.c.failedAttempts, 1);
      expect(f.c.currentAttempt, 2);
      expect(f.c.fallbackAllowed, isFalse);
    });

    test('timeout lewat tick() tanpa frame', () {
      final f = Feeder(LivenessChallenge());
      f.face();
      expect(f.c.tick(f.t + 10001), LivenessEvent.attemptTimedOut);
    });

    test('reset wajah tidak mengulang jam percobaan', () {
      final f = Feeder(LivenessChallenge());
      f.face();
      f.blink();
      f.none(dt: 5000); // reset di detik ke ~5
      f.face(dt: 100);
      expect(f.face(dt: 6000), LivenessEvent.attemptTimedOut);
    });

    test('3 percobaan gagal -> fallback diizinkan; frame lanjutan diabaikan',
        () {
      final f = Feeder(LivenessChallenge());
      f.face();
      expect(f.face(dt: 10100), LivenessEvent.attemptTimedOut);
      f.face();
      expect(f.face(dt: 10100), LivenessEvent.attemptTimedOut);
      f.face();
      expect(f.face(dt: 10100), LivenessEvent.fallbackAllowed);
      expect(f.c.fallbackAllowed, isTrue);
      expect(f.c.failedAttempts, 3);
      // Sesudah fallback tersedia, tantangan tidak jalan lagi.
      f.blink();
      expect(f.c.phase, LivenessPhase.blink);
    });

    test('lolos pada percobaan ke-2 -> percobaan=2', () {
      final f = Feeder(LivenessChallenge());
      f.face();
      f.face(dt: 10100); // gagal #1
      f.blink();
      f.face(yaw: 30);
      f.face(yaw: 0);
      expect(f.c.passed, isTrue);
      final r = f.c.buildReport(LivenessReport.statusLolos, nowMs: f.t);
      expect(r.percobaan, 2);
    });

    test('tidak ada fallback sebelum 3 gagal', () {
      final f = Feeder(LivenessChallenge());
      f.face();
      f.face(dt: 10100);
      f.face();
      f.face(dt: 10100);
      expect(f.c.fallbackAllowed, isFalse);
    });
  });

  group('LivenessReport', () {
    test('lolos: langkah, percobaan, durasi, versi sesuai kontrak', () {
      final f = Feeder(LivenessChallenge());
      f.blink();
      f.face(yaw: 30);
      f.face(yaw: 0);
      final json =
          f.c.buildReport(LivenessReport.statusLolos, nowMs: f.t).toJson();
      expect(json['status'], 'lolos');
      expect(json['langkah'], ['kedip', 'toleh_kiri']);
      expect(json['percobaan'], 1);
      expect(json['durasiMs'], 400); // dari sampel pertama (t=100) sampai lolos (t=500)
      expect(json['versi'], '1');
    });

    test('dilewati setelah 3 gagal: percobaan=3, langkah kosong', () {
      final f = Feeder(LivenessChallenge());
      for (var i = 0; i < 3; i++) {
        f.face();
        f.face(dt: 10100);
      }
      final r = f.c.buildReport(LivenessReport.statusDilewati, nowMs: f.t);
      expect(r.status, 'dilewati');
      expect(r.percobaan, 3);
      expect(r.langkah, isEmpty);
    });

    test('tidak_didukung: tanpa langkah, 0 percobaan', () {
      final j = const LivenessReport.unsupported().toJson();
      expect(j['status'], 'tidak_didukung');
      expect(j['langkah'], isEmpty);
      expect(j['percobaan'], 0);
      expect(j['durasiMs'], 0);
    });

    test('nilai di-clamp ke batas server (0..100, 0..600000)', () {
      final j = const LivenessReport(
              status: 'lolos', percobaan: 500, durasiMs: 9999999)
          .toJson();
      expect(j['percobaan'], 100);
      expect(j['durasiMs'], 600000);
    });
  });
}
