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

  group('fixMojibake', () {
    test('répare un encodage simple ou double', () {
      expect(fixMojibake('CrÃ¨me brÃ»lÃ©e'), 'Crème brûlée');
      expect(fixMojibake('ÃƒÂ©tape'), 'étape');
      expect(fixMojibake('Å“uf'), 'œuf');
      expect(fixMojibake('Ã  la poÃªle'), 'à la poêle');
      expect(fixMojibake('Ã\u00A0 la'), 'à la'); // espace insécable intacte
    });

    test('ponctuation typographique ramenée à sa forme simple', () {
      expect(fixMojibake('lâ€™huile'), "l'huile");
      expect(fixMojibake('â€¢ Ã©tape'), '- étape');
    });

    test('un texte correct reste intact', () {
      for (final s in ['Pâtes à la crème', 'Bœuf', 'Ça va ?', 'Été 2024']) {
        expect(fixMojibake(s), s);
      }
    });
  });

  test('parseInstructions retire « Étape n » et « Préparation »', () {
    expect(
      parseInstructions('Préparation\nÉtape 1 Couper\nÃ©tape 2 Cuire'),
      ['Couper', 'Cuire'],
    );
  });
}
