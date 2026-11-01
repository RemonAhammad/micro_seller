import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import 'release_update_service.dart';

class UpdateService {

  static Future<void> checkForUpdate({UpdateChannel? channel}) async {
    if ((channel ?? await readUpdateChannel()) != UpdateChannel.play) return;
    if (!Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      debugPrint('[UpdateService] Update available: ${info.updateAvailability}');
      debugPrint('[UpdateService] Update priority: ${info.updatePriority}');

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {

          if (info.updatePriority >= 4) {
            await InAppUpdate.performImmediateUpdate();
            return;
          }
        }

        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();

          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Update check failed: $e');

    }
  }
}
