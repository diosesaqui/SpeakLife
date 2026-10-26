"""Native TikTok-style slideshows (speaklife-format-slideshows): the night and
morning "Jesus routine" decks, 8 slides each, 1080x1350.

Same teaching as docs/creative/carousels/2026-10-15, rebuilt in the native
cartoon-Jesus format. Renders with the skill's own render.py and assets.

Run: python3 docs/creative/slideshows/render_jesus_routines.py
"""
import os
import sys

SKILL = os.path.expanduser(
    "~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/"
    "6f09d0c0-9387-4451-9680-433a378aca94/bccac979-dca5-46b5-af8f-b53d6b0f5b1b/"
    "skills/speaklife-format-slideshows")
sys.path.insert(0, SKILL)
import render  # noqa: E402

_draw_pill = render._cta_pill


def _cta_pill_legible(canvas, draw, sub):
    """The skill's close slide draws the CTA sub-line straight over the reach
    pose's robe, where it can't be read. Same pill and colors, plus a white
    backing behind the sub-line."""
    y = _draw_pill(canvas, draw, None)
    if sub:
        fs = render.poppins(27)
        sw = draw.textlength(sub, font=fs)
        ty = y + 108 + 12
        draw.rounded_rectangle([(render.W - sw) / 2 - 18, ty - 4, (render.W + sw) / 2 + 18, ty + 38],
                               radius=20, fill=render.WHITE)
        draw.text(((render.W - sw) / 2, ty), sub, font=fs, fill=render.GRAY)
    return y


render._cta_pill = _cta_pill_legible

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "2026-10-15")

# Copy DNA from the two best ads in the account (Oct 2026):
#   "you cant fight a thought silently" carousel, $15.04 CPT: how-to hook with
#   "(step 2 is the key)", numbered steps, SpeakLife ONLY on step 2 as the tool
#   that makes the hard step easy, close "X doesn't get the last word. His does."
#   "PAIN-06 fever what-if" static, $8.56 CPT: "Jesus didn't pray about the
#   fever. He spoke to it." + name it / find what God says / say it out loud,
#   with SpeakLife as the answer to step 2 ("type the thought, get the verse").

NIGHT = [
    {"type": "hook", "kicker": "tutorial · 4 steps",
     "lines": ["what to do every night before bed", "(step 2 is the key)"],
     "pose": "seated"},
    {"type": "hook", "anchor": True, "kicker": "Mark 4:38-39",
     "lines": ["storm filling the boat. Jesus asleep in the back.",
               "He didn't pray about the storm. He spoke to it:",
               "\"Quiet! Be still!\"",
               "same Spirit lives in you (Romans 8:11)."],
     "pose": "reach"},
    {"type": "step", "n": 1, "title": "hand it over out loud",
     "how": "name what's heavy. give it to Him before your head hits the pillow.",
     "verse": "1 Peter 5:7", "pose": "seated"},
    {"type": "step", "n": 2, "title": "answer the 1am thought out loud",
     "how": "a thought fought silently wins. SpeakLife puts the verse in your hand at 1am.",
     "verse": "Mark 4:39", "pose": "seated"},
    {"type": "step", "n": 3, "title": "let it go before lights out",
     "how": "the text. the comment. the person. don't carry it into bed.",
     "verse": "Ephesians 4:26", "pose": "seated"},
    {"type": "step", "n": 4, "title": "make Psalm 4:8 the last word",
     "how": "\"in peace I will lie down and sleep.\" say it last, every night.",
     "verse": "Psalm 4:8", "pose": "seated"},
    {"type": "ba", "label": "say this tonight",
     "before": "replaying today at 1am",
     "after": "lights off. peace on.",
     "declaration": "I lie down in peace and my sleep is sweet, because the Lord keeps me safe.",
     "pose": "seated"},
    {"type": "close",
     "lines": ["the 1am thought doesn't get the last word. His does.",
               "awake anyway? He didn't move."],
     "pose": "reach"},
]

NIGHT_META = {
    "title": "what to do every night before bed",
    "caption": ("you can't win the night with a silent mind. step 2 is the whole key. save this for tonight."),
    "hashtags": ["#christiantiktok", "#jesus", "#bedtimeprayer", "#scripture", "#fyp"],
    "cta_sub": "bedtime declarations · 7 days free",
}

