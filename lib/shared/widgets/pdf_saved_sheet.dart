import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_strings.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../core/constants/app_icons.dart';
import 'app_button.dart';

/// Whether "Download PDF" asks where to save each time, in the system's save
/// sheet ([savePdfWithSystemSheet]), instead of writing into the folder picked
/// once (Settings → PDF download folder, which is then hidden). True on iOS:
/// a folder picked there can't be written to (the picker hands back a bare
/// path, without the security-scoped access writing needs), and no picked
/// folder is reachable on a later launch.
bool get pdfDownloadAsksWhereToSave =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// "Download PDF" where [pdfDownloadAsksWhereToSave]: offers [bytes] as
/// [fileName] in the system's save sheet (on iOS, Files: On My iPhone,
/// iCloud Drive, …), which is its own confirmation. When that sheet can't
/// open, the share sheet instead, which has Save to Files too, pointing on
/// an iPad at [shareOrigin], the rect of the control that was tapped
/// (`shareOriginOf`). Returns whether the PDF was saved or shared (false
/// when the user cancels).
Future<bool> savePdfWithSystemSheet({
  required String fileName,
  required Uint8List bytes,
  Rect? shareOrigin,
}) async {
  try {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/pdf',
    );
    return saved != null;
  } on Exception catch (e, st) {
    developer.log(
      'save sheet failed, sharing instead',
      name: 'PdfDownload',
      error: e,
      stackTrace: st,
    );
  }
  // A folder of its own in the system temp folder (the app's tmp/ on iOS),
  // so the shared file keeps [fileName], as local backups do.
  final dir = await Directory.systemTemp.createTemp('microseller_pdf');
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      sharePositionOrigin: shareOrigin,
    ),
  );
  return result.status == ShareResultStatus.success;
}

/// Shows a modal bottom sheet confirming a PDF was saved, with an "Open"
/// action and an automatic 5-second dismiss.
///
/// Replaces the SnackBar previously used here — Material's SnackBar duration
/// turned out to be unreliable on some Android skins (notably MIUI), where
/// the dismiss timer can be paused indefinitely. A modal sheet with our own
/// `Timer` cancels and pops the route after exactly 5 seconds, no matter
/// what the OS does.
Future<void> showPdfSavedSheet({
  required BuildContext context,
  required String filePath,
  required String savedToDirectory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => _PdfSavedSheet(filePath: filePath, savedToDirectory: savedToDirectory),
  );
}

class _PdfSavedSheet extends StatefulWidget {
  final String filePath;
  final String savedToDirectory;
  const _PdfSavedSheet({required this.filePath, required this.savedToDirectory});

  @override
  State<_PdfSavedSheet> createState() => _PdfSavedSheetState();
}

class _PdfSavedSheetState extends State<_PdfSavedSheet> {
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _autoCloseTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    // Cancel the timer if the user dismissed the sheet themselves (drag,
    // tap-outside, Open button) so we don't try to pop a closed route.
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const ThinIcon(tabler.CircleCheck.new, color: Colors.green, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.pdfSavedTo, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        widget.savedToDirectory,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Side by side, or stacked when a label wouldn't fit its half.
            ButtonPair(
              first: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(s.close)),
              second: FilledButton.icon(
                onPressed: () async {
                  Navigator.of(context).maybePop();
                  await OpenFile.open(widget.filePath);
                },
                icon: const ThinIcon(tabler.ExternalLink.new, size: 18),
                label: Text(s.tr('open')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
