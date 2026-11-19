import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification channel configurations and NotificationDetails definitions.
class NotificationChannels {
  NotificationChannels._();

  static const String channelId = 'campus_tracker_reminders';
  static const String channelName = 'Task Reminders';
  static const String channelDescription =
      'Notifications and scheduled reminders for campus tasks, classes, and exams';
  static const String attendanceCategory = 'uniro_attendance_prompt';

  static const AndroidNotificationChannel defaultAndroidChannel =
      AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static const NotificationDetails taskDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static const NotificationDetails greetingDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static const NotificationDetails attendanceDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'attended',
          'Attended',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'missed',
          'Missed',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: attendanceCategory,
    ),
  );

  static InitializationSettings createInitializationSettings() {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          attendanceCategory,
          actions: [
            DarwinNotificationAction.plain(
              'attended',
              'Attended',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'missed',
              'Missed',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    return InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
  }
}
