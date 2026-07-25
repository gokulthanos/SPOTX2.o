import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/storage_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    final auth = context.read<AuthProvider>();
    final contact = auth.passengerContact;
    final raw = StorageService.getWalletTransactions('${contact}_notifications');
    setState(() => _notifications = raw.cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(title: const Text('Notifications')),
      body: _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey[200]),
                  const SizedBox(height: 12),
                  Text('No notifications yet', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, i) {
                final n = _notifications[i];
                final type = n['type'] ?? 'info';
                final icon = type == 'alert' ? Icons.warning_amber_rounded
                    : type == 'ticket' ? Icons.confirmation_num_rounded
                    : Icons.info_outline_rounded;
                final color = type == 'alert' ? AppTheme.error
                    : type == 'ticket' ? AppTheme.primaryBlue
                    : AppTheme.primaryLight;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['title'] ?? 'Notification', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Text(n['body'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text(n['timestamp'] ?? '', style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