MORNING = [
    {"type": "hook", "kicker": "tutorial · 4 steps",
     "lines": ["what to do first thing every morning", "(step 2 is the key)"],
     "pose": "seated"},
    {"type": "hook", "anchor": True, "kicker": "Mark 1:35",
     "lines": ["still dark. the house asleep.",
               "Jesus didn't wait to see how the day went.",
               "He got up and prayed first.",
               "same Spirit lives in you (Romans 8:11)."],
     "pose": "reach"},
    {"type": "step", "n": 1, "title": "first words go to God",
     "how": "before the phone. before the news. He hears your voice first.",
     "verse": "Psalm 5:3", "pose": "seated"},
    {"type": "step", "n": 2, "title": "answer the first lie out loud",
     "how": "a thought fought silently wins. SpeakLife's Daily Burst hands you 7 before coffee.",
     "verse": "Matthew 4:4", "pose": "seated"},
    {"type": "step", "n": 3, "title": "speak to today's mountain",
     "how": "name what's in front of you today. talk to it, not about it.",
     "verse": "Mark 11:23", "pose": "seated"},
    {"type": "step", "n": 4, "title": "let yesterday go",
     "how": "yesterday doesn't get the first word. His mercy is new this morning.",
     "verse": "Lamentations 3:22-23", "pose": "seated"},
    {"type": "ba", "label": "say this today",
     "before": "losing the day by 9am",
     "after": "won before it started.",
     "declaration": "His mercies are new this morning, and I walk into this day more than a conqueror.",
     "pose": "seated"},
    {"type": "close",
     "lines": ["the day doesn't get the first word. His does.",
               "slept through the alarm? mercy's still new."],
     "pose": "reach"},
]

MORNING_META = {
    "title": "what to do first thing every morning",
    "caption": ("the day is won in the first 10 minutes. step 2 is the whole key. save this for tomorrow morning."),
    "hashtags": ["#christiantiktok", "#jesus", "#morningprayer", "#scripture", "#fyp"],
    "cta_sub": "7 declarations every morning · 7 days free",
}

# The PAIN-06 what-if spine, two new storms. Health stays faith-practice
# (the close tells them to keep the appointment); provision stays inheritance
# (no money promised, the Father knows).
WHATIF_BODY = [
    {"type": "hook", "kicker": "tutorial · 3 steps",
     "lines": ["\"what if it's something serious?\"", "Jesus spoke to that. (step 2 is the key)"],
     "pose": "seated"},
    {"type": "hook", "anchor": True, "kicker": "Mark 1:40-42",
     "lines": ["a man nobody would touch. Jesus touched him.",
               "\"I am willing. Be clean!\"",
               "He didn't pray about it. He spoke to it.",
               "same Spirit lives in you (Romans 8:11)."],
     "pose": "reach"},
    {"type": "step", "n": 1, "title": "name it: that's fear talking",
     "how": "a what-if isn't a diagnosis. it's a thought. call it what it is.",
     "verse": "2 Timothy 1:7", "pose": "seated"},
    {"type": "step", "n": 2, "title": "find what God says about it",
     "how": "at 1am you won't know where to look. type the thought into SpeakLife. it hands you the verse.",
     "verse": "Psalm 107:20", "pose": "seated"},
    {"type": "step", "n": 3, "title": "say it out loud",
     "how": "\"He sent out his word and healed them.\" say it over your body, slowly.",
     "verse": "Psalm 107:20", "pose": "seated"},
    {"type": "ba", "label": "say this tonight",
     "before": "googling symptoms at 1am",
     "after": "His word gets the first word.",
     "declaration": "By His wounds I am healed, and His life is at work in this body.",
     "pose": "seated"},
    {"type": "close",
     "lines": ["the what-if doesn't get the last word. His does.",
               "keep the appointment. He's in that room too."],
     "pose": "reach"},
]

WHATIF_BODY_META = {
    "title": "what to do when the what-if hits at 1am",
    "caption": ("Jesus didn't panic over the what-if. He spoke to it. step 2 is the whole key. save this for the next 1am."),
    "hashtags": ["#christiantiktok", "#jesus", "#healingscriptures", "#scripture", "#fyp"],
    "cta_sub": "a verse for every what-if · 7 days free",
}

