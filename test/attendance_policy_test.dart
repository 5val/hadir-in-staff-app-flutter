import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/models/attendance_policy.dart';
import 'package:hadirin_staff_app/services/attendance_service.dart';
import 'package:hadirin_staff_app/services/liveness_challenge.dart';

void main() {
  group('AttendancePolicy.fromApi', () {
    test('mem-parsing respons server lengkap', () {
      final p = AttendancePolicy.fromApi({
        'sumber': 'lokasi',
        'kebijakanId': 'k1',
        'nama': 'Kantor Pusat',
        'wajibFoto': true,
        'wajibGps': true,
        'cekRadius': false,
        'deteksiMockGps': false,
        'wajibLiveness': true,
      });
      expect(p.sumber, 'lokasi');
      expect(p.kebijakanId, 'k1');
      expect(p.nama, 'Kantor Pusat');
      expect(p.cekRadius, isFalse);
      expect(p.deteksiMockGps, isFalse);
      expect(p.livenessActive, isTrue);
      expect(p.radiusEnforced, isFalse);
      expect(p.blocksMockedGps, isFalse);
    });

    test('field hilang / non-boolean jatuh ke bawaan ketat', () {
      final p = AttendancePolicy.fromApi({'wajibFoto': 'ya'});
      expect(p, AttendancePolicy.strictDefault);
      expect(p.wajibLiveness, isFalse);
    });

    test('normalisasi server: tanpa GPS -> tanpa radius; tanpa foto -> tanpa liveness',
        () {
      final p = AttendancePolicy.fromApi({
        'wajibFoto': false,
        'wajibGps': false,
        'cekRadius': true,
        'deteksiMockGps': true,
        'wajibLiveness': true,
      });
      expect(p.cekRadius, isFalse);
      expect(p.wajibLiveness, isFalse);
      expect(p.livenessActive, isFalse);
      expect(p.blocksMockedGps, isFalse); // GPS tak dipakai -> mock tak diblokir
    });

    test('strictDefault: foto+GPS+radius+mock wajib, liveness tidak', () {
      const p = AttendancePolicy.strictDefault;
      expect(
          [p.wajibFoto, p.wajibGps, p.cekRadius, p.deteksiMockGps, p.wajibLiveness],
          [true, true, true, true, false]);
      expect(p.blocksMockedGps, isTrue);
    });
  });

  group('AttendancePolicyCache.resolve', () {
    setUp(AttendancePolicyCache.clear);

    const live = AttendancePolicy(
        wajibFoto: true,
        wajibGps: true,
        cekRadius: true,
        deteksiMockGps: true,
        wajibLiveness: true);

    test('sukses: dipakai dan di-cache', () async {
      final p = await AttendancePolicyCache.resolve('s1', () async => live);
      expect(p.wajibLiveness, isTrue);
      expect(AttendancePolicyCache.peek('s1'), live);
    });

    test('gagal fetch -> cache terakhir yang baik', () async {
      await AttendancePolicyCache.resolve('s1', () async => live);
      final p = await AttendancePolicyCache.resolve(
          's1', () async => throw Exception('offline'));
      expect(p, live);
    });

    test('gagal fetch tanpa cache -> strict default', () async {
      final p = await AttendancePolicyCache.resolve(
          's2', () async => throw Exception('offline'));
      expect(p, AttendancePolicy.strictDefault);
    });

    test('cache per staff, tidak bocor antar akun', () async {
      await AttendancePolicyCache.resolve('s1', () async => live);
      final p = await AttendancePolicyCache.resolve(
          's2', () async => throw Exception('offline'));
      expect(p, AttendancePolicy.strictDefault);
    });

    test('mengenali error 400 "Perbarui aplikasi" dari server', () {
      expect(
          AttendancePolicyCache.isLivenessRequiredError(
              'Perbarui aplikasi Hadir-In ke versi terbaru untuk melanjutkan absensi (verifikasi liveness diwajibkan oleh kebijakan kantor).'),
          isTrue);
      expect(
          AttendancePolicyCache.isLivenessRequiredError(
              'Foto selfie wajib diambil untuk absensi.'),
          isFalse);
    });
  });

  group('AttendanceService.buildCheckBody', () {
    const lolos = LivenessReport(
        status: 'lolos',
        langkah: ['kedip', 'toleh_kiri'],
        percobaan: 1,
        durasiMs: 3200);

    test('check-in: foto, GPS, lokasiPalsu, liveness semua ikut', () {
      final b = AttendanceService.buildCheckBody(
        isCheckIn: true,
        fotoBase64: 'QUJD',
        fotoPath: '/x/a.png',
        latitude: -6.2,
        longitude: 106.8,
        accuracy: 5,
        lokasiPalsu: false,
        liveness: lolos,
      );
      expect(b['fotoMasuk'], 'QUJD');
      expect(b['fotoMimeType'], 'image/png');
      expect(b['lokasiPalsu'], false);
      expect(b['liveness'], {
        'status': 'lolos',
        'langkah': ['kedip', 'toleh_kiri'],
        'percobaan': 1,
        'durasiMs': 3200,
        'versi': '1',
      });
    });

    test('check-out memakai fotoKeluar', () {
      final b = AttendanceService.buildCheckBody(
          isCheckIn: false, fotoBase64: 'QUJD', fotoPath: '/x/a.jpg');
      expect(b.containsKey('fotoKeluar'), isTrue);
      expect(b.containsKey('fotoMasuk'), isFalse);
    });

    test('lokasiPalsu=true dikirim apa adanya bila GPS terbaca', () {
      final b = AttendanceService.buildCheckBody(
          isCheckIn: true, latitude: 1, longitude: 2, lokasiPalsu: true);
      expect(b['lokasiPalsu'], true);
    });

    test('GPS terbaca tapi lokasiPalsu null -> tetap dikirim false', () {
      final b = AttendanceService.buildCheckBody(
          isCheckIn: true, latitude: 1, longitude: 2);
      expect(b['lokasiPalsu'], false);
    });

    test('tanpa GPS: lokasiPalsu & koordinat tidak dikirim', () {
      final b = AttendanceService.buildCheckBody(
          isCheckIn: true, lokasiPalsu: true);
      expect(b.containsKey('lokasiPalsu'), isFalse);
      expect(b.containsKey('latitude'), isFalse);
    });

    test('liveness tidak dijalankan -> field liveness tidak ada', () {
      final b = AttendanceService.buildCheckBody(
          isCheckIn: true, latitude: 1, longitude: 2, lokasiPalsu: false);
      expect(b.containsKey('liveness'), isFalse);
    });

    test('tanpa foto (kebijakan tak wajib foto): tak ada foto/mime', () {
      final b = AttendanceService.buildCheckBody(
          isCheckIn: true, latitude: 1, longitude: 2, fotoPath: '/x/a.jpg');
      expect(b.containsKey('fotoMasuk'), isFalse);
      expect(b.containsKey('fotoMimeType'), isFalse);
    });

    test('jam testing hanya bila diberikan', () {
      expect(AttendanceService.buildCheckBody(isCheckIn: true).containsKey('time'),
          isFalse);
      expect(
          AttendanceService.buildCheckBody(isCheckIn: true, jamTesting: '08:00')['time'],
          '08:00');
    });
  });
}
