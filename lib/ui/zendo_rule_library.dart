enum ZendoRuleDifficulty { easy, medium, mediumHard, hard, crazyHard }

extension ZendoRuleDifficultyLabel on ZendoRuleDifficulty {
  String get label => switch (this) {
    ZendoRuleDifficulty.easy => 'Easy',
    ZendoRuleDifficulty.medium => 'Medium',
    ZendoRuleDifficulty.mediumHard => 'Medium Hard',
    ZendoRuleDifficulty.hard => 'Hard',
    ZendoRuleDifficulty.crazyHard => 'Crazy Hard',
  };
}

class ZendoRule {
  const ZendoRule({
    required this.id,
    required this.text,
    required this.difficulty,
    required this.sourceLabel,
    this.usesSize = false,
    this.usesPips = false,
    this.usesGreen = false,
    this.classicOnly = false,
  });

  final String id;
  final String text;
  final ZendoRuleDifficulty difficulty;
  final String sourceLabel;
  final bool usesSize;
  final bool usesPips;
  final bool usesGreen;
  final bool classicOnly;

  bool get worksWithZendo20 =>
      !usesSize && !usesPips && !usesGreen && !classicOnly;
}

ZendoRule _easy(
  String id,
  String text, {
  bool size = false,
  bool pips = false,
  bool green = false,
  bool classicOnly = false,
  String source = 'Induction rule cards',
}) => ZendoRule(
  id: id,
  text: text,
  difficulty: ZendoRuleDifficulty.easy,
  sourceLabel: source,
  usesSize: size,
  usesPips: pips,
  usesGreen: green,
  classicOnly: classicOnly,
);

ZendoRule _card(
  String id,
  String text,
  ZendoRuleDifficulty difficulty, {
  bool size = false,
  bool pips = false,
  bool green = false,
  bool classicOnly = false,
}) => ZendoRule(
  id: id,
  text: text,
  difficulty: difficulty,
  sourceLabel: 'Zendo Cards PDF',
  usesSize: size,
  usesPips: pips,
  usesGreen: green,
  classicOnly: classicOnly,
);

