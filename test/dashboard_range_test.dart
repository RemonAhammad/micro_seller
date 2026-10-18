import 'package:flutter_test/flutter_test.dart';
import 'package:micro_seller/features/dashboard/providers/dashboard_provider.dart';

void main() {
  // Sunday 18 Oct 2026, 14:30.
  final now = DateTime(2026, 10, 18, 14, 30);

  // A preset picked days ago keeps those dates in the notifier.
  DashboardRange picked(DateRangePreset preset) =>
      (start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30, 9), preset: preset);

  test('presets mean "now", however long ago they were picked', () {
    expect(resolveDashboardRange(picked(DateRangePreset.today), now),
        (start: DateTime(2026, 10, 18), end: now));
    expect(resolveDashboardRange(picked(DateRangePreset.thisWeek), now),
        (start: DateTime(2026, 10, 12), end: now)); // Monday
    expect(resolveDashboardRange(picked(DateRangePreset.thisMonth), now),
        (start: DateTime(2026, 10, 1), end: now));
  });

  test('a custom range is kept as picked', () {
    final r = resolveDashboardRange(picked(DateRangePreset.custom), now);
    expect(r, (start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30, 9)));
  });

  test('this week starts on Monday, including on a Monday', () {
    final monday = DateTime(2026, 10, 12, 8);
    expect(resolveDashboardRange(picked(DateRangePreset.thisWeek), monday).start,
        DateTime(2026, 10, 12));
  });
}
