import '../models/models.dart';
import 'api_client.dart';
import 'session_service.dart';

/// Hasil pemuatan notifikasi (daftar + jumlah belum dibaca).
class NotificationResult {
  final List<AppNotification> items;
  final int unreadCount;
  const NotificationResult(this.items, this.unreadCount);
}

/// Panggilan backend untuk notifikasi staff yang sedang login.
class NotificationService {
  const NotificationService._();

  static Future<String> _staffId() async {
    final id = await SessionService.getStaffId();
    if (id == null || id.isEmpty) {
      throw ApiException('Sesi tidak ditemukan. Silakan login kembali.');
    }
    return id;
  }

  /// GET daftar notifikasi + unreadCount.
  static Future<NotificationResult> myNotifications() async {
    final id = await _staffId();
    final res = await ApiClient.instance.get('/mobile/staff/$id/notifications');
    final m = res.asMap;
    final list = (m['notifications'] as List?)
            ?.whereType<Map>()
            .map((e) => AppNotification.fromApi(Map<String, dynamic>.from(e)))
            .toList() ??
        <AppNotification>[];
    final unread = (m['unreadCount'] as num?)?.toInt() ?? 0;
    return NotificationResult(list, unread);
  }

  /// PATCH tandai semua dibaca.
  static Future<void> markAllRead() async {
    final id = await _staffId();
    await ApiClient.instance
        .patch('/mobile/staff/$id/notifications/read-all');
  }

  /// PATCH tandai satu notifikasi dibaca.
  static Future<void> markRead(String notifId) async {
    final id = await _staffId();
    await ApiClient.instance
        .patch('/mobile/staff/$id/notifications/$notifId/read');
  }
}
