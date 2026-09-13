/// Builds A1 ranges for Google Sheets API (handles sheet titles with spaces).
String formatSheetRange(String sheetTitle, String a1Range) {
  final title = sheetTitle.trim();
  if (title.isEmpty) return a1Range;
  if (RegExp(r'^[A-Za-z0-9_]+$').hasMatch(title)) {
    return '$title!$a1Range';
  }
  final escaped = title.replaceAll("'", "''");
  return "'$escaped'!$a1Range";
}
