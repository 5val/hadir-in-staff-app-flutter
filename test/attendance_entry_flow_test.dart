import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hadirin_staff_app/models/attendance_policy.dart';
import 'package:hadirin_staff_app/screens/camera_checkin_screen.dart';
import 'package:hadirin_staff_app/services/liveness_challenge.dart';
import 'package:hadirin_staff_app/services/location_service.dart';
import 'package:hadirin_staff_app/widgets/attendance_entry_flow.dart';

Position pos({bool mocked = false}) => Position(
      latitude: -6.2,
      longitude: 106.8,
      timestamp: DateTime(2026, 11, 8),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: mocked,
    );

void main() {
  group('F4 -- lokasi palsu ditolak di LocationService (satu pintu)', () {
    test('guardMocked menolak isMocked, meloloskan yang asli', () {
      final bad = LocationService.guardMocked(pos(mocked: true));
      expect(bad.ok, isFalse);
      expect(bad.failure, GpsFailure.mockLocation);
      expect(bad.failure!.message, contains('fake GPS'));
      expect(LocationService.guardMocked(pos()).ok, isTrue);
    });
  });

  group('F3/F5 -- runAttendanceEntry (FAB & kartu Home)', () {
    late int cameraOpened;
    late List<String> messages;
    late List<bool> errors;
    late List<bool> blockMockedArgs;
    late List<Duration> timeLimitArgs;
    AttendancePolicy? policySeenByCamera;

    AttendanceEntryHooks hooks({
      bool holiday = false,
      bool afterEarliest = true,
      String? imagePath = '/tmp/f.jpg',
      GpsResult? gps,
      AttendancePolicy? policy,
      LivenessReport? liveness,
    }) =>
        AttendanceEntryHooks(
          findOpenSession: () async => null,
          refreshTodayAndSnapshot: () async {},
          isHolidayWork: () => holiday,
          isAfterEarliestCheckout: () => afterEarliest,
          openCamera: (ctx, type, p) async {
            cameraOpened++;
            policySeenByCamera = p;
            return CameraResult(
                confirmed: true,
                actionType: type,
                imagePath: imagePath,
                liveness: liveness);
          },
          readGps: (blockMocked, timeLimit) async {
            blockMockedArgs.add(blockMocked);
            timeLimitArgs.add(timeLimit);
            return gps ?? GpsResult.success(pos());
          },
          closeOpenSession: (_, __) async => false,
          fetchPolicy:
              policy == null ? null : () async => policy,
        );

    Future<AttendanceEntryResult?> run(WidgetTester tester,
        CameraActionType type, AttendanceEntryHooks h,
        {String? tapAfterDialog}) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      final fut = runAttendanceEntry(
        context: ctx,
        actionType: type,
        hooks: h,
        onMessage: (m, {bool error = false}) {
          messages.add(m);
          errors.add(error);
        },
      );
      await tester.pumpAndSettle();
      if (tapAfterDialog != null) {
        await tester.tap(find.text(tapAfterDialog));
        await tester.pumpAndSettle();
      }
      return fut;
    }

    setUp(() {
      cameraOpened = 0;
      messages = [];
      errors = [];
      blockMockedArgs = [];
      timeLimitArgs = [];
      policySeenByCamera = null;
    });

    testWidgets('check-out sebelum jam pulang: dialog "Belum Jam Pulang!", Batal = kamera tidak dibuka',
        (tester) async {
      final r = await run(tester, CameraActionType.checkOut,
          hooks(afterEarliest: false),
          tapAfterDialog: 'Batal');
      expect(r, isNull);
      expect(cameraOpened, 0);
    });

    testWidgets('check-out sebelum jam pulang: "Ya, Check-Out Sekarang" melanjutkan', (tester) async {
      final r = await run(tester, CameraActionType.checkOut,
          hooks(afterEarliest: false),
          tapAfterDialog: 'Ya, Check-Out Sekarang');
      expect(r, isNotNull);
      expect(cameraOpened, 1);
    });

    testWidgets('check-out hari libur tidak digerbang "Belum Jam Pulang!"', (tester) async {
      final r = await run(tester, CameraActionType.checkOut,
          hooks(holiday: true, afterEarliest: false));
      expect(r, isNotNull);
      expect(find.text('Belum Jam Pulang!'), findsNothing);
    });

    testWidgets('check-in hari libur: konfirmasi dulu, Batal = kamera tidak dibuka', (tester) async {
      final r = await run(tester, CameraActionType.checkIn, hooks(holiday: true),
          tapAfterDialog: 'Batal');
      expect(r, isNull);
      expect(cameraOpened, 0);
    });

    testWidgets('F3: kamera confirmed tanpa foto ditolak, tidak lanjut ke server', (tester) async {
      final r = await run(
          tester, CameraActionType.checkIn, hooks(imagePath: null));
      expect(r, isNull);
      expect(messages.single, contains('Foto'));
      expect(errors.single, isTrue);
    });

    testWidgets('F4: GPS lokasi palsu menghentikan alur dengan pesan', (tester) async {
      final r = await run(
          tester,
          CameraActionType.checkIn,
          hooks(
              gps: const GpsResult.failed(GpsFailure.mockLocation)));
      expect(r, isNull);
      expect(messages.single, GpsFailure.mockLocation.message);
    });

    // ── Fase 3: alur mengikuti Kebijakan Absensi ──────────────────────
    const noPhoto = AttendancePolicy(
        wajibFoto: false,
        wajibGps: true,
        cekRadius: true,
        deteksiMockGps: true,
        wajibLiveness: false);
    const noGps = AttendancePolicy(
        wajibFoto: true,
        wajibGps: false,
        cekRadius: false,
        deteksiMockGps: true,
        wajibLiveness: false);
    const mockOk = AttendancePolicy(
        wajibFoto: true,
        wajibGps: true,
        cekRadius: true,
        deteksiMockGps: false,
        wajibLiveness: false);
    const withLiveness = AttendancePolicy(
        wajibFoto: true,
        wajibGps: true,
        cekRadius: true,
        deteksiMockGps: true,
        wajibLiveness: true);

    testWidgets('wajibFoto=false: kamera dilewati, tanpa path foto', (tester) async {
      final r = await run(
          tester, CameraActionType.checkIn, hooks(policy: noPhoto));
      expect(r, isNotNull);
      expect(cameraOpened, 0);
      expect(r!.fotoPath, isNull);
      expect(r.position, isNotNull);
    });

    testWidgets('wajibGps=false: GPS gagal TIDAK memblokir (posisi null)', (tester) async {
      final r = await run(
          tester,
          CameraActionType.checkIn,
          hooks(
              policy: noGps,
              gps: const GpsResult.failed(GpsFailure.serviceDisabled)));
      expect(r, isNotNull);
      expect(r!.position, isNull);
      expect(r.lokasiPalsu, isNull); // GPS tak terbaca -> tidak dikirim
      expect(messages, isEmpty);
    });

    testWidgets('wajibGps=false: GPS dibaca best-effort dengan batas tunggu pendek', (tester) async {
      await run(tester, CameraActionType.checkIn, hooks(policy: noGps));
      expect(timeLimitArgs, [LocationService.bestEffortTimeLimit]);
      expect(LocationService.bestEffortTimeLimit, const Duration(seconds: 5));
    });

    testWidgets('wajibGps=true: GPS dibaca dengan batas tunggu penuh (20 dtk)', (tester) async {
      await run(tester, CameraActionType.checkIn,
          hooks(policy: AttendancePolicy.strictDefault));
      expect(timeLimitArgs, [const Duration(seconds: 20)]);
    });

    testWidgets('wajibGps=true: GPS gagal tetap memblokir (perilaku lama)', (tester) async {
      final r = await run(
          tester,
          CameraActionType.checkIn,
          hooks(
              policy: AttendancePolicy.strictDefault,
              gps: const GpsResult.failed(GpsFailure.serviceDisabled)));
      expect(r, isNull);
      expect(messages.single, GpsFailure.serviceDisabled.message);
    });

    testWidgets('deteksiMockGps=true: GPS dibaca dengan blokir mock', (tester) async {
      await run(tester, CameraActionType.checkIn,
          hooks(policy: AttendancePolicy.strictDefault));
      expect(blockMockedArgs, [true]);
    });

    testWidgets('deteksiMockGps=false: mock tidak diblokir & lokasiPalsu=true terkirim', (tester) async {
      final r = await run(tester, CameraActionType.checkIn,
          hooks(policy: mockOk, gps: GpsResult.success(pos(mocked: true))));
      expect(blockMockedArgs, [false]);
      expect(r, isNotNull);
      expect(r!.lokasiPalsu, isTrue);
    });

    testWidgets('GPS asli: lokasiPalsu=false (selalu ada bila GPS terbaca)', (tester) async {
      final r = await run(tester, CameraActionType.checkIn, hooks());
      expect(r!.lokasiPalsu, isFalse);
    });

    testWidgets('liveness: kebijakan diteruskan ke kamera & laporannya terbawa', (tester) async {
      const rep = LivenessReport(
          status: 'lolos',
          langkah: ['kedip', 'toleh_kanan'],
          percobaan: 1,
          durasiMs: 2500);
      final r = await run(tester, CameraActionType.checkOut,
          hooks(policy: withLiveness, liveness: rep));
      expect(policySeenByCamera!.livenessActive, isTrue);
      expect(r!.liveness!.status, 'lolos');
    });

    testWidgets('tanpa liveness di kebijakan: tidak ada laporan liveness', (tester) async {
      final r = await run(tester, CameraActionType.checkIn,
          hooks(policy: AttendancePolicy.strictDefault));
      expect(r!.liveness, isNull);
    });

    testWidgets('tanpa fetchPolicy (tes lama): strict default', (tester) async {
      await run(tester, CameraActionType.checkIn, hooks());
      expect(policySeenByCamera, AttendancePolicy.strictDefault);
    });
  });
}