WHATIF_MONEY = [
    {"type": "hook", "kicker": "tutorial · 3 steps",
     "lines": ["\"what if the money runs out?\"", "Jesus answered that one. (step 2 is the key)"],
     "pose": "seated"},
    {"type": "hook", "anchor": True, "kicker": "Matthew 6:31-32",
     "lines": ["a hillside crowd. most of them poor.",
               "\"do not worry, saying, 'What shall we eat?'\"",
               "\"your heavenly Father knows that you need them.\"",
               "same Father. still knows."],
     "pose": "reach"},
    {"type": "step", "n": 1, "title": "name it: that's fear doing math",
     "how": "the 11pm numbers aren't a prophecy. they're a what-if. call it that.",
     "verse": "Matthew 6:34", "pose": "seated"},
    {"type": "step", "n": 2, "title": "find what God says about it",
     "how": "at 11pm you won't know where to look. type the worry into SpeakLife. it hands you the promise.",
     "verse": "Philippians 4:19", "pose": "seated"},
    {"type": "step", "n": 3, "title": "say it out loud",
     "how": "\"my God will meet all your needs.\" say it over the bills, not about them.",
     "verse": "Philippians 4:19", "pose": "seated"},
    {"type": "ba", "label": "say this tonight",
     "before": "doing the math at 11pm",
     "after": "my Father already knows.",
     "declaration": "My Father knows what I need, and He meets every need I have.",
     "pose": "seated"},
    {"type": "close",
     "lines": ["the what-if doesn't get the last word. His does.",
               "still tight this month? He hasn't looked away."],
     "pose": "reach"},
]

WHATIF_MONEY_META = {
    "title": "what to do when the money what-if hits",
    "caption": ("Jesus already answered the \"what if the money runs out\" question. step 2 is the whole key. save this."),
    "hashtags": ["#christiantiktok", "#jesus", "#godwillprovide", "#scripture", "#fyp"],
    "cta_sub": "a promise for every what-if · 7 days free",
}

# Identity before the crisis: don't wait for the storm to find out who you
# are in Christ. Identity is the payoff, never the cold opener (LEARNINGS
# 2026-10-01 lesson 6), so the hook leads with the crisis moment.
IDENTITY = [
    {"type": "hook", "kicker": "tutorial · 3 steps",
     "lines": ["the crisis is the worst time to find out who you are", "(step 2 is the key)"],
     "pose": "seated"},
    {"type": "hook", "anchor": True, "kicker": "Matthew 3:17 · 4:3",
     "lines": ["before one miracle, the Father said: \"This is my Son, whom I love.\"",
               "then the wilderness. first attack: \"If you are the Son of God...\"",
               "He didn't find out who He was in the storm. He walked in knowing.",
               "same Spirit lives in you (Romans 8:11)."],
     "pose": "reach"},
    {"type": "step", "n": 1, "title": "learn what Jesus already paid for",
     "how": "peace. healing. provision. a sound mind. settled before you ever need it.",
     "verse": "2 Peter 1:3", "pose": "seated"},
    {"type": "step", "n": 2, "title": "renew your mind to it every day",
     "how": "not in the crisis. SpeakLife puts it in your ears every morning, 7 declarations at a time.",
     "verse": "Romans 12:2", "pose": "seated"},
    {"type": "step", "n": 3, "title": "say it out loud while it's calm",
     "how": "what you speak on the good days is what comes out on the hard ones.",
     "verse": "Luke 6:45", "pose": "seated"},
    {"type": "ba", "label": "say this today",
     "before": "googling verses mid-crisis",
     "after": "already know who I am.",
     "declaration": "I already have everything I need in Christ, and I walk into every storm knowing who I am.",
     "pose": "seated"},
    {"type": "close",
     "lines": ["the storm doesn't tell you who you are. He already did.",
               "already in one? start today. He's right there."],
     "pose": "reach"},
]

IDENTITY_META = {
    "title": "the crisis is the worst time to find out who you are",
    "caption": ("the crisis is the worst time to find out who you are in Christ. step 2 is the whole key. save this."),
    "hashtags": ["#christiantiktok", "#jesus", "#identityinchrist", "#renewyourmind", "#fyp"],
    "cta_sub": "7 declarations every morning · 7 days free",
}

if __name__ == "__main__":
    for slug, deck, meta in [("night-before-bed", NIGHT, NIGHT_META),
                             ("morning-victory", MORNING, MORNING_META),
                             ("whatif-body", WHATIF_BODY, WHATIF_BODY_META),
                             ("whatif-money", WHATIF_MONEY, WHATIF_MONEY_META),
                             ("identity-before-crisis", IDENTITY, IDENTITY_META)]:
        out = os.path.join(OUT, slug)
        render.build_slideshow(deck, out, meta=meta)
        print(out)
