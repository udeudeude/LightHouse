import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/zendo_rule_library.dart';

void main() {
  test('Induction PDF contributes a substantial Easy rule set', () {
    final induction = zendoRules
        .where((rule) => rule.sourceLabel == 'Induction rule cards')
        .toList();
    expect(induction.length, greaterThanOrEqualTo(70));
    expect(
      induction.every((rule) => rule.difficulty == ZendoRuleDifficulty.easy),
      isTrue,
    );
  });

  test('Zendo 2.0 compatibility excludes size and pip rules', () {
    final compatible = zendoRules.where((rule) => rule.worksWithZendo20);
    expect(compatible, isNotEmpty);
    expect(compatible.every((rule) => !rule.usesSize), isTrue);
    expect(compatible.every((rule) => !rule.usesPips), isTrue);
    expect(compatible.every((rule) => !rule.usesGreen), isTrue);
  });

  test('supplied card deck exposes all five difficulty levels', () {
    final fromCards = zendoRules
        .where((rule) => rule.sourceLabel == 'Zendo Cards PDF')
        .toList();
    for (final difficulty in ZendoRuleDifficulty.values) {
      expect(
        fromCards.any((rule) => rule.difficulty == difficulty),
        isTrue,
        reason: 'Missing ${difficulty.label} rule from supplied cards',
      );
    }
  });
}
