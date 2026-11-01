import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:isar_community/isar.dart';
import '../models/product.dart';
import '../models/order.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _initFuture;

  static Future<void> init() => _initFuture ??= _initialize();

  static Future<void> _initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );
  }

  static Future<void> showLowStockAlert(List<Product> products) async {
    if (products.isEmpty) return;

    final names = products.take(3).map((p) => p.name).join(', ');
    final extra =
        products.length > 3 ? ' and ${products.length - 3} more' : '';

    await _plugin.show(
      id: 1,
      title: 'Low Stock Alert',
      body: '$names$extra ${products.length == 1 ? "is" : "are"} running low',
      notificationDetails: const NotificationDetails(
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
      id: 2,
      title: 'Payment Reminder',
      body: '$unpaidCount unpaid order${unpaidCount == 1 ? "" : "s"} with outstanding balance',
      notificationDetails: const NotificationDetails(
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

  static Future<void> showAutoBackupPaused() async {
    await _plugin.show(
      id: 3,
      title: 'Auto backup paused',
      body: 'Sign in to Google Drive again to resume backups.',
      notificationDetails: const NotificationDetails(
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

  static Future<void> checkAndNotify(Isar isar,
      {List<Product>? lowStock}) async {

    final init = _initFuture;
    if (init == null) return;
    try {
      await init;
    } catch (_) {
      return;
    }

    final lowStockProducts = lowStock ??
        (await isar.products.filter().isActiveEqualTo(true).findAll())
            .where((p) => p.isLowStock || p.isOutOfStock)
            .toList();
    if (lowStockProducts.isNotEmpty) {
      await showLowStockAlert(lowStockProducts);
    }

    final unpaidCount = await isar.orders
        .filter()
        .not()
        .paymentStatusEqualTo(PaymentStatus.paid)
        .not()
        .orderStatusEqualTo(OrderStatus.cancelled)
        .count();
    if (unpaidCount > 0) {
      await showPaymentReminder(unpaidCount, 0);
    }
  }
}
