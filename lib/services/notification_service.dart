import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ignore: unused_field
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  // ignore: unused_field
  final int _retentionId = 999;

  Future<void> init() async {
    // TODO: re-enable when flutter_local_notifications build errors are resolved
    // const AndroidInitializationSettings androidSettings =
    //     AndroidInitializationSettings('@mipmap/ic_launcher');
    // const InitializationSettings initializationSettings = InitializationSettings(
    //   android: androidSettings,
    // );
    // await _plugin.initialize(initializationSettings);
  }

  Future<void> manageAppNotifications(bool isPremium) async {
    // TODO: re-enable when flutter_local_notifications build errors are resolved
    // if (isPremium) {
    //   await _plugin.cancelAll();
    // } else {
    //   await _plugin.cancel(_retentionId);
    //   const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    //     'kitchy_retention_channel',
    //     'Lembretes Kitchy',
    //     channelDescription: 'Canal focado em trazer utilizadores Free de volta',
    //     importance: Importance.max,
    //     priority: Priority.high,
    //   );
    //   const NotificationDetails details = NotificationDetails(android: androidDetails);
    //   await _plugin.show(
    //     _retentionId,
    //     'Sem ideias para o jantar? 🍽️',
    //     'Digita os teus ingredientes no Kitchy e deixa a IA cozinhar!',
    //     details,
    //   );
    // }
  }
}
