// Non-régression du nettoyage des ingrédients sur le jeu de données réel
// (BDD/, non versionné) : ignoré automatiquement si le CSV est absent (CI).
import 'dart:io';

import 'package:eco_diet_v0/pages/taste/taste_logic.dart';
import 'package:flutter_test/flutter_test.dart';

// Dans le repo ou à côté (dossier parent), selon l'installation.
final _path = ['BDD', '../BDD']
    .map((d) => '$d/DIM/DIM_INGREDIENTS.csv')
    .firstWhere((p) => File(p).existsSync(), orElse: () => '');
final _available = _path.isNotEmpty;

/// Libellés bruts : 2e colonne (la dernière), guillemets CSV retirés.
List<String> _rawIngredients() => File(_path)
    .readAsLinesSync()
    .skip(1)
    .where((l) => l.contains(','))
    .map((l) => l.substring(l.indexOf(',') + 1))
    .map((v) => v.startsWith('"') && v.endsWith('"') && v.length > 1
        ? v.substring(1, v.length - 1).replaceAll('""', '"')
        : v)
    .toList();

void main() {
  test('aucun libellé nettoyé ne garde quantité, unité ou guillemet', () {
    final raws = _rawIngredients();
    expect(raws.length, greaterThan(1000));

    final unit = RegExp(
      r"^(cuill|g |kg |cl |ml |l |gousse|pinc|tranche|boîte|boite|sachet|verre|de |d'|du |des |un |une )",
      caseSensitive: false,
    );
    final bad = <String>[];
    var empty = 0;
    final emptied = <String>[];
    for (final raw in raws) {
      final name = ingredientDisplayName(raw);
      if (name.isEmpty) {
        empty++;
        emptied.add(raw);
        continue;
      }
      if (name.contains('"') ||
          RegExp(r'\d').hasMatch(name) ||
          unit.hasMatch(name) ||
          name.length > 40) {
        bad.add('$raw → $name');
      }
    }
    // Quelques libellés atypiques restent tolérés, pas plus de 2 %.
    expect(bad.length, lessThan(raws.length * 0.02), reason: bad.take(30).join('\n'));
    expect(empty, lessThan(raws.length * 0.02),
        reason: emptied.take(60).join(' | '));
  }, skip: _available ? false : 'BDD/ absent');
}
