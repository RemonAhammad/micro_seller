import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;

import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/order_item.dart' show warrantyEnd;
import '../../data/models/product_serial.dart';
import '../../data/services/serial_service.dart';
import '../screens/qr_scanner_screen.dart';
import 'app_button.dart';
import 'bottom_sheet_handle.dart';

String _key(String s) => normalizeSerial(s).toLowerCase();

/// A serial's status in the app's language, and its color.
(String, Color) serialStatusLabel(BuildContext context, SerialStatus status) {
  final s = AppStrings.of(context);
  return switch (status) {
    SerialStatus.inStock => (s.serialStatusInStock, AppColors.statusCompleted),
    SerialStatus.sold => (s.serialStatusSold, AppColors.statusConfirmed),
    SerialStatus.removed => (s.serialStatusRemoved, AppColors.statusCancelled),
  };
}

/// "Warranty until 17 Nov 2027" or "Warranty ended …" for a unit sold on
/// [soldAt] with [months] of warranty; null without one.
(String, bool)? warrantyText(BuildContext context, DateTime? soldAt, int months) {
  if (soldAt == null || months <= 0) return null;
  final s = AppStrings.of(context);
  final end = warrantyEnd(soldAt, months);
  final date = DateFormatter.format(end);
  final active = !end.isBefore(DateTime.now());
  return (active ? s.warrantyUntil(date) : s.warrantyExpiredOn(date), active);
}

/// The words for a serial-number error, or null for any other error.
String? serialErrorMessage(BuildContext context, Object error) {
  final s = AppStrings.of(context);
  return switch (error) {
    DuplicateSerialException(:final serial) => s.serialAlreadyAdded(serial),
    SerialNotAvailableException(:final serial, :final productName) =>
      s.serialNotAvailable(serial, productName),
    SerialsMissingException(:final productName) => s.serialsMissing(
      productName,
    ),
    _ => null,
  };
}

/// Opens the camera scanner; the trimmed code, or null.
Future<String?> _scan(BuildContext context) => Navigator.of(
  context,
).push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));

/// New serial numbers for [productName] (the product form, a purchase, a
/// restock): typed, pasted (one per line) or scanned. [taken] are the
/// serials the product already has, refused like a repeat. Returns the
/// whole list, or null when dismissed.
Future<List<String>?> showSerialEntrySheet(
  BuildContext context, {
  required String productName,
  List<String> initial = const [],
  Iterable<String> taken = const [],
}) => AppBottomSheet.show<List<String>>(
  context,
  title: productName,
  child: SerialEntrySheet(
    initial: initial,
    taken: {for (final t in taken) _key(t)},
  ),
);

/// Which of [available] (serials in stock, plus those already on this line)
/// go: checked in a list, searched, or scanned. Returns the picked ones in
/// [available]'s order, or null when dismissed.
Future<List<String>?> showSerialPickerSheet(
  BuildContext context, {
  required String productName,
  required List<String> available,
  List<String> selected = const [],
}) => AppBottomSheet.show<List<String>>(
  context,
  title: productName,
  child: SerialPickerSheet(available: available, selected: selected),
);

class SerialEntrySheet extends StatefulWidget {
  const SerialEntrySheet({
    super.key,
    this.initial = const [],
    this.taken = const {},
  });

  final List<String> initial;

  /// Lower-cased serials the product already has.
  final Set<String> taken;

  @override
  State<SerialEntrySheet> createState() => _SerialEntrySheetState();
}

