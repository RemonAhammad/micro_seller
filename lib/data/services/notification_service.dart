import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar_community/isar.dart';
import '../models/product.dart';
import '../models/order.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );
    _initialized = true;
  }

  static Future<void> showLowStockAlert(List<Product> products) async {
    if (products.isEmpty) return;

    final names = products.take(3).map((p) => p.name).join(', ');
    final extra =
        products.length > 3 ? ' and ${products.length - 3} more' : '';

    await _plugin.show(
      1,
      'Low Stock Alert',
      '$names$extra ${products.length == 1 ? "is" : "are"} running low',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'low_stock',
          'Low Stock Alerts',
          channelDescription: 'Notifications for low stock products',
          importance: Importance.high,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showPaymentReminder(
      int unpaidCount, double totalDue) async {
    if (unpaidCount == 0) return;

    await _plugin.show(
      2,
      'Payment Reminder',
      '$unpaidCount unpaid order${unpaidCount == 1 ? "" : "s"} with outstanding balance',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'payment_reminder',
          'Payment Reminders',
          channelDescription: 'Notifications for unpaid orders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Fired by the background WorkManager worker when Drive access is no
  /// longer usable (silent sign-in returned null, account revoked the
  /// scope, or Play Services raised DEVELOPER_ERROR). Tapping the
  /// notification opens the app, where Settings → Drive shows a banner
  /// with a "Sign in" button to restore the connection.
  static Future<void> showAutoBackupPaused() async {
    await _plugin.show(
      3,
      'Auto backup paused',
      'Sign in to Google Drive again to resume backups.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'auto_backup',
          'Auto Backup',
          channelDescription:
              'Alerts when scheduled Drive backups need your attention',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Check and trigger notifications based on current data
  static Future<void> checkAndNotify(Isar isar) async {
    // Low stock check
    final products =
        await isar.products.filter().isActiveEqualTo(true).findAll();
    final lowStock =
        products.where((p) => p.isLowStock || p.isOutOfStock).toList();
    if (lowStock.isNotEmpty) {
      await showLowStockAlert(lowStock);
    }

    // Unpaid orders check
    final unpaidOrders = await isar.orders
        .filter()
        .not()
        .paymentStatusEqualTo(PaymentStatus.paid)
        .not()
        .orderStatusEqualTo(OrderStatus.cancelled)
        .findAll();
    if (unpaidOrders.isNotEmpty) {
      final totalDue = unpaidOrders.fold(0.0, (s, o) => s + o.balanceDue);
      await showPaymentReminder(unpaidOrders.length, totalDue);
    }
  }
}
