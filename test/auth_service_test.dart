// Sprint 2 OTP/auth overhaul (2026-08-03): regression tests for the parts of
// `AuthService` that changed shape — email OTP delivery (Piece 1), resend/
// lockout message parsing (Piece 2), and forgot-passcode request shape
// (Piece 3). See `docs/api-contracts/sprint2.md` (backend repo) for the
// contract these mirror.
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/services/auth_service.dart';

void main() {
  group('OtpRequestResult.fromMap — Piece 1 (email OTP, breaking shape)', () {
    test('parses the new email-delivery response shape', () {
      final result = OtpRequestResult.fromMap({
        'message': 'Kode OTP telah dikirim ke email Anda',
        'phone': '081234567890',
        'email': 'staff@example.com',
        'expiresInMinutes': 10,
        'delivered': true,
      });

      expect(result.phone, '081234567890');
      expect(result.email, 'staff@example.com');
      expect(result.expiresInMinutes, 10);
      expect(result.delivered, isTrue);
      expect(result.devCode, isNull);
      expect(result.message, 'Kode OTP telah dikirim ke email Anda');
    });

    test('dev-mode response: delivered=false + devCode present', () {
      final result = OtpRequestResult.fromMap({
        'message': 'Kode OTP telah dikirim ke email Anda',
        'phone': '081234567890',
        'email': 'staff@example.com',
        'expiresInMinutes': 10,
        'delivered': false,
        'devCode': '123456',
      });

      expect(result.delivered, isFalse);
      expect(result.devCode, '123456');
    });

    test('missing delivered/email fields default safely (no crash)', () {
      final result = OtpRequestResult.fromMap({'phone': '08123'});
      expect(result.delivered, isFalse);
      expect(result.email, '');
      expect(result.expiresInMinutes, 10);
    });
  });

  group('AuthService.parseLockoutMinutes — Piece 2 (best-effort UI countdown)', () {
    test('extracts minutes from the 15-minute wrong-code lockout message', () {
      expect(
        AuthService.parseLockoutMinutes('Kode OTP salah. Akun dikunci 15 menit.'),
        15,
      );
    });

    test('extracts minutes from the active-lockout-blocks-both message', () {
      expect(
        AuthService.parseLockoutMinutes(
          'Terlalu banyak percobaan verifikasi OTP gagal. Coba lagi dalam 12 menit.',
        ),
        12,
      );
    });

    test('extracts minutes from the max-resend rolling-window message', () {
      expect(
        AuthService.parseLockoutMinutes(
          'Terlalu banyak permintaan OTP. Coba lagi setelah 30 menit.',
        ),
        30,
      );
    });

    test('returns null for the plain wrong-code message (has no minute count)', () {
      expect(
        AuthService.parseLockoutMinutes('Kode OTP tidak valid. Sisa 2 percobaan.'),
        isNull,
      );
    });

    test('returns null for the 60-second cooldown message (seconds, not minutes)', () {
      expect(
        AuthService.parseLockoutMinutes('Tunggu 45 detik sebelum meminta OTP baru.'),
        isNull,
      );
    });
  });

  group('AuthService.buildSetPasscodeBody — Piece 3 (forgot-passcode request shape)', () {
    test('omits passcodeLama entirely when null (forgot-passcode flow)', () {
      final body = AuthService.buildSetPasscodeBody(passcode: '123456');
      expect(body.containsKey('passcodeLama'), isFalse);
      expect(body['passcode'], '123456');
    });

    test('omits passcodeLama entirely when empty string', () {
      final body = AuthService.buildSetPasscodeBody(
        passcode: '123456',
        passcodeLama: '',
      );
      expect(body.containsKey('passcodeLama'), isFalse);
    });

    test('includes passcodeLama when provided (normal Ubah Passcode flow)', () {
      final body = AuthService.buildSetPasscodeBody(
        passcode: '654321',
        passcodeLama: '111111',
      );
      expect(body['passcodeLama'], '111111');
      expect(body['passcode'], '654321');
    });
  });
}
