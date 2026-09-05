import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/database.dart';

void main() {
  test('description favorites add and remove', () async {
    final db = await AppDatabase.openMemory();

    await db.addDescriptionFavorite('Groceries');
    await db.addDescriptionFavorite('Uber');

    var favorites = await db.getDescriptionFavorites();
    expect(favorites.map((f) => f.text), containsAll(['Groceries', 'Uber']));

    await db.removeDescriptionFavorite(favorites.first.id);
    favorites = await db.getDescriptionFavorites();
    expect(favorites.length, 1);
  });
}
