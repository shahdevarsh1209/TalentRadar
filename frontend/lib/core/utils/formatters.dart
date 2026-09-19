/// Display formatting shared by every screen, in the design's voice:
/// "₹22k–28k", "0.9 km", "Thu, 25 Sept", "2 days ago".
abstract final class Fmt {
  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _weekdaysLong = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'June', 'July', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec',
  ];

  static String _k(int value) {
    if (value >= 100000) {
      final lakhs = value / 100000;
      return '${lakhs.toStringAsFixed(lakhs >= 10 ? 0 : 1)}L';
    }
    if (value >= 1000) return '${(value / 1000).round()}k';
    return '$value';
  }

  /// Monthly salary band, or null when none was given.
  static String? salary(int? min, int? max) {
    if (min == null && max == null) return null;
    if (min != null && max != null) return '₹${_k(min)}–${_k(max)}';
    if (min != null) return 'From ₹${_k(min)}';
    return 'Up to ₹${_k(max!)}';
  }

  static String distance(double? km) {
    if (km == null) return '';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// "Today", "Tomorrow" or "Thu, 25 Sept".
  static String day(DateTime date) {
    final now = DateTime.now();
    if (_sameDay(date, now)) return 'Today';
    if (_sameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
    return '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';
  }

  /// "Thursday, 25 Sept".
  static String dayLong(DateTime date) =>
      '${_weekdaysLong[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

  /// "3:00 PM".
  static String time(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
  }

  /// "10:00" (24h, as stored) → "10 AM" / "10:30 AM".
  static String clock(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final display = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return minute == 0 ? '$display $suffix' : '$display:${parts[1]} $suffix';
  }

  /// Chat-list timestamp: "9:30 AM", "Yesterday", "Thu, 25 Sept".
  static String chatStamp(DateTime date) {
    final now = DateTime.now();
    if (_sameDay(date, now)) return time(date);
    if (_sameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return day(date);
  }

  static String ago(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return day(date);
  }

  static String plural(int count, String one, [String? many]) =>
      '$count ${count == 1 ? one : (many ?? '${one}s')}';

  /// Three-letter company badge: "BrightDesk Support" → "BRI".
  static String companyCode(String name) {
    final letters = name.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return 'CO';
    return letters.substring(0, letters.length >= 3 ? 3 : letters.length).toUpperCase();
  }
}
