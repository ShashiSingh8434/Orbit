abstract final class OrbitDateUtils {
  /// Returns today's Firestore date key (e.g. `"2026-06-27"`).
  static String todayKey() => dateKey(DateTime.now());

  /// Returns a Firestore date key for [date] (e.g. `"2026-06-27"`).
  static String dateKey(DateTime date) {
    final d = date.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Parses a Firestore date key string into a [DateTime].
  static DateTime parseKey(String key) => DateTime.parse(key);

  /// Returns a human-readable label for a date key (e.g. `"Today"`,
  /// `"Yesterday"`, `"Mon, Jun 26"`).
  static String friendlyLabel(String dateKey) {
    final date = parseKey(dateKey);
    final today = DateTime.now();
    final todayKey = OrbitDateUtils.dateKey(today);
    final yesterdayKey = OrbitDateUtils.dateKey(today.subtract(const Duration(days: 1)));

    if (dateKey == todayKey) return 'Today';
    if (dateKey == yesterdayKey) return 'Yesterday';

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}
