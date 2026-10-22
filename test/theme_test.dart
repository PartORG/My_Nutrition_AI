import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:myfoodmind/ui/theme.dart';

/// WCAG 2.2 contrast ratio of two colours (1 … 21).
double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  for (final (name, p) in [('light', AppPalette.light), ('night', AppPalette.night)]) {
    test('$name: text ≥ 4.5:1 on the background and the cards, icons ≥ 3:1 on their tint', () {
      final texts = {
        'ink': p.ink, 'ink2': p.ink2, 'muted': p.muted, 'primary': p.primary, 'danger': p.danger, 'water': p.water,
        for (final e in p.accents.entries) e.key: e.value,
      };
      for (final MapEntry(key: k, value: c) in texts.entries) {
        for (final (on, bg) in [('background', p.background), ('surface', p.surface)]) {
          expect(contrast(c, bg), greaterThanOrEqualTo(4.5), reason: '$k on $on');
        }
      }
      // A meal or nutrient icon on its 13 % (light) / 16 % (night) wash over the card (tint in theme.dart).
      for (final MapEntry(key: k, value: c) in p.accents.entries) {
        final wash = Color.alphaBlend(c.withValues(alpha: name == 'light' ? .13 : .16), p.surface);
        expect(contrast(c, wash), greaterThanOrEqualTo(3), reason: '$k icon on its tint');
      }
      for (final (k, fg, bg) in [
        ('onMint', p.onMint, p.mint), ('onWarm', p.onWarm, p.warm), ('danger', p.danger, p.dangerBg),
        ('water', p.water, p.waterBg), ('onPrimary', p.onPrimary, p.primary),
      ]) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$k on its chip');
      }
    });
  }

  test('light: no pure white surface; the cards are lighter than the background', () {
    final p = AppPalette.light;
    expect(p.surface, isNot(const Color(0xFFFFFFFF)));
    expect(p.surface.computeLuminance(), greaterThan(p.background.computeLuminance()));
    expect(p.surfaceHigh.computeLuminance(), lessThan(p.surface.computeLuminance()), reason: 'a raised control shows');
  });
}
