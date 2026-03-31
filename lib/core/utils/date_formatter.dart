import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final _displayFormat = DateFormat('dd MMM yyyy');
  static final _displayWithTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _shortFormat = DateFormat('dd MMM');
  static final _monthYear = DateFormat('MMM yyyy');
  static final _backupFormat = DateFormat('yyyyMMdd_HHmm');

  static String format(DateTime? date) {
    if (date == null) return '—';
    return _displayFormat.format(date);
  }

  static String formatWithTime(DateTime? date) {
    if (date == null) return '—';
    return _displayWithTime.format(date);
  }

  static String formatShort(DateTime? date) {
    if (date == null) return '—';
    return _shortFormat.format(date);
  }

  static String formatMonthYear(DateTime date) {
    return _monthYear.format(date);
  }

  static String formatForBackup(DateTime date) {
    return _backupFormat.format(date);
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
  }
}
