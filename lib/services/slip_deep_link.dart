import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Deep-link notifikasi slip gaji -> detail slip yang tepat.
///
/// `slipId` datang dari dua tempat: `metadata.slipId` (daftar notifikasi di
/// app) atau field data push `slipId`. Payload ketukan notifikasi HP berbentuk
/// `notification:<rawType>:<id>[:<slipId>]` -- segmen ke-4 opsional sehingga
/// pembaca lama (yang hanya memakai segmen 1-2) tetap jalan.
class SlipDeepLink {
  const SlipDeepLink._();

  /// Id slip yang diminta dibuka; dikonsumsi (dikosongkan) oleh `SalaryScreen`.
  static final ValueNotifier<String?> pending = ValueNotifier<String?>(null);

  /// Minta pembukaan slip. Id kosong/null diabaikan (tetap di tab Gaji).
  static void request(String? slipId) {
    final id = clean(slipId);
    if (id != null) pending.value = id;
  }

  static String? clean(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty || s == 'null') ? null : s;
  }

  /// `slipId` dari metadata notifikasi dan/atau data push (yang pertama
  /// terisi menang).
  static String? slipIdFrom({Map? metadata, Map? data}) =>
      clean(metadata?['slipId']) ?? clean(data?['slipId']);

  static String buildPayload(String rawType, String id, {String? slipId}) {
    final s = clean(slipId);
    return s == null ? 'notification:$rawType:$id' : 'notification:$rawType:$id:$s';
  }

  /// Urai payload ketukan; null bila bukan payload notifikasi backend.
  static ({String rawType, String id, String? slipId})? parsePayload(
      String? payload) {
    if (payload == null || !payload.startsWith('notification:')) return null;
    final parts = payload.split(':');
    if (parts.length < 3 || parts[1].isEmpty) return null;
    return (
      rawType: parts[1],
      id: parts[2],
      slipId: parts.length > 3 ? clean(parts.sublist(3).join(':')) : null,
    );
  }

  /// Keputusan routing: slip yang harus dibuka, atau null (tidak ada id /
  /// tidak ditemukan) -> cukup tinggal di tab Gaji.
  static SalarySlip? resolve(List<SalarySlip> slips, String? slipId) {
    final id = clean(slipId);
    if (id == null) return null;
    for (final s in slips) {
      if (s.id == id) return s;
    }
    return null;
  }
}