List<ZendoRule> _inductionRules() {
  final rules = <ZendoRule>[];
  const colors = ['yellow', 'red', 'blue'];
  for (final color in colors) {
    rules.addAll([
      _easy('ind-$color-all', 'All pieces are $color.'),
      _easy('ind-$color-any', 'At least one piece is $color.'),
      _easy('ind-$color-one', 'Exactly one piece is $color.'),
      _easy('ind-$color-none', 'No pieces are $color.'),
      _easy('ind-$color-two-plus', 'At least two pieces are $color.'),
      _easy('ind-$color-two', 'Exactly two pieces are $color.'),
    ]);
  }
  rules.addAll([
    _easy('ind-color-same-all', 'All pieces are the same color.'),
    _easy('ind-color-all-different', 'No two pieces are the same color.'),
    _easy(
      'ind-color-same-two-plus',
      'At least two pieces are the same color.',
    ),
    _easy('ind-color-same-two', 'Exactly two pieces are the same color.'),
  ]);

  const sizes = ['large', 'medium', 'small'];
  for (final size in sizes) {
    rules.addAll([
      _easy('ind-$size-all', 'All pieces are $size.', size: true),
      _easy('ind-$size-any', 'At least one piece is $size.', size: true),
      _easy('ind-$size-one', 'Exactly one piece is $size.', size: true),
      _easy('ind-$size-none', 'No pieces are $size.', size: true),
      _easy(
        'ind-$size-two-plus',
        'At least two pieces are $size.',
        size: true,
      ),
      _easy('ind-$size-two', 'Exactly two pieces are $size.', size: true),
    ]);
  }
  rules.addAll([
    _easy('ind-size-same-all', 'All pieces are the same size.', size: true),
    _easy(
      'ind-size-all-different',
      'No two pieces are the same size.',
      size: true,
    ),
    _easy(
      'ind-size-same-two-plus',
      'At least two pieces are the same size.',
      size: true,
    ),
    _easy(
      'ind-size-same-two',
      'Exactly two pieces are the same size.',
      size: true,
    ),
  ]);

  for (final orientation in ['upright', 'lying down']) {
    final slug = orientation == 'upright' ? 'upright' : 'flat';
    rules.addAll([
      _easy('ind-$slug-all', 'All pieces are $orientation.'),
      _easy('ind-$slug-any', 'At least one piece is $orientation.'),
      _easy('ind-$slug-one', 'Exactly one piece is $orientation.'),
      _easy('ind-$slug-none', 'No pieces are $orientation.'),
      _easy('ind-$slug-two-plus', 'At least two pieces are $orientation.'),
      _easy('ind-$slug-two', 'Exactly two pieces are $orientation.'),
    ]);
  }
  rules.addAll([
    _easy(
      'ind-orientation-same-all',
      'All pieces have the same orientation.',
    ),
    _easy(
      'ind-orientation-all-different',
      'No two pieces have the same orientation.',
    ),
    _easy(
      'ind-orientation-same-two-plus',
      'At least two pieces have the same orientation.',
    ),
    _easy(
      'ind-orientation-same-two',
      'Exactly two pieces have the same orientation.',
    ),
    _easy(
      'ind-touch-all',
      'Every piece touches at least one other piece.',
    ),
    _easy(
      'ind-touch-some',
      'At least two pieces touch each other.',
    ),
    _easy(
      'ind-touch-exact-two',
      'Exactly two pieces touch each other.',
    ),
    _easy(
      'ind-touch-none',
      'No pieces touch another piece.',
    ),
    _easy(
      'ind-ground-all',
      'All pieces touch the table.',
    ),
    _easy(
      'ind-ground-any',
      'At least one piece touches the table.',
    ),
    _easy(
      'ind-ground-one',
      'Exactly one piece touches the table.',
    ),
    _easy(
      'ind-ground-two-plus',
      'At least two pieces touch the table.',
    ),
    _easy(
      'ind-ground-two',
      'Exactly two pieces touch the table.',
    ),
    _easy(
      'ind-pips-5-7',
      'The total pip count is five, six, or seven.',
      pips: true,
    ),
    _easy(
      'ind-pips-not-5-7',
      'The total pip count is not five, six, or seven.',
      pips: true,
    ),
    _easy('ind-pips-6-plus', 'The total pip count is six or more.', pips: true),
    _easy('ind-pips-6-less', 'The total pip count is six or less.', pips: true),
    _easy('ind-pips-6', 'The total pip count is six.', pips: true),
    _easy('ind-pips-5', 'The total pip count is five.', pips: true),
    _easy('ind-pips-7', 'The total pip count is seven.', pips: true),
    _easy('ind-pips-under-6', 'The total pip count is less than six.', pips: true),
    _easy('ind-pips-over-6', 'The total pip count is more than six.', pips: true),
    _easy('ind-pips-odd', 'The total pip count is odd.', pips: true),
    _easy('ind-pips-even', 'The total pip count is even.', pips: true),
  ]);
  return rules;
}

