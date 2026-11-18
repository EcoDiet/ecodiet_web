// Non-régression sur le jeu de données réel (BDD/, non versionné) : ignoré
// automatiquement si les CSV sont absents (CI).
import 'dart:io';

import 'package:eco_diet_v0/pages/home/home_models.dart';
import 'package:eco_diet_v0/pages/home/recipe_filtering.dart';
import 'package:flutter_test/flutter_test.dart';

const _dir = 'BDD';
final _available = File('$_dir/FACT/FACT_RECETTE_REGIME.csv').existsSync();

List<List<String>> _csv(String path) {
  final rows = <List<String>>[];
  final text = File(path).readAsStringSync();
  var field = StringBuffer();
  var row = <String>[];
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field = StringBuffer();
    } else if (c == '\n') {
      row.add(field.toString());
      rows.add(row);
      row = [];
      field = StringBuffer();
    } else if (c != '\r') {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows.skip(1).where((r) => r.length > 1).toList();
}

class _Labeled {
  final RecipeDisplayModel recipe;
  final DietLevel expected;
  _Labeled(this.recipe, this.expected);
}

List<_Labeled> _load({required bool withLabel}) {
  final titles = {
    for (final r in _csv('$_dir/FACT/FACT_RECETTE_BASE.csv')) r[0]: r[1]
  };
  final names = {
    for (final r in _csv('$_dir/DIM/DIM_INGREDIENTS.csv')) r[0]: r[1]
  };
  final regimes = {
    for (final r in _csv('$_dir/DIM/DIM_REGIME.csv')) r[0]: r[1]
  };
  final ingredients = <String, List<String>>{};
  for (final r in _csv('$_dir/FACT/FACT_INGREDIENTS_RECETTE.csv')) {
    ingredients.putIfAbsent(r[0], () => []).add(names[r[1]] ?? '');
  }
  return [
    for (final r in _csv('$_dir/FACT/FACT_RECETTE_REGIME.csv'))
      _Labeled(
        RecipeDisplayModel(
          id: r[0],
          title: titles[r[0]] ?? '',
          category: '',
          ingredients: (ingredients[r[0]] ?? []).join(', '),
          diets: withLabel ? regimes[r[1]]! : '',
          duration: '',
        ),
        dietLevelFromLabel(regimes[r[1]]!)!,
      ),
  ];
}

void main() {
  test('avec le régime des données : 300/300 recettes bien classées', () {
    final data = _load(withLabel: true);
    expect(data, hasLength(300));
    final wrong =
        data.where((d) => recipeDietLevel(d.recipe) != d.expected).length;
    expect(wrong, 0);
  }, skip: _available ? false : 'BDD/ absent');

  test('secours par mots-clés : pas de régression sous 299/300', () {
    final data = _load(withLabel: false);
    final ok = data.where((d) => inferDietLevel(d.recipe) == d.expected).length;
    // 299 : seul écart, Fish and Chips (pâte seule, étiqueté pescétarien).
    expect(ok, greaterThanOrEqualTo(299), reason: 'accord : $ok/300');
    printOnFailure('accord mots-clés : $ok/300');
  }, skip: _available ? false : 'BDD/ absent');
}
