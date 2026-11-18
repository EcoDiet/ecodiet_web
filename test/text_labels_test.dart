import 'package:eco_diet_v0/pages/home/recipe_filtering.dart';
import 'package:eco_diet_v0/pages/recipe_infos/recipe_text.dart';
import 'package:eco_diet_v0/utils/text_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stripQuotesAndSpaces', () {
    expect(stripQuotesAndSpaces('  """Plat"  du   jour" '), 'Plat du jour');
  });

  test('normalizeTypeLabel', () {
    expect(
        normalizeTypeLabel(' Plat-Principal_Chaud '), 'plat principal chaud');
    expect(normalizeTypeLabel('Apperitif'), 'aperitif');
  });

  test('libellé de filtre sans accents, libellé affiché avec accents', () {
    expect(asciiFilterLabel(' "Crème  fraîche" '), 'Creme fraiche');
    expect(displayLabel(' "Crème  fraîche" '), 'Crème fraîche');
  });
}
