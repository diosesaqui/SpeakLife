/**
 * The life-situation categories AI content is written for. Keys match
 * DeclarationCategory raw values on iOS, so anything stored under one opens
 * in the app's matching category.
 *
 * Shared by generateCategoryDevotional and the weekly For You set.
 */

// The focus line aims the writing at the place the issue lives (CLAUDE.md
// rule 12): anxiety is the mind, sickness the body, lack the money.
const CATEGORIES = {
  faith:          { name: 'Faith',                     focus: 'growing, unshakeable faith that takes God at His word' },
  identity:       { name: 'Identity in Christ',        focus: 'who the reader is in Christ: chosen, loved, righteous, a new creation' },
  love:           { name: 'Love & Belonging',          focus: "the Father's love and the reader's secure place in His family" },
  grace:          { name: 'Grace & Forgiveness',       focus: 'grace that forgives completely and frees from guilt and condemnation' },
  rest:           { name: 'Peace & Rest',              focus: 'the peace of God guarding the heart and mind, and rest in Him' },
  anxiety:        { name: 'Anxiety & Worry',           focus: 'a sound, settled mind and the peace that guards it' },
  fear:           { name: 'Fear Not',                  focus: 'courage, boldness and safety in God' },
  hope:           { name: 'Hope & Endurance',          focus: 'living hope and strength to keep going' },
  joy:            { name: 'Joy',                       focus: 'the joy of the Lord as the reader\'s strength' },
  health:         { name: 'Healing & Health',          focus: 'healing in the body, by His wounds, and strength rising in it' },
  wealth:         { name: 'Provision & Finances',      focus: 'God as provider, and abundance in the reader\'s finances' },
  debt:           { name: 'Freedom from Debt',         focus: 'freedom from financial bondage and God\'s provision' },
  work:           { name: 'Work & Career',             focus: 'favor, excellence and purpose in the reader\'s work' },
  business:       { name: 'Business & Calling',        focus: 'wisdom, increase and calling in building a business' },
  wisdom:         { name: 'Wisdom & Decisions',        focus: 'wisdom from God for real decisions' },
  destiny:        { name: 'Purpose & Destiny',         focus: 'God\'s purpose and calling over the reader\'s life' },
  marriage:       { name: 'Marriage',                  focus: 'a strong, loving, Christ-centered marriage' },
  relationship:   { name: 'Dating & Relationships',    focus: 'God\'s wisdom and timing in dating and relationships' },
  parenting:      { name: 'Parenting',                 focus: 'raising children in God\'s ways, and His promises over them' },
  singleParent:   { name: 'Single Parent',             focus: 'God\'s strength, provision and presence for a parent raising kids alone' },
  friendship:     { name: 'Friendship',                focus: 'godly friendship and community' },
  forgiveness:    { name: 'Forgiving Others',          focus: 'the freedom of forgiving as Christ forgave' },
  grief:          { name: 'Comfort in Loss',           focus: 'God\'s comfort in loss and the hope of resurrection' },
  hardtimes:      { name: 'Hard Times',                focus: 'God\'s faithfulness and strength through hard seasons' },
  innerHealing:   { name: 'Inner Healing',             focus: 'God healing the broken heart and restoring the soul' },
  mentalHealth:   { name: 'Mental Health',             focus: 'a sound mind, the mind of Christ, and peace' },
  addiction:      { name: 'Freedom from Addiction',    focus: 'freedom in Christ and a new nature that is no longer enslaved' },
  purity:         { name: 'Purity',                    focus: 'holiness, a clean heart and freedom from temptation' },
  anger:          { name: 'Peace Over Anger',          focus: 'self-control, patience and the peace of Christ ruling the heart' },
  godsprotection: { name: "God's Protection",          focus: 'God as shield, refuge and protector' },
  warfare:        { name: 'Spiritual Warfare',         focus: 'victory and authority in Christ over the enemy' },
  favor:          { name: 'Favor & Blessing',          focus: 'God\'s favor surrounding the reader like a shield' },
  miracles:       { name: 'Miracles & Breakthrough',   focus: 'the God who still does the impossible' },
  gratitude:      { name: 'Gratitude',                 focus: 'thankfulness and praise' },
  fertility:      { name: 'Believing for a Child',     focus: 'God\'s promises over the womb and a family' },
  salvation:      { name: 'Loved Ones to Salvation',   focus: 'God\'s heart and faithfulness toward unsaved loved ones' },
  newSeason:      { name: 'New Season',                focus: 'a fresh start and the new thing God is doing' },
  wellness:       { name: 'Body & Wellness',           focus: 'honoring God with the body, strength and discipline' },
  divorce:        { name: 'Healing After Divorce',     focus: 'restoration, worth and a future after divorce' },
  education:      { name: 'School & Study',            focus: 'wisdom, understanding and diligence in study' },
  housing:        { name: 'Home & Housing',            focus: 'God\'s provision of a home and a secure dwelling' },
  obedience:      { name: 'Surrender & Obedience',     focus: 'surrender to God and the blessing of obedience' },
};

module.exports = { CATEGORIES };
