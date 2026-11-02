import 'package:flutter/material.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/extensions/context_extensions.dart';

final kFirstEntryDate = DateTime(2020);

String formatEntryDateTime(BuildContext context, DateTime value) {
  final loc = MaterialLocalizations.of(context);
  final time = loc.formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return AppStrings.of(context).dateAtTime(loc.formatShortDate(value), time);
}

Future<DateTime?> pickEntryDateTime(
  BuildContext context, {
  required DateTime initial,
  DateTime? first,
}) async {
  final earliest = first ?? kFirstEntryDate;
  final firstDay = DateTime(earliest.year, earliest.month, earliest.day);
  var now = DateTime.now();
  final start = initial.isBefore(earliest)
      ? earliest
      : initial.isAfter(now)
          ? now
          : initial;

  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: firstDay,
    lastDate: now,
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null || !context.mounted) return null;

  // The seconds of [start] keep entries picked for the same minute apart.
  final picked = DateTime(date.year, date.month, date.day, time.hour,
      time.minute, start.second, start.millisecond, start.microsecond);
  now = DateTime.now();
  final value = snapEntryDateTime(picked, earliest: earliest, now: now);
  if (value == null) {
    final s = AppStrings.of(context);
    context.showErrorSnackBar(picked.isAfter(now)
        ? s.entryDateInFuture
        : s.entryDateTooEarly(formatEntryDateTime(context, earliest)));
  }
  return value;
}

@visibleForTesting
DateTime? snapEntryDateTime(DateTime picked,
    {required DateTime earliest, required DateTime now}) {
  bool sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  if (picked.isAfter(now)) return sameMinute(picked, now) ? now : null;
  if (picked.isBefore(earliest)) {
    return sameMinute(picked, earliest) ? earliest : null;
  }
  return picked;
}

class EntryDateField extends StatelessWidget {
  const EntryDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.first,
    this.onReset,
    this.hint,
  });

  final String label;
  final DateTime? value;
  final DateTime? first;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback? onReset;
  final String? hint;

  Future<void> _pick(BuildContext context) async {
    final picked = await pickEntryDateTime(
      context,
      initial: value ?? DateTime.now(),
      first: first,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    final current = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pick(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  ThinIcon(tabler.CalendarTime.new, color: cs.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted)),
                        Text(
                          current == null
                              ? s.entryDateNow
                              : formatEntryDateTime(context, current),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (current != null && onReset != null)
                    IconButton(
                      tooltip: s.entryDateUseNow,
                      onPressed: onReset,
                      icon: ThinIcon(tabler.X.new, size: 18, color: cs.outline),
                    )
                  else
                    ThinIcon(tabler.ChevronRight.new, size: 20, color: cs.outline),
                ],
              ),
            ),
          ),
        ),
        if (current == null && hint != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
            child: Text(hint!,
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ),
      ],
    );
  }
}
