import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  /// Check for Play Store updates and prompt the user.
  /// - Immediate updates for critical versions (priority >= 4)
  /// - Flexible updates for normal versions
  static Future<void> checkForUpdate() async {
    if (!Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      debugPrint('[UpdateService] Update available: ${info.updateAvailability}');
      debugPrint('[UpdateService] Update priority: ${info.updatePriority}');

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          // For high-priority updates, force immediate
          if (info.updatePriority >= 4) {
            await InAppUpdate.performImmediateUpdate();
            return;
          }
        }

        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          // After download, prompt to install
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Update check failed: $e');
      // Silently fail — don't disrupt the user experience
    }
  }
}
