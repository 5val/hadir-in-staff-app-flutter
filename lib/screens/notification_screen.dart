import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/common_widgets.dart';
import '../services/notification_service.dart';
import '../services/api_client.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _listController;
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;
  String _filter = 'Semua';
  String _scope = 'Diri Sendiri';

  bool get _isSupervisor => AppSession.isSupervisor;

  static const _filters = [
    'Semua',
    'Belum Dibaca',
    'Disetujui',
    'Ditolak',
    'Pengingat',
    'Info'
  ];

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _load();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await NotificationService.myNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = res.items;
        _loading = false;
      });
      _listController.forward(from: 0);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<AppNotification> get _filtered {
    List<AppNotification> list = _notifications;
    if (_isSupervisor) {
      if (_scope == 'Diri Sendiri') {
        list = list.where((n) => !n.isTeam).toList();
      } else {
        list = list.where((n) => n.isTeam).toList();
      }
    }

    switch (_filter) {
      case 'Belum Dibaca':
        return list.where((n) => !n.isRead).toList();
      case 'Disetujui':
        return list.where((n) => n.type == NotificationType.approval).toList();
      case 'Ditolak':
        return list.where((n) => n.type == NotificationType.rejection).toList();
      case 'Pengingat':
        return list.where((n) => n.type == NotificationType.reminder).toList();
      case 'Info':
        return list.where((n) => n.type == NotificationType.info).toList();
      default:
        return list;
    }
  }

  int get _unreadCount {
    var list = _notifications;
    if (_isSupervisor) {
      if (_scope == 'Diri Sendiri') {
        list = list.where((n) => !n.isTeam).toList();
      } else {
        list = list.where((n) => n.isTeam).toList();
      }
    }
    return list.where((n) => !n.isRead).length;
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationService.markAllRead();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                title: n.title,
                message: n.message,
                type: n.type,
                createdAt: n.createdAt,
                isRead: true,
                isTeam: n.isTeam,
              ))
          .toList();
    });
  }

  Future<void> _markRead(String id) async {
    try {
      await NotificationService.markRead(id);
    } on ApiException catch (_) {
      // Diamkan; tandai lokal saja bila gagal.
    }
    if (!mounted) return;
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
                  isTeam: n.isTeam,
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
        backgroundColor: AppColors.brandNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notifikasi',
                style: AppText.headline3
                    .copyWith(fontSize: 18, color: AppColors.white)),
            if (_unreadCount > 0)
              Text('$_unreadCount belum dibaca',
                  style: AppText.caption.copyWith(color: AppColors.white)),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Baca Semua',
                  style: AppText.caption.copyWith(
                      color: AppColors.slate200, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isSupervisor) ...[
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _scope = 'Diri Sendiri';
                          _filter = 'Semua';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _scope == 'Diri Sendiri'
                                ? AppColors.brandNavy
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Diri Sendiri',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _scope == 'Diri Sendiri'
                                  ? Colors.white
                                  : AppColors.slate700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _scope = 'Team Saya';
                          _filter = 'Semua';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _scope == 'Team Saya'
                                ? AppColors.brandNavy
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Team Saya',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _scope == 'Team Saya'
                                  ? Colors.white
                                  : AppColors.slate700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // ── Filter chips ──────────────────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                            color: selected ? Colors.white : AppColors.slate600,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
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
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.brandNavy))
                : _error != null
                    ? _buildErrorState()
                    : filtered.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final n = filtered[i];
                                return _buildCard(n, i);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.slate400),
              const SizedBox(height: 12),
              Text(_error ?? 'Gagal memuat notifikasi',
                  textAlign: TextAlign.center, style: AppText.body2),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 64, color: AppColors.slate600.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('Tidak ada notifikasi',
                style: AppText.body1.copyWith(color: AppColors.slate600)),
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
                  : Border.all(color: color.withOpacity(0.3), width: 1),
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
                                    color: AppColors.slate600, fontSize: 11)),
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
                          style: AppText.headline3.copyWith(
                              fontSize: 16, color: AppColors.slate900)),
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
                style: AppText.body1
                    .copyWith(color: AppColors.slate600, height: 1.6)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14, color: AppColors.slate600),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy · HH:mm', 'id_ID')
                      .format(n.createdAt),
                  style: AppText.caption.copyWith(color: AppColors.slate600),
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
