import 'package:eco_diet_v0/pages/create_account/onboarding_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('passwordStrength compte longueur, majuscule, chiffre et symbole', () {
    expect(passwordStrength(''), 0);
    expect(passwordStrength('abcdefgh'), 1);
    expect(passwordStrength('Abcdefgh'), 2);
    expect(passwordStrength('Abcdefg1'), 3);
    expect(passwordStrength('Abcdef1!'), 4);
  });
}
