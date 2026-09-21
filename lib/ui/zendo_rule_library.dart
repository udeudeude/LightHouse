class ZendoCommunityRule {
  const ZendoCommunityRule({
    required this.id,
    required this.text,
    required this.sourceLabel,
    required this.sourceUrl,
    required this.compatibility,
  });

  final String id;
  final String text;
  final String sourceLabel;
  final String sourceUrl;
  final String compatibility;
}

// Community examples are paraphrased rather than copied verbatim. They are
// intentionally kept small and source-linked so LightHouse can offer a rule
// helper without republishing entire fan-made files.
const zendoCommunityRules = <ZendoCommunityRule>[
  ZendoCommunityRule(
    id: 'bgg-medium-present',
    text: 'At least one medium piece is present.',
    sourceLabel: 'BoardGameGeek community example',
    sourceUrl: 'https://boardgamegeek.com/thread/3399670/my-onlinetext-zendo-setup-and-some-thoughts-about',
    compatibility: 'pyramids',
  ),
  ZendoCommunityRule(
    id: 'bgg-more-white-than-black',
    text: 'There are more white pieces than black pieces.',
    sourceLabel: 'BoardGameGeek community example',
    sourceUrl: 'https://boardgamegeek.com/thread/3399670/my-onlinetext-zendo-setup-and-some-thoughts-about',
    compatibility: 'general',
  ),
  ZendoCommunityRule(
    id: 'bgg-two-vertical',
    text: 'Exactly two pieces are vertical.',
    sourceLabel: 'BoardGameGeek community example',
    sourceUrl: 'https://boardgamegeek.com/thread/3399670/my-onlinetext-zendo-setup-and-some-thoughts-about',
    compatibility: 'general',
  ),
  ZendoCommunityRule(
    id: 'bgg-black-above-white',
    text: 'A black piece is directly above a white piece.',
    sourceLabel: 'BoardGameGeek community example',
    sourceUrl: 'https://boardgamegeek.com/thread/3399670/my-onlinetext-zendo-setup-and-some-thoughts-about',
    compatibility: 'general',
  ),
  ZendoCommunityRule(
    id: 'bgg-white-pips-square',
    text: 'The total pip count of the white pyramids is a square number.',
    sourceLabel: 'BoardGameGeek community example',
    sourceUrl: 'https://boardgamegeek.com/thread/3399670/my-onlinetext-zendo-setup-and-some-thoughts-about',
    compatibility: 'pyramids',
  ),
  ZendoCommunityRule(
    id: 'bgg-all-medium-touch',
    text: 'Every medium piece touches another medium piece.',
    sourceLabel: 'BoardGameGeek discussion example',
    sourceUrl: 'https://boardgamegeek.com/geeklist/33356/the-best-way-to-play-zendo-please-vote',
    compatibility: 'general',
  ),
  ZendoCommunityRule(
    id: 'bgg-contains-blue',
    text: 'At least one blue piece is present.',
    sourceLabel: 'BoardGameGeek review example',
    sourceUrl: 'https://boardgamegeek.com/thread/1047875/pretty-sneaky-sis-pyramid-scheme-a-zendo-review',
    compatibility: 'general',
  ),
  ZendoCommunityRule(
    id: 'bgg-large-blue',
    text: 'At least one large blue pyramid is present.',
    sourceLabel: 'BoardGameGeek review example',
    sourceUrl: 'https://boardgamegeek.com/thread/1047875/pretty-sneaky-sis-pyramid-scheme-a-zendo-review',
    compatibility: 'pyramids',
  ),
  ZendoCommunityRule(
    id: 'looney-shape-present',
    text: 'At least one piece of the selected shape is present.',
    sourceLabel: 'Looney Labs rule-card example',
    sourceUrl: 'https://faq.looneylabs.com/question/1445',
    compatibility: 'boxed',
  ),
  ZendoCommunityRule(
    id: 'looney-color-shape',
    text: 'At least one piece matches both the selected color and shape.',
    sourceLabel: 'Looney Labs rule-card example',
    sourceUrl: 'https://faq.looneylabs.com/question/1445',
    compatibility: 'boxed',
  ),
];
