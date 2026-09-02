import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/integrations/drive_backup_naming.dart';

void main() {
  test('same ISO week produces same filename', () {
    final monday = DateTime(2026, 9, 7);
    final wednesday = DateTime(2026, 9, 9);
    expect(
      DriveBackupNaming.weeklyFileName(monday),
      DriveBackupNaming.weeklyFileName(wednesday),
    );
  });

  test('new week produces new filename', () {
    final lastWeek = DateTime(2026, 9, 7);
    final nextWeek = DateTime(2026, 9, 14);
    expect(
      DriveBackupNaming.weeklyFileName(lastWeek),
      isNot(DriveBackupNaming.weeklyFileName(nextWeek)),
    );
  });

  test('filename format includes ISO week-year and week number', () {
    final name = DriveBackupNaming.weeklyFileName(DateTime(2026, 9, 2));
    expect(name, matches(RegExp(r'^spendwise-backup-\d{4}-W\d{2}\.json$')));
  });
}
