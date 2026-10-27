/// The update notice of installs no store updates (the iPhone app, and
/// Android APKs from GitHub): the Dashboard's banner ([UpdateNoticeBanner])
/// and the dialog Settings → Check for updates opens ([UpdateNoticeDialog]).
/// Both say how to install the new version over this one so the seller's
/// data stays, and Download opens the release's page, which lists its files.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../data/services/release_update_service.dart';
import '../../../shared/widgets/app_button.dart';

/// Opens [url], a release's page, in the browser. False when nothing could
/// open it.
Future<bool> openReleasePage(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// How to install an update over this install, keeping its data: with the
/// same sideloading tool and Apple ID on an iPhone or iPad, from the same
/// kind of APK on Android.
String _howTo(BuildContext context) {
  final s = AppStrings.of(context);
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? s.updateHowToIos
      : s.updateHowToAndroid;
}

/// Opens [update]'s page, or says that it couldn't.
Future<void> _download(BuildContext context, AvailableUpdate update) async {
  final s = AppStrings.of(context);
  if (await openReleasePage(update.url)) return;
  if (context.mounted) context.showErrorSnackBar(s.errorOccurred);
}

/// The Dashboard's notice of a newer release: what it is and how to install
/// it, Download, and ✕, which hides it until a newer release comes out
/// ([onDismiss]).
class UpdateNoticeBanner extends StatelessWidget {
  const UpdateNoticeBanner({
    super.key,
    required this.update,
    required this.onDismiss,
  });

  final AvailableUpdate update;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final brand = context.brand;
    return Material(
      color: brand.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: ThinIcon(AppIcons.update, color: brand.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              // The button goes under the texts, not beside them, so a
              // narrow screen at a large text size still has room for both.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.updateAvailable(update.version),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _howTo(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _download(context, update),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(s.download),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: s.dismiss,
              visualDensity: VisualDensity.compact,
              icon: const ThinIcon(tabler.X.new, size: 20),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings → Check for updates' answer when there is a newer release: what
/// it is and how to install it, with Close and Download.
class UpdateNoticeDialog extends StatelessWidget {
  const UpdateNoticeDialog({super.key, required this.update});

  final AvailableUpdate update;

  /// Shows the dialog for [update]; its Download opens the release's page.
  static Future<void> show(BuildContext context, AvailableUpdate update) async {
    final download = await showDialog<bool>(
      context: context,
      builder: (_) => UpdateNoticeDialog(update: update),
    );
    if (download == true && context.mounted) {
      await _download(context, update);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      // The how-to scrolls above the buttons when the dialog can't fit it
      // (a large text size on a short or zoomed-in screen).
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      icon: ThinIcon(AppIcons.update, size: 40, color: context.brand.primary),
      title: Text(
        s.updateAvailable(update.version),
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        _howTo(context),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.center,
      ),
      actions: [
        // Side by side, or stacked when a label wouldn't fit its half.
        ButtonPair(
          first: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.close),
          ),
          second: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.download),
          ),
        ),
      ],
    );
  }
}
