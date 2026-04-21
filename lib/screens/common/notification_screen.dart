import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/notification_model.dart';
import '../../services/database_service.dart';

class NotificationScreen extends StatelessWidget {
  final String userId;

  const NotificationScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              // Mark all as read
              final notifications =
                  await dbService.getNotifications(userId).first;
              for (final n in notifications) {
                if (!n.isReadBy(userId)) {
                  await dbService.markNotificationAsRead(n.id, userId);
                }
              }
            },
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: dbService.getNotifications(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64, color: AppTheme.greyColor),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll be notified about updates here',
                    style: TextStyle(color: AppTheme.greyColor),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isRead = notification.isReadBy(userId);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isRead
                      ? (isDark ? const Color(0xFF1F2937) : Colors.white)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: isRead
                      ? null
                      : Border.all(
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: isRead
                          ? null
                          : AppTheme.primaryGradient,
                      color: isRead
                          ? AppTheme.greyColor.withValues(alpha: 0.2)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.notifications,
                      color: isRead ? AppTheme.greyColor : Colors.white,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight:
                          isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notification.message),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 14, color: AppTheme.greyColor),
                          const SizedBox(width: 4),
                          Text(
                            notification.senderName,
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.greyColor),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('MMM d, h:mm a')
                                .format(notification.createdAt),
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.greyColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!isRead) {
                      dbService.markNotificationAsRead(
                          notification.id, userId);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
