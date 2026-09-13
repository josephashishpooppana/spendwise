/// Weekly Google Drive backup file naming (one file per ISO week).
class DriveBackupNaming {
  DriveBackupNaming._();

  static const prefix = 'spendwise-backup-';

  /// e.g. `spendwise-backup-2026-W36.json` — new name each ISO week (Monday start).
  static String weeklyFileName([DateTime? when]) {
    final (year, week) = isoWeekParts(when ?? DateTime.now());
    final weekStr = week.toString().padLeft(2, '0');
    return '$prefix$year-W$weekStr.json';
  }

  /// ISO 8601 week-year and week number.
  static (int weekYear, int weekNumber) isoWeekParts(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final monday = local.subtract(Duration(days: local.weekday - DateTime.monday));
    final thursday = monday.add(const Duration(days: 3));
    final weekYear = thursday.year;
    final jan4 = DateTime(weekYear, 1, 4);
    final firstMonday = jan4.subtract(Duration(days: jan4.weekday - DateTime.monday));
    final weekNumber = 1 + monday.difference(firstMonday).inDays ~/ 7;
    return (weekYear, weekNumber);
  }
}
