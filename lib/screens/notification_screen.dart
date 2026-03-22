import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _listController;
  late List<AppNotification> _notifications;
  String _filter = 'Semua';

  static const _filters = ['Semua', 'Belum Dibaca', 'Disetujui', 'Ditolak', 'Pengingat', 'Info'];

  @override
  void initState() {
    super.initState();
    _notifications = List.from(SampleData.notifications)
      ..addAll(_extraSampleNotifications());
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  List<AppNotification> _extraSampleNotifications() => [
        AppNotification(
          id: 'N004',
          title: 'Cuti Ditolak',
          message:
              'Pengajuan cuti Anda tanggal 20 Mar ditolak. Alasan: Kuota cuti habis untuk bulan ini.',
          type: NotificationType.rejection,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
        ),
        AppNotification(
          id: 'N005',
          title: 'Slip Gaji Tersedia',
          message:
              'Slip gaji periode Maret 2026 sudah dapat diunduh di menu Slip Gaji.',
          type: NotificationType.info,
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          isRead: true,
        ),
        AppNotification(
          id: 'N006',
          title: 'Izin Seminar Disetujui',
          message:
              'Izin seminar tanggal 15 Mar telah disetujui. Tunjangan akomodasi & transportasi akan diproses.',
          type: NotificationType.approval,
          createdAt: DateTime.now().subtract(const Duration(days: 4)),
          isRead: true,
        ),
      ];

  List<AppNotification> get _filtered {
    switch (_filter) {
      case 'Belum Dibaca':
        return _notifications.where((n) => !n.isRead).toList();
      case 'Disetujui':
        return _notifications
            .where((n) => n.type == NotificationType.approval)
            .toList();
      case 'Ditolak':
        return _notifications
            .where((n) => n.type == NotificationType.rejection)
            .toList();
      case 'Pengingat':
        return _notifications
            .where((n) => n.type == NotificationType.reminder)
            .toList();
      case 'Info':
        return _notifications
            .where((n) => n.type == NotificationType.info)
            .toList();
      default:
        return _notifications;
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _markAllRead() {
    setState(() {
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                title: n.title,
                message: n.message,
                type: n.type,
                createdAt: n.createdAt,
                isRead: true,
              ))
          .toList();
    });
  }

  void _markRead(String id) {
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == id
              ? AppNotification(
                  id: n.id,
                  title: n.title,
                  message: n.message,
                  type: n.type,
                  createdAt: n.createdAt,
                  isRead: true,
                )
              : n)
          .toList();
    });
  }

  void _deleteNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  Color _typeColor(NotificationType type) {
    switch (type) {
      case NotificationType.approval:
        return AppColors.success;
      case NotificationType.rejection:
        return AppColors.danger;
      case NotificationType.reminder:
        return AppColors.warning;
      case NotificationType.info:
        return AppColors.brandNavy;
    }
  }

  IconData _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.approval:
        return Icons.check_circle_rounded;
      case NotificationType.rejection:
        return Icons.cancel_rounded;
      case NotificationType.reminder:
        return Icons.alarm_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
    }
  }

  String _typeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.approval:
        return 'Disetujui';
      case NotificationType.rejection:
        return 'Ditolak';
      case NotificationType.reminder:
        return 'Pengingat';
      case NotificationType.info:
        return 'Info';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.slate900, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifikasi',
                style: AppText.headline3
                    .copyWith(fontSize: 18, color: AppColors.slate900)),
            if (_unreadCount > 0)
              Text('$_unreadCount belum dibaca',
                  style: AppText.caption.copyWith(color: AppColors.brandNavy)),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Baca Semua',
                  style: AppText.caption.copyWith(
                      color: AppColors.brandNavy, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ──────────────────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.brandNavy
                              : AppColors.slate300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          f,
                          style: AppText.caption.copyWith(
                            color:
                                selected ? Colors.white : AppColors.slate600,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const AppDivider(),

          // ── List ─────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final n = filtered[i];
                      return _buildCard(n, i);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 64, color: AppColors.slate600.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Tidak ada notifikasi',
                style: AppText.body1
                    .copyWith(color: AppColors.slate600)),
          ],
        ),
      );

  Widget _buildCard(AppNotification n, int index) {
    final color = _typeColor(n.type);
    final delay = index * 0.07;

    return AnimatedBuilder(
      animation: _listController,
      builder: (_, child) {
        final t = Curves.easeOut.transform(
          ((_listController.value - delay).clamp(0.0, 1.0) /
                  (1.0 - delay).clamp(0.01, 1.0))
              .clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key(n.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: AppColors.danger.withOpacity(0.15),
          child: Icon(Icons.delete_outline_rounded,
              color: AppColors.danger, size: 24),
        ),
        onDismissed: (_) => _deleteNotification(n.id),
        child: GestureDetector(
          onTap: () {
            if (!n.isRead) _markRead(n.id);
            _showDetail(n);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: n.isRead ? AppColors.white : AppColors.slate300,
              borderRadius: BorderRadius.circular(16),
              border: n.isRead
                  ? null
                  : Border.all(
                      color: color.withOpacity(0.3), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_typeIcon(n.type), color: color, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(n.title,
                                  style: AppText.body1.copyWith(
                                      fontWeight: n.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: AppColors.slate900)),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.brandNavy,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(n.message,
                            style: AppText.caption.copyWith(
                                color: AppColors.slate600, height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_typeLabel(n.type),
                                  style: AppText.caption.copyWith(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text(_formatTime(n.createdAt),
                                style: AppText.caption.copyWith(
                                    color: AppColors.slate600,
                                    fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(AppNotification n) {
    final color = _typeColor(n.type);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_typeIcon(n.type), color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title,
                          style: AppText.headline3
                              .copyWith(fontSize: 16, color: AppColors.slate900)),
                      const SizedBox(height: 2),
                      Text(_typeLabel(n.type),
                          style: AppText.caption.copyWith(color: color)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const AppDivider(),
            const SizedBox(height: 16),
            Text(n.message,
                style: AppText.body1.copyWith(
                    color: AppColors.slate600, height: 1.6)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14, color: AppColors.slate600),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy · HH:mm', 'id_ID')
                      .format(n.createdAt),
                  style:
                      AppText.caption.copyWith(color: AppColors.slate600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: 'Tutup',
                onTap: () => Navigator.pop(context),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
          ],
        ),
      ),
    );
  }
}