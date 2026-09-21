enum ZendoRuleUniverse { any, pyramidTrio, boxed }

enum ZendoRuleDifficulty { easy, medium, hard }

class ZendoCommunityRule {
  const ZendoCommunityRule({
    required this.id,
    required this.text,
    required this.difficulty,
    required this.universe,
    required this.sourceLabel,
    required this.sourceUrl,
  });

  final String id;
  final String text;
  final ZendoRuleDifficulty difficulty;
  final ZendoRuleUniverse universe;
  final String sourceLabel;
  final String sourceUrl;
}

/// Short, paraphrased community rule examples verified on BoardGameGeek.
/// The source URLs remain attached so the app can credit where each idea came
/// from without bundling large copied rule lists.
const zendoCommunityRules = <ZendoCommunityRule>[
  ZendoCommunityRule(
    id: 'three-pieces',
    text: 'A structure has at least three pieces.',
    difficulty: ZendoRuleDifficulty.easy,
    universe: ZendoRuleUniverse.any,
    sourceLabel: 'BoardGameGeek · Zendo and the scientific method',
    sourceUrl:
        'https://boardgamegeek.com/blog/812/blogpost/5759/zendo-as-a-tool-for-teaching-the-scientific-method',
  ),
  ZendoCommunityRule(
    id: 'one-medium',
    text: 'A structure contains at least one medium pyramid.',
    difficulty: ZendoRuleDifficulty.easy,
    universe: ZendoRuleUniverse.pyramidTrio,
    sourceLabel: 'BoardGameGeek · Pretty Sneaky, Sis review',
    sourceUrl:
        'https://boardgamegeek.com/thread/1047875/pretty-sneaky-sis-pyramid-scheme-a-zendo-review',
  ),
  ZendoCommunityRule(
    id: 'blue-pyramid',
    text: 'A structure contains at least one blue pyramid.',
    difficulty: ZendoRuleDifficulty.easy,
    universe: ZendoRuleUniverse.pyramidTrio,
    sourceLabel: 'BoardGameGeek · game-night report',
    sourceUrl:
        'https://boardgamegeek.com/geeklist/145548/game-night-ministers-to-the-rash-tube-past-the-toa',
  ),
  ZendoCommunityRule(
    id: 'large-blue',
    text: 'A structure contains at least one large blue pyramid.',
    difficulty: ZendoRuleDifficulty.easy,
    universe: ZendoRuleUniverse.pyramidTrio,
    sourceLabel: 'BoardGameGeek · Pretty Sneaky, Sis review',
    sourceUrl:
        'https://boardgamegeek.com/thread/1047875/pretty-sneaky-sis-pyramid-scheme-a-zendo-review',
  ),
  ZendoCommunityRule(
    id: 'medium-touch',
    text: 'Every medium pyramid touches another medium pyramid.',
    difficulty: ZendoRuleDifficulty.medium,
    universe: ZendoRuleUniverse.pyramidTrio,
    sourceLabel: 'BoardGameGeek · The best way to play Zendo?',
    sourceUrl:
        'https://boardgamegeek.com/geeklist/33356/the-best-way-to-play-zendo-please-vote',
  ),
  ZendoCommunityRule(
    id: 'no-pointing',
    text: 'No pyramid points at another pyramid.',
    difficulty: ZendoRuleDifficulty.medium,
    universe: ZendoRuleUniverse.any,
    sourceLabel: 'BoardGameGeek · game-night report',
    sourceUrl:
        'https://boardgamegeek.com/geeklist/145548/game-night-ministers-to-the-rash-tube-past-the-toa',
  ),
  ZendoCommunityRule(
    id: 'uprights-same-size',
    text: 'All upright pyramids are the same size.',
    difficulty: ZendoRuleDifficulty.medium,
    universe: ZendoRuleUniverse.pyramidTrio,
    sourceLabel: 'BoardGameGeek · game-night report',
    sourceUrl:
        'https://boardgamegeek.com/geeklist/145548/game-night-ministers-to-the-rash-tube-past-the-toa',
  ),
  ZendoCommunityRule(
    id: 'green-over-red',
    text: 'There are more green pyramids than red pyramids.',
    difficulty: ZendoRuleDifficulty.medium,
    universe: ZendoRuleUniverse.pyramidTrio,
    sourceLabel: 'BoardGameGeek · community difficulty thread',
    sourceUrl:
        'https://boardgamegeek.com/thread/3111857/what-are-some-rules-you-came-up-with-as-master-tha',
  ),
  ZendoCommunityRule(
    id: 'ignore-small',
    text:
        'Ignoring small pyramids, there are more blue pyramids than yellow pyramids.',
    difficulty: ZendoRuleDifficulty.hard,
    universe: ZendoRuleUniverse.pyramidTrio,
    sourceLabel: 'BoardGameGeek · community difficulty thread',
    sourceUrl:
        'https://boardgamegeek.com/thread/3111857/what-are-some-rules-you-came-up-with-as-master-tha',
  ),
  ZendoCommunityRule(
    id: 'set-like',
    text:
        'Using exactly three pyramids, each chosen attribute is either all the same or all different.',
    difficulty: ZendoRuleDifficulty.hard,
    universe: ZendoRuleUniverse.pyramidTrio,
    sourceLabel: 'BoardGameGeek · community difficulty thread',
    sourceUrl:
        'https://boardgamegeek.com/thread/3111857/what-are-some-rules-you-came-up-with-as-master-tha',
  ),
];

String zendoDifficultyLabel(ZendoRuleDifficulty difficulty) => switch (difficulty) {
  ZendoRuleDifficulty.easy => 'Easy',
  ZendoRuleDifficulty.medium => 'Medium',
  ZendoRuleDifficulty.hard => 'Hard',
};
