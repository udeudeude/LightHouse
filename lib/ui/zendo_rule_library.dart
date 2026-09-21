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
    required this.text,
    required this.difficulty,
    required this.source,
    this.usesSize = false,
    this.usesPips = false,
  });

  final String text;
  final ZendoRuleDifficulty difficulty;
  final String source;
  final bool usesSize;
  final bool usesPips;

  bool get suitableForZendo20 => !usesSize && !usesPips;
}

const _induction = 'Induction rule cards PDF';
const _zendoCards = 'Zendo Cards PDF';

const zendoRules = <ZendoRule>[
  // The complete 80-card induction sheet supplied by the user. These are
  // deliberately classified as Easy: each tests a single explicit property.
  ZendoRule(
    text: 'All the pieces are yellow.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least one piece is yellow.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly one piece is yellow.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'No pieces are yellow.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'All the pieces are red.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least one piece is red.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly one piece is red.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'No pieces are red.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'All the pieces are blue.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least one piece is blue.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly one piece is blue.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'No pieces are blue.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'All the pieces are the same color.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'No pieces are the same color.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'All the pieces are the same size.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'No pieces are the same size.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'All the pieces are large.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'At least one piece is large.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'Exactly one piece is large.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'No pieces are large.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'All the pieces are the same orientation.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'No pieces are the same orientation.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'The sum of pips is five, six, or seven.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The sum of pips is not five, six, or seven.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'All the pieces are medium.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'At least one piece is medium.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'Exactly one piece is medium.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'No pieces are medium.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'All the pieces are small.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'At least one piece is small.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'Exactly one piece is small.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'No pieces are small.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'All the pieces are upright.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least one piece is upright.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly one piece is upright.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'No pieces are upright.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'All the pieces are lying down.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least one piece is lying down.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly one piece is lying down.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'No pieces are lying down.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'All the pieces are touching other pieces.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least two pieces are touching each other.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly two pieces are touching each other.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'No pieces are touching other pieces.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'All the pieces are touching the table.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least one piece is touching the table.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly one piece is touching the table.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'The sum of pips is six or more.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The sum of pips is six or less.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The sum of pips is six.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The sum of pips is five.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The sum of pips is seven.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The sum of pips is less than six.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The sum of pips is more than six.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The sum of pips is odd.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The sum of pips is even.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesPips: true,
  ),
  ZendoRule(
    text: 'At least two pieces are yellow.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly two pieces are yellow.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least two pieces are red.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly two pieces are red.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least two pieces are blue.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly two pieces are blue.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least two pieces are the same color.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly two pieces are the same color.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least two pieces are large.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'Exactly two pieces are large.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'At least two pieces are medium.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'Exactly two pieces are medium.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'At least two pieces are small.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'Exactly two pieces are small.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'At least two pieces are the same size.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'Exactly two pieces are the same size.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
    usesSize: true,
  ),
  ZendoRule(
    text: 'At least two pieces are upright.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly two pieces are upright.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least two pieces are lying down.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly two pieces are lying down.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least two pieces have the same orientation.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly two pieces have the same orientation.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'At least two pieces are touching the table.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),
  ZendoRule(
    text: 'Exactly two pieces are touching the table.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _induction,
  ),

  // Difficulty-tagged rules from the supplied Zendo Cards deck. The deck's
  // own legend defines Easy, Medium, Medium Hard, Hard, and Crazy Hard.
  ZendoRule(
    text: 'All its pieces are the same color.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It contains at least one red piece.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It contains no green pieces.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It contains exactly two pieces.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It contains an ungrounded piece.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It contains two or more upright pieces.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It contains at least one green piece and at least one blue piece.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'All its pieces are flat.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It contains at least one piece of each of the four colors.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has no upright pieces.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has a non-upright red piece.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has a flat piece pointed at a non-flat piece.',
    difficulty: ZendoRuleDifficulty.easy,
    source: _zendoCards,
  ),

  ZendoRule(
    text: 'It has a piece which points at a piece of a different color.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has a three-piece tower that contains a red piece.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has an odd number of medium pieces.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
    usesSize: true,
  ),
  ZendoRule(
    text: 'It has an ungrounded blue piece pointing at a weird piece.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has an upright green piece.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has at least two pieces of the same color.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has exactly three non-yellow pieces.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has exactly three towers.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has a red piece pointing at a weird piece.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'The total pip count is less than or equal to four.',
    difficulty: ZendoRuleDifficulty.medium,
    source: _zendoCards,
    usesPips: true,
  ),

  ZendoRule(
    text: 'Every piece touches exactly one other piece, which is of a different color.',
    difficulty: ZendoRuleDifficulty.mediumHard,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'Exactly half of the pieces are medium.',
    difficulty: ZendoRuleDifficulty.mediumHard,
    source: _zendoCards,
    usesSize: true,
  ),
  ZendoRule(
    text: 'Exactly half of the pieces are upright.',
    difficulty: ZendoRuleDifficulty.mediumHard,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'A blue piece points at, but does not touch, a small piece.',
    difficulty: ZendoRuleDifficulty.mediumHard,
    source: _zendoCards,
    usesSize: true,
  ),
  ZendoRule(
    text: 'It has a piece touching a piece of its own orientation.',
    difficulty: ZendoRuleDifficulty.mediumHard,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has a weird piece touching a blue piece.',
    difficulty: ZendoRuleDifficulty.mediumHard,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'Every piece is pointing at an even number of pieces.',
    difficulty: ZendoRuleDifficulty.mediumHard,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has a piece pointing at two or more different colors.',
    difficulty: ZendoRuleDifficulty.mediumHard,
    source: _zendoCards,
  ),

  ZendoRule(
    text: 'It has a set of contiguously touching pieces with a total pip-count of five.',
    difficulty: ZendoRuleDifficulty.hard,
    source: _zendoCards,
    usesPips: true,
  ),
  ZendoRule(
    text: 'It has either a yellow or a green piece, but not both.',
    difficulty: ZendoRuleDifficulty.hard,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It has exactly one piece touching nothing.',
    difficulty: ZendoRuleDifficulty.hard,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'Any piece is touching at least two other pieces.',
    difficulty: ZendoRuleDifficulty.hard,
    source: _zendoCards,
  ),
  ZendoRule(
    text: 'It cannot have two pieces of the same size, color, or orientation.',
    difficulty: ZendoRuleDifficulty.hard,
    source: _zendoCards,
    usesSize: true,
  ),
  ZendoRule(
    text: 'No pieces touch a piece that has the same size, color, or orientation.',
    difficulty: ZendoRuleDifficulty.hard,
    source: _zendoCards,
    usesSize: true,
  ),
  ZendoRule(
    text:
        'It has a piece that is touching as many other pieces as it has pips.',
    difficulty: ZendoRuleDifficulty.hard,
    source: _zendoCards,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The number of flat pieces equals the number of upright pips.',
    difficulty: ZendoRuleDifficulty.hard,
    source: _zendoCards,
    usesPips: true,
  ),

  ZendoRule(
    text: 'The total pip count is prime.',
    difficulty: ZendoRuleDifficulty.crazyHard,
    source: _zendoCards,
    usesPips: true,
  ),
  ZendoRule(
    text: 'It has two pieces of the same color exclusive-or two pieces of the same size.',
    difficulty: ZendoRuleDifficulty.crazyHard,
    source: _zendoCards,
    usesSize: true,
  ),
  ZendoRule(
    text: 'The pip count of pieces pointing at no other pieces is three.',
    difficulty: ZendoRuleDifficulty.crazyHard,
    source: _zendoCards,
    usesPips: true,
  ),
  ZendoRule(
    text: 'The total non-blue pip count is prime.',
    difficulty: ZendoRuleDifficulty.crazyHard,
    source: _zendoCards,
    usesPips: true,
  ),
];
