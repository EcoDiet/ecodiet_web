import 'package:eco_diet_v0/pages/recipe_infos/recipe_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatDuration', () {
    expect(formatDuration(45), '45 min');
    expect(formatDuration(60), '1h');
    expect(formatDuration(95), '1h 35min');
  });

  test('difficultyLabel selon la durée', () {
    expect(difficultyLabel(10), 'Facile');
    expect(difficultyLabel(30), 'Moyen');
    expect(difficultyLabel(31), 'Difficile');
  });

  test('formatTypeLabel normalise le type de plat', () {
    expect(formatTypeLabel('Plat_Principal'), 'plat principal');
    expect(formatTypeLabel('apperitif'), 'aperitif');
  });

  test('parseInstructions découpe un tableau d étapes', () {
    const raw = "['Couper les légumes', 'Cuire 10 minutes']";
    expect(parseInstructions(raw), ['Couper les légumes', 'Cuire 10 minutes']);
    expect(parseInstructions('   '), isEmpty);
  });
}