class _SerialEntrySheetState extends State<SerialEntrySheet> {
  late final List<String> _serials = [...widget.initial];
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String text) {
    final s = AppStrings.of(context);
    final have = {for (final x in _serials) _key(x), ...widget.taken};
    final refused = <String>[];
    setState(() {
      // Every part, repeats included, so a repeat is reported, not dropped.
      final parts = [
        for (final p in text.split(RegExp(r'[\n\r,;\t]+')))
          if (normalizeSerial(p).isNotEmpty) normalizeSerial(p),
      ];
      for (final serial in parts) {
        if (have.add(_key(serial))) {
          _serials.add(serial);
        } else {
          refused.add(serial);
        }
      }
      _error = refused.isEmpty
          ? null
          : s.serialAlreadyAdded(refused.join(', '));
      _ctrl.clear();
    });
  }

  Future<void> _scanOne() async {
    final code = await _scan(context);
    if (code != null && mounted) _add(code);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          s.serialsOnePerUnit,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('serialEntryField'),
          controller: _ctrl,
          autofocus: widget.initial.isEmpty,
          minLines: 1,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: s.serialNumbers,
            hintText: s.serialFieldHint,
            errorText: _error,
            errorMaxLines: 3,
            suffixIcon: IconButton(
              tooltip: s.scanSerial,
              icon: const ThinIcon(tabler.Scan.new),
              onPressed: _scanOne,
            ),
          ),
          onSubmitted: _add,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            key: const ValueKey('serialEntryAdd'),
            onPressed: () => _add(_ctrl.text),
            icon: const ThinIcon(tabler.Plus.new, size: 18),
            label: Text(s.addSerials),
          ),
        ),
        if (_serials.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              s.noSerialsYet,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
        for (final (i, serial) in _serials.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text(
              '${i + 1}',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            minLeadingWidth: 24,
            title: Text(serial, textDirection: TextDirection.ltr),
            trailing: IconButton(
              tooltip: s.remove,
              icon: const ThinIcon(tabler.X.new, size: 18),
              onPressed: () => setState(() => _serials.removeAt(i)),
            ),
          ),
        const SizedBox(height: 12),
        AppButton(
          label: '${s.done} (${_serials.length})',
          onPressed: () {
            // Text still in the field is added first; a repeat in it keeps
            // the sheet open to say so. An earlier message doesn't.
            final pending = _ctrl.text;
            if (splitSerials(pending).isNotEmpty) {
              _add(pending);
              if (_error != null) return;
            }
            Navigator.of(context).pop(_serials);
          },
        ),
      ],
    );
  }
}

class SerialPickerSheet extends StatefulWidget {
  const SerialPickerSheet({
    super.key,
    required this.available,
    this.selected = const [],
  });

  final List<String> available;
  final List<String> selected;

  @override
  State<SerialPickerSheet> createState() => _SerialPickerSheetState();
}

class _SerialPickerSheetState extends State<SerialPickerSheet> {
  late final Set<String> _picked = {for (final x in widget.selected) _key(x)};
  final _search = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _scanOne() async {
    final code = await _scan(context);
    if (code == null || !mounted) return;
    final hit = widget.available
        .where((a) => _key(a) == _key(code))
        .firstOrNull;
    setState(() {
      if (hit == null) {
        _error = AppStrings.of(context).serialNotInStock(normalizeSerial(code));
      } else {
        _error = null;
        _picked.add(_key(hit));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final cs = Theme.of(context).colorScheme;
    final query = _key(_search.text);
    final shown = [
      for (final a in widget.available)
        if (query.isEmpty || _key(a).contains(query)) a,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.available.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              s.noSerialsInStock,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          )
        else ...[
          TextField(
            key: const ValueKey('serialSearchField'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: s.searchSerials,
              prefixIcon: const ThinIcon(tabler.Search.new, size: 20),
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: s.scanSerial,
                icon: const ThinIcon(tabler.Scan.new),
                onPressed: _scanOne,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final serial in shown)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _picked.contains(_key(serial)),
              title: Text(serial, textDirection: TextDirection.ltr),
              onChanged: (v) => setState(
                () => v == true
                    ? _picked.add(_key(serial))
                    : _picked.remove(_key(serial)),
              ),
            ),
        ],
        const SizedBox(height: 12),
        AppButton(
          label: '${s.done} · ${s.serialsSelected(_picked.length)}',
          onPressed: () => Navigator.of(context).pop([
            for (final a in widget.available)
              if (_picked.contains(_key(a))) a,
          ]),
        ),
      ],
    );
  }
}