// Normalized/paraphrased from the supplied Zendo Cards PDF. The colored
// markers on the cards define Easy, Medium, Medium Hard, Hard, and Crazy Hard.
final List<ZendoRule> zendoRules = List.unmodifiable([
  ..._inductionRules(),

  // Easy examples from the card deck.
  _easy(
    'cards-easy-same-color',
    'All pieces are the same color.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-same-size',
    'All pieces are the same size.',
    size: true,
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-all-flat',
    'All pieces are flat.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-red-present',
    'At least one red piece is present.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-small-present',
    'At least one small piece is present.',
    size: true,
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-four-colors',
    'At least one piece of each of the four Classic colors is present.',
    green: true,
    classicOnly: true,
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-no-green',
    'No green pieces are present.',
    green: true,
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-no-large',
    'No large pieces are present.',
    size: true,
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-medium-yellow',
    'At least one medium yellow piece is present.',
    size: true,
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-two-pieces',
    'There are exactly two pieces.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-two-upright',
    'There are at least two upright pieces.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-pointing',
    'At least one piece points at another piece.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-ungrounded',
    'At least one piece is ungrounded.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-green-and-blue',
    'At least one green and at least one blue piece are present.',
    green: true,
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-touching-pair',
    'At least two pieces touch each other.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-red-blue',
    'At least one red and at least one blue piece are present.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-two-yellow',
    'At least two yellow pieces are present.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-uprights-grounded',
    'Every upright piece is grounded, and there is at least one upright piece.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-weird',
    'At least one piece is in a weird orientation.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-one-upright',
    'Exactly one piece is upright.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-no-upright',
    'No pieces are upright.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-reds-upright',
    'Every red piece is upright, and at least one red piece is present.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-uprights-same-size',
    'All upright pieces are the same size.',
    size: true,
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-blue-or-weird',
    'There is a blue piece or a weirdly oriented piece.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-non-upright-red',
    'There is a red piece that is not upright.',
    source: 'Zendo Cards PDF',
  ),
  _easy(
    'cards-easy-pointed-smaller',
    'A piece is pointed at by a smaller piece.',
    size: true,
    source: 'Zendo Cards PDF',
  ),

  // Medium.
  _card(
    'cards-med-points-different-color',
    'A piece points at a piece of a different color.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-red-points-large',
    'A red piece points at a large piece.',
    ZendoRuleDifficulty.medium,
    size: true,
  ),
  _card(
    'cards-med-small-yellow-on-medium-red',
    'A small yellow upright is on top of a medium red upright, with no other pieces.',
    ZendoRuleDifficulty.medium,
    size: true,
  ),
  _card(
    'cards-med-three-tower-red',
    'A three-piece tower contains a red piece.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-weird-blue',
    'There is a weirdly oriented blue piece.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-even-colors',
    'An even number of colors are represented.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-odd-medium',
    'There is an odd number of medium pieces.',
    ZendoRuleDifficulty.medium,
    size: true,
  ),
  _card(
    'cards-med-ungrounded-blue-points-weird',
    'An ungrounded blue piece points at a weirdly oriented piece.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-ungrounded-flat',
    'There is an ungrounded flat piece.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-ungrounded-large-only-large',
    'There is one ungrounded large piece and no other large pieces.',
    ZendoRuleDifficulty.medium,
    size: true,
  ),
  _card(
    'cards-med-upright-green',
    'There is an upright green piece.',
    ZendoRuleDifficulty.medium,
    green: true,
  ),
  _card(
    'cards-med-upright-touches-flat',
    'An upright piece touches a flat piece.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-red-and-blue',
    'There is a red piece and a blue piece.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-two-colors-two-plus',
    'At least two colors each have two or more pieces.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-red-points-red',
    'A red piece points at another red piece.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-two-same-color',
    'At least two pieces have the same color.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-ungrounded-yellow-medium',
    'There is an ungrounded yellow medium piece.',
    ZendoRuleDifficulty.medium,
    size: true,
  ),
  _card(
    'cards-med-exactly-every-size',
    'There is exactly one piece of every Classic size.',
    ZendoRuleDifficulty.medium,
    size: true,
    classicOnly: true,
  ),
  _card(
    'cards-med-three-towers',
    'There are exactly three towers.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-two-non-large',
    'There are exactly two non-large pieces.',
    ZendoRuleDifficulty.medium,
    size: true,
  ),
  _card(
    'cards-med-more-blue-than-other-color',
    'Blue has more pieces than any other individual color.',
    ZendoRuleDifficulty.medium,
  ),
  _card(
    'cards-med-red-piece-or-small-or-upright',
    'There is a red piece, a small piece, or an upright piece.',
    ZendoRuleDifficulty.medium,
    size: true,
  ),
  _card(
    'cards-med-pip-at-most-four',
    'The total pip count is four or less.',
    ZendoRuleDifficulty.medium,
    pips: true,
  ),
  _card(
    'cards-med-medium-touches-flat',
    'A medium piece touches a flat piece.',
    ZendoRuleDifficulty.medium,
    size: true,
  ),

  // Medium Hard.
  _card(
    'cards-mh-touch-different-color',
    'Every piece touches exactly one other piece, and that piece is a different color.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-half-medium',
    'Exactly half of the pieces are medium.',
    ZendoRuleDifficulty.mediumHard,
    size: true,
  ),
  _card(
    'cards-mh-half-upright',
    'Exactly half of the pieces are upright.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-half-pips-green',
    'Exactly half of the total pip count comes from green pieces.',
    ZendoRuleDifficulty.mediumHard,
    pips: true,
    green: true,
  ),
  _card(
    'cards-mh-third-yellow',
    'Exactly one third of the pieces are yellow.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-blue-points-red-pointed',
    'A blue piece points at something and a red piece is being pointed at.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-blue-points-not-touch-small',
    'A blue piece points at, but does not touch, a small piece.',
    ZendoRuleDifficulty.mediumHard,
    size: true,
  ),
  _card(
    'cards-mh-flat-no-yellow',
    'There is a flat piece and there are no yellow pieces.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-green-or-red-blue',
    'There is a green piece, or both a red and a blue piece.',
    ZendoRuleDifficulty.mediumHard,
    green: true,
  ),
  _card(
    'cards-mh-large-and-upright',
    'There is a large piece and a different piece that is upright.',
    ZendoRuleDifficulty.mediumHard,
    size: true,
  ),
  _card(
    'cards-mh-medium-ungrounded-or-blue',
    'There is a medium ungrounded piece or a blue piece.',
    ZendoRuleDifficulty.mediumHard,
    size: true,
  ),
  _card(
    'cards-mh-nonblue-medium-or-blue',
    'There is a non-blue medium piece or a blue piece.',
    ZendoRuleDifficulty.mediumHard,
    size: true,
  ),
  _card(
    'cards-mh-small-touches-medium',
    'A small piece touches a medium piece.',
    ZendoRuleDifficulty.mediumHard,
    size: true,
  ),
  _card(
    'cards-mh-small-touches-weird',
    'A small piece touches a weirdly oriented piece.',
    ZendoRuleDifficulty.mediumHard,
    size: true,
  ),
  _card(
    'cards-mh-yellow-touches-nonyellow',
    'A yellow piece touches a non-yellow piece.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-two-nonred',
    'There are exactly two non-red pieces.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-upright-points',
    'An upright piece points at something.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-no-pointed-at',
    'No piece is pointed at by another piece.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-eight-pips',
    'The total pip count is eight.',
    ZendoRuleDifficulty.mediumHard,
    pips: true,
  ),
  _card(
    'cards-mh-two-orientations',
    'Exactly two orientations are represented.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-points-two-colors',
    'A piece points at pieces of two or more different colors.',
    ZendoRuleDifficulty.mediumHard,
  ),
  _card(
    'cards-mh-no-same-shared-attributes',
    'No touching pair shares the same size, color, or orientation.',
    ZendoRuleDifficulty.mediumHard,
    size: true,
  ),
  _card(
    'cards-mh-five-grounded-pips',
    'There are exactly five grounded pips.',
    ZendoRuleDifficulty.mediumHard,
    pips: true,
  ),

  // Hard.
  _card(
    'cards-hard-touching-pip-five',
    'A contiguous group of touching pieces has a total pip count of five.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-yellow-xor-green',
    'Exactly one of yellow or green is present.',
    ZendoRuleDifficulty.hard,
    green: true,
  ),
  _card(
    'cards-hard-yellow-flat-or-small',
    'There is a yellow flat piece or a small piece.',
    ZendoRuleDifficulty.hard,
    size: true,
  ),
  _card(
    'cards-hard-only-smalls-with-large',
    'There is an ungrounded large piece, and every other piece is small.',
    ZendoRuleDifficulty.hard,
    size: true,
  ),
  _card(
    'cards-hard-pointing-and-pointed',
    'At least one piece both points at another piece and is pointed at.',
    ZendoRuleDifficulty.hard,
  ),
  _card(
    'cards-hard-yellow-pips-plus-two',
    'Yellow contributes at least two more pips than blue.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-one-more-blue',
    'There is exactly one more blue piece than yellow pieces.',
    ZendoRuleDifficulty.hard,
  ),
  _card(
    'cards-hard-one-touching-nothing',
    'Exactly one piece touches no other piece.',
    ZendoRuleDifficulty.hard,
  ),
  _card(
    'cards-hard-two-colors-grounded',
    'Exactly two colors have pieces touching the table.',
    ZendoRuleDifficulty.hard,
  ),
  _card(
    'cards-hard-two-sizes-two-colors',
    'Exactly two sizes and exactly two colors are represented.',
    ZendoRuleDifficulty.hard,
    size: true,
  ),
  _card(
    'cards-hard-more-blue-pips',
    'Blue contributes more pips than green.',
    ZendoRuleDifficulty.hard,
    pips: true,
    green: true,
  ),
  _card(
    'cards-hard-color-balance',
    'Red plus blue pieces equal green plus yellow pieces.',
    ZendoRuleDifficulty.hard,
    green: true,
  ),
  _card(
    'cards-hard-yellow-blue-pips-five',
    'Yellow and blue together contribute exactly five pips.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-total-even',
    'The total pip count is even.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-total-not-multiple-three',
    'The total pip count is not a multiple of three.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-total-odd',
    'The total pip count is odd.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-nonyellow-pips-five',
    'Non-yellow pieces contribute exactly five pips.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-red-pips-multiple-three',
    'Red contributes a multiple of three pips.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-piece-touches-two',
    'At least one piece touches two or more other pieces.',
    ZendoRuleDifficulty.hard,
  ),
  _card(
    'cards-hard-orientation-counts-equal',
    'Every represented orientation has the same number of pieces.',
    ZendoRuleDifficulty.hard,
  ),
  _card(
    'cards-hard-third-pips-red',
    'Exactly one third of all pips are red.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-no-duplicate-triple',
    'No two pieces share the same size, color, or orientation.',
    ZendoRuleDifficulty.hard,
    size: true,
  ),
  _card(
    'cards-hard-large-or-small-xor',
    'There are large pieces or small pieces, but not both.',
    ZendoRuleDifficulty.hard,
    size: true,
  ),
  _card(
    'cards-hard-one-not-touching',
    'Exactly one piece touches no other pieces.',
    ZendoRuleDifficulty.hard,
  ),
  _card(
    'cards-hard-pips-outside-four-seven',
    'The total pip count is less than four or greater than seven.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-four-or-seven-pips',
    'The total pip count is exactly four or seven.',
    ZendoRuleDifficulty.hard,
    pips: true,
  ),
  _card(
    'cards-hard-more-pointed-than-not',
    'More pieces are being pointed at than are not being pointed at.',
    ZendoRuleDifficulty.hard,
  ),
  _card(
    'cards-hard-two-colors-or-sizes',
    'Exactly two colors or exactly two sizes are represented.',
    ZendoRuleDifficulty.hard,
    size: true,
  ),

  // The special black section on page 4.
  _card(
    'cards-crazy-prime-pips',
    'The total pip count is prime.',
    ZendoRuleDifficulty.crazyHard,
    pips: true,
  ),
  _card(
    'cards-crazy-xor-pair-attribute',
    'Exactly one is true: two pieces share a color, or two pieces share a size.',
    ZendoRuleDifficulty.crazyHard,
    size: true,
  ),
  _card(
    'cards-crazy-pips-no-targets',
    'Pieces that point at no other piece contribute exactly three pips.',
    ZendoRuleDifficulty.crazyHard,
    pips: true,
  ),
  _card(
    'cards-crazy-nonblue-prime',
    'The total non-blue pip count is prime.',
    ZendoRuleDifficulty.crazyHard,
    pips: true,
  ),
]);
