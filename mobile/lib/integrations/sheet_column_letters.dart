/// A1-style column letter helpers for Google Sheets.
class SheetColumnLetters {
  static int columnLetterToIndex(String letter) {
    var index = 0;
    for (var i = 0; i < letter.length; i++) {
      index = index * 26 + (letter.codeUnitAt(i) - 64);
    }
    return index - 1;
  }

  static String indexToColumnLetter(int index) {
    var n = index + 1;
    final chars = <int>[];
    while (n > 0) {
      n--;
      chars.insert(0, 65 + (n % 26));
      n ~/= 26;
    }
    return String.fromCharCodes(chars);
  }
}

/// Known sheet layout for the user's original seven accounts (columns A–Z).
class LegacySheetColumnBackfill {
  static const metadataStartAfterLegacy = 26; // column AA

  static const bySourceName = <String, (String credit, String debit, String balance)>{
    'Federal Bank Credit Card': ('N', 'O', 'P'),
    'HDFC Bank Credit Card': ('Q', 'R', 'S'),
    'ICICI Bank Credit Card': ('T', 'U', 'V'),
    'ICICI Bank': ('D', 'E', 'F'),
    'Cash In Hand': ('W', 'X', 'Y'),
    'BOB': ('G', 'H', 'I'),
    'HDFC': ('J', 'K', 'L'),
  };

  static (String, String, String)? columnsForName(String name) {
    for (final entry in bySourceName.entries) {
      if (name.contains(entry.key) || entry.key.contains(name)) {
        return entry.value;
      }
    }
    return null;
  }
}
