class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);

  static DateRange today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return DateRange(start, end);
  }
   static DateRange forDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return DateRange(start, end);
  }
}
