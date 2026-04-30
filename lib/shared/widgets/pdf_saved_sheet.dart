import 'dart:async';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../../core/constants/app_strings.dart';

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
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(s.close)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(context).maybePop();
                      await OpenFile.open(widget.filePath);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(s.tr('open')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
