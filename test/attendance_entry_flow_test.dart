import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hadirin_staff_app/screens/camera_checkin_screen.dart';
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

    AttendanceEntryHooks hooks({
      bool holiday = false,
      bool afterEarliest = true,
      String? imagePath = '/tmp/f.jpg',
      GpsResult? gps,
    }) =>
        AttendanceEntryHooks(
          findOpenSession: () async => null,
          refreshTodayAndSnapshot: () async {},
          isHolidayWork: () => holiday,
          isAfterEarliestCheckout: () => afterEarliest,
          openCamera: (ctx, type) async {
            cameraOpened++;
            return CameraResult(
                confirmed: true, actionType: type, imagePath: imagePath);
          },
          readGps: () async => gps ?? GpsResult.success(pos()),
          closeOpenSession: (_, __) async => false,
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
  });
}
