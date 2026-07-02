import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// =============================================================================
// NOTIFICATION SERVICE — Monetisation & Retention
// =============================================================================
// Controls local notifications exclusively around the user's subscription plan.
//
// Strategy
// --------
// FREE  users  → Schedule a recurring "come back" reminder every 3 days at
//                19:00 to re-engage them and drive ad impressions.
// PREMIUM users → Cancel ALL pending notifications immediately. Never bother
//                 paying customers — unsolicited reminders are a known driver
//                 of subscription cancellations.
//
// Call sites (both mandatory)
// ---------------------------
// 1. main()    → NotificationService.initialize()
// 2. initState → after loadUserStatus() resolves, call
//                NotificationService.manageAppNotifications(isPremium)
// 3. onPurchaseSuccess → call manageAppNotifications(true) immediately so
//                        notifications are cleared before the UI updates.
//
// Platform notes
// --------------
// Android: Targets API 33+. Uses inexactAllowWhileIdle so no
//   SCHEDULE_EXACT_ALARM permission is required in the manifest.
//   Channel "kitchy_retention" is created on first notification.
// iOS: Requests alert/badge/sound permissions on first initialize() call.
//   No extra Info.plist keys needed for local notifications.
//
// Timezone handling
// -----------------
// We use Dart's built-in DateTime.timeZoneOffset to convert the desired
// local 19:00 target to a UTC TZDateTime — this is accurate for scheduling
// without needing the flutter_timezone package.
// =============================================================================

class NotificationService {
  NotificationService._(); // pure static API — never instantiated

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Stable ID for the recurring retention notification.
  // Using a fixed ID means rescheduling automatically replaces the previous
  // pending notification rather than stacking duplicates.
  static const int _retentionId = 1001;

  // Android notification channel
  static const String _channelId   = 'kitchy_retention';
  static const String _channelName = 'Lembretes de receitas';
  static const String _channelDesc =
      'Lembretes periódicos para trazer utilizadores Free de volta à app.';

  // ============================================================================
  // INITIALIZE — call once in main(), after WidgetsFlutterBinding.ensureInitialized()
  // ============================================================================
  static Future<void> initialize() async {
    // Load the full IANA timezone database.
    // latest_all.dart ships all historical zones (~600 KB); use latest_10y.dart
    // for a smaller bundle if size is a concern.
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Request all permissions up-front on iOS so the user sees the system
    // prompt on first launch. We request sound + alert + badge together to
    // avoid multiple prompts.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    debugPrint('[NotificationService] Inicializado com sucesso.');
  }

  // ============================================================================
  // MAIN CONTROL FUNCTION — call after every plan status change
  // ============================================================================
  /// Evaluates [isPremium] and applies the correct notification policy.
  ///
  /// - [isPremium] == true  → cancel everything immediately.
  /// - [isPremium] == false → schedule (or reschedule) the 3-day retention alert.
  ///
  /// Always safe to call multiple times — rescheduling cancels the previous
  /// pending notification before creating a new one.
  static Future<void> manageAppNotifications(bool isPremium) async {
    if (isPremium) {
      await _cancelAllNotifications();
    } else {
      await _scheduleRetentionNotification();
    }
  }

  // ============================================================================
  // PREMIUM PATH — cancel everything
  // ============================================================================
  static Future<void> _cancelAllNotifications() async {
    await _plugin.cancelAll();
    debugPrint(
      '[NotificationService] User Premium: Bypass de anúncios ativado. '
      'Todas as notificações pendentes foram canceladas.',
    );
  }

  // ============================================================================
  // FREE PATH — schedule 3-day retention notification at 19:00 local time
  // ============================================================================
  static Future<void> _scheduleRetentionNotification() async {
    // Cancel the previous pending notification first.
    // This prevents duplicates when manageAppNotifications() is called on each
    // app open, and also resets the 3-day countdown from today.
    await _plugin.cancel(_retentionId);

    // ── Build the target TZDateTime ─────────────────────────────────────────
    // We want "3 days from now at 19:00" in the device's local timezone.
    // Dart's DateTime carries the local UTC offset in .timeZoneOffset, so we:
    //   1. Build the local target (today + 3 days @ 19:00) as a plain DateTime
    //   2. Subtract the offset to get the equivalent UTC instant
    //   3. Wrap it in a TZDateTime.utc() so the plugin uses it correctly
    final now    = DateTime.now();
    final offset = now.timeZoneOffset; // e.g. Duration(hours: 1) for UTC+1

    final localTarget = DateTime(
      now.year, now.month, now.day, 19, 0, 0,
    ).add(const Duration(days: 3));

    final utcTarget = localTarget.subtract(offset);

    final tzTarget = tz.TZDateTime.utc(
      utcTarget.year, utcTarget.month, utcTarget.day,
      utcTarget.hour, utcTarget.minute,
    );

    // ── Notification details ─────────────────────────────────────────────────
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        // Use the default app icon; swap for a food-themed icon when available.
        icon: '@mipmap/ic_launcher',
        // Show a subtle orange accent that matches the app brand colour.
        color: Color(0xFFFF7043),
        // Keep it concise — heads-up notifications truncate long text on lock screen.
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );

    await _plugin.zonedSchedule(
      _retentionId,
      'Kitchy 🍳',
      'Sem ideias para o jantar? 🍽️ Digita os teus ingredientes e deixa a IA cozinhar!',
      tzTarget,
      details,
      // inexactAllowWhileIdle: delivers when the device next wakes for a
      // maintenance window — no exact-alarm permission needed on Android 12+.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    debugPrint(
      '[NotificationService] Notificação de retenção agendada para: '
      '${localTarget.toIso8601String()} (hora local) — '
      '${tzTarget.toIso8601String()} (UTC)',
    );
  }
}
