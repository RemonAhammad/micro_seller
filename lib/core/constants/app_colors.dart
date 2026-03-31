import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF00897B);
  static const primaryDark = Color(0xFF00695C);
  static const primaryLight = Color(0xFF4DB6AC);
  static const accent = Color(0xFF00BFA5);

  // Status colors
  static const statusPending = Color(0xFFFFC107);
  static const statusConfirmed = Color(0xFF2196F3);
  static const statusShipped = Color(0xFF9C27B0);
  static const statusCompleted = Color(0xFF4CAF50);
  static const statusCancelled = Color(0xFFF44336);

  // Payment status colors
  static const paymentUnpaid = Color(0xFFF44336);
  static const paymentPartial = Color(0xFFFF9800);
  static const paymentPaid = Color(0xFF4CAF50);

  // Customer tag colors
  static const tagNew = Color(0xFF42A5F5);
  static const tagRegular = Color(0xFF66BB6A);
  static const tagVip = Color(0xFFFFD54F);

  // Chart colors
  static const chartRevenue = Color(0xFF00897B);
  static const chartProfit = Color(0xFF42A5F5);

  // Gradient
  static const dashboardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00897B), Color(0xFF004D40)],
  );

  static const cardGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5F5F5), Color(0xFFEEEEEE)],
  );
}
