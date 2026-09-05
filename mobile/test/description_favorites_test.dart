import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('description favorites add and remove', () async {
    final db = await AppDatabase.openMemory();

    await db.addDescriptionFavorite('Groceries');
    await db.addDescriptionFavorite('Uber');

    var favorites = await db.getDescriptionFavorites();
    expect(favorites.map((f) => f.text).toList(), containsAll(['Groceries', 'Uber']));

    final uber = favorites.firstWhere((f) => f.text == 'Uber');
    await db.removeDescriptionFavorite(uber.id);
    favorites = await db.getDescriptionFavorites();
    expect(favorites.map((f) => f.text).toList(), ['Groceries']);
  });
}
