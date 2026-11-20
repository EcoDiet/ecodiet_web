import 'package:eco_diet_v0/widgets/cover_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int? width(double w, double h, double ratio) =>
      CoverNetworkImage.cacheWidthFor(
          BoxConstraints.tight(Size(w, h)), ratio);

  test('carte paysage : largeur affichée × densité, arrondie au palier', () {
    expect(width(250, 150, 2), 512);
  });

  test('boîte haute : largeur suffisante pour couvrir une photo 3:2', () {
    expect(width(300, 500, 1), 768);
  });

  test('contraintes infinies : pas de redimensionnement', () {
    expect(
        CoverNetworkImage.cacheWidthFor(
            const BoxConstraints(maxWidth: 300), 2),
        isNull);
  });
}
