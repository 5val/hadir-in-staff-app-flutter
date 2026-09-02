import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadirin_staff_app/screens/account_info_screen.dart';

/// Regresi untuk crash sheet "Ubah Nomor HP" (2026-08-29).
///
/// Gejalanya dua error framework yang membingungkan —
/// `children.contains(child)` di `MultiChildRenderObjectElement.forgetChild`,
/// dan `LateInitializationError: _children` saat keyboard di-dismiss.
/// Keduanya hanya AKIBAT: penyebab sebenarnya adalah `TextEditingController`
/// sheet yang di-`dispose()` begitu future `showModalBottomSheet` selesai,
/// padahal widget sheet masih hidup sepanjang animasi menutupnya. Rebuild apa
/// pun di jendela waktu itu — dan dismiss keyboard memicunya, karena sheet
/// membaca `viewInsets` — menyentuh controller yang sudah mati.
///
/// Test ini menggerakkan inset keyboard persis di titik-titik itu.
void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccountInfoScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> setKeyboard(WidgetTester tester, {required bool visible}) async {
    tester.view.viewInsets =
        visible ? const FakeViewPadding(bottom: 300) : FakeViewPadding.zero;
    await tester.pumpAndSettle();
  }

  testWidgets('sheet ubah nomor HP tahan terhadap keyboard muncul/hilang',
      (tester) async {
    await pumpScreen(tester);

    await tester.ensureVisible(find.text('Ubah Nomor HP'));
    await tester.tap(find.text('Ubah Nomor HP'));
    await tester.pumpAndSettle();
    expect(find.text('Nomor HP baru, mis. 08123456789'), findsOneWidget);

    await setKeyboard(tester, visible: true);
    await tester.enterText(find.byType(TextField).last, '08123456789');
    await tester.pumpAndSettle();

    // Dismiss keyboard SELAGI sheet masih terbuka.
    await setKeyboard(tester, visible: false);

    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
  });

  testWidgets('menutup sheet lalu keyboard berubah tidak menyentuh controller mati',
      (tester) async {
    await pumpScreen(tester);

    await tester.ensureVisible(find.text('Ubah Nomor HP'));
    await tester.tap(find.text('Ubah Nomor HP'));
    await tester.pumpAndSettle();

    await setKeyboard(tester, visible: true);

    // Tutup sheet dengan mengetuk barrier, lalu goyang inset SEBELUM animasi
    // menutupnya selesai -- inilah jendela waktu yang dulu menabrak
    // controller yang sudah di-dispose.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Nomor HP baru, mis. 08123456789'), findsNothing);
    tester.view.resetViewInsets();
  });
}
