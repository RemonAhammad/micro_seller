import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand: the Teal color theme's fixed values (`BrandColors.teal`). Widgets
  // read the active theme's instead, `context.brand` or the color scheme;
  // these stay for what never follows a theme (the first-launch splash, the
  // "Powered by Micro Seller" watermark, launcher and native splash colors).

  /// Teal's main color.
  static const primary = Color(0xFF00897B);

  /// A darker teal (Teal's `BrandColors.primaryDark`).
  static const primaryDark = Color(0xFF00695C);

  /// A lighter teal: Teal's dark-mode main color (`BrandColors.primaryLight`).
  static const primaryLight = Color(0xFF4DB6AC);

  /// Teal's accent.
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

  // Chart colors: fixed data-series colors, never themed.
  static const chartRevenue = Color(0xFF00897B);
  static const chartProfit = Color(0xFF42A5F5);

  /// Teal's header gradient (`BrandColors.teal.gradient`); headers read
  /// `context.brand.gradient`.
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
