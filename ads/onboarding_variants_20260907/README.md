# Onboarding Variant Ad Test — 7 Qualifying Ads

One ad per single-issue onboarding arm. Style B (organic / native): solid dark navy,
centered mixed-weight text, no CTA button or badge on the image, so it reads as a post
rather than an ad and gets past ad blindness on cold traffic.

Every ad does one job on the image: **qualify**. It names the exact person, so the only
people who tap are the people whose arc is waiting on the other side of the link.

## Why these seven

The four live arms (`healing`, `provision`, `anxiety`, `renewal`) are the ones already
built for deep-linked creative. `purpose`, `joy` and `more` were added on this branch and
are new to this test:

- **purpose** — the biggest un-served angle. Not in crisis, off-course: called to more,
  still in the same spot. Seeds the `destiny` set.
- **joy** — heaviness and grief. Under-served by every competitor and scripture is
  strong on it (Psalm 30:5, Psalm 30:11, Psalm 42:5). Seeds the `joy` set.
- **more** — the one non-pain arm in the test. Everything else targets a storm, so this
  is the read on whether hunger converts as well as hurt. Cheaper audiences, and it tells
  us whether SpeakLife can scale past crisis targeting. Seeds the `faith` set.

## Ship checklist per ad

| Ad | Image | Deep link `ob=` | Seeds | Read creative against |
|---|---|---|---|---|
| Healing | `SpeakLife_Ad_healing.png` | `healing` | health | `healing_*` picker rows |
| Provision | `SpeakLife_Ad_provision.png` | `provision` | wealth | `provision_*` picker rows |
| Anxiety | `SpeakLife_Ad_anxiety.png` | `anxiety` | anxiety | `anxiety_*` picker rows |
| Renewal | `SpeakLife_Ad_renewal.png` | `renewal` | identity | `renewal_*` picker rows |
| Purpose | `SpeakLife_Ad_purpose.png` | `purpose` | destiny | `purpose_*` picker rows |
| Joy | `SpeakLife_Ad_joy.png` | `joy` | joy | `joy_*` picker rows |
| More | `SpeakLife_Ad_more.png` | `more` | faith | `more_*` picker rows |

Paste the **Branch link carrying `ob=<value>`** into the ad's destination field (see
`docs/AD_ONBOARDING_ROUTING.md`). The `ob=` code is what makes the onboarding continue the
ad's promise; without it the install falls into the random Remote Config experiment and the
test reads nothing.

`purpose`, `joy` and `more` only resolve on a build that ships this branch. Do not spend on
those three before that build is live, or their traffic lands in the default arm.

**Measurement.** These arms are targeted, not random-assigned, so never rank them against
each other or against the broad arms on raw conversion. Read each arm against itself over
time, and cut creative on `picker_choice` / `onboardingSegment` (`healing_diagnosis`,
`purpose_direction`, and so on) to see which intent inside the angle actually pays.

---

## 01 — HEALING (`ob=healing`)

**Image text:** If you're a Christian holding **a diagnosis, a chronic pain, or a prayer for someone you love**, this is for you.

**Primary text:**

```
You've prayed about it more times than you can count.

And you're still holding the report. Still managing the pain. Still asking God for
someone you love who hasn't turned the corner yet.

Here's what took me years to see: healing was bought at the same cross, with the same
blood, in the same hour as forgiveness. You don't beg for what's already been paid for.
You stand on it.

A man knelt in front of Jesus and said, if you are willing. Jesus didn't hesitate.
"I am willing."

That answer still stands over your body today.

SpeakLife puts God's Word about your healing in your mouth every single morning. Not
positive thinking. Not a devotional you skim. Scripture, spoken out loud, over the body
you have right now, until what God said carries more weight than what you feel.

Try free for 3 days 👇
```

**Headline:** Healing was already paid for
**Description:** Daily healing declarations, straight from His Word
**CTA button:** Download

---

## 02 — PROVISION (`ob=provision`)

**Image text:** If you're a Christian who is **short at the end of every month** and tired of watching the bills win, this is for you.

**Primary text:**

```
You do the math again. It still doesn't work.

You tithe. You work hard. You've cut everything there is to cut. And the month still
ends before the money does.

Nobody tells believers this part: your paycheck was never your source. It's a channel.
God is the source, and He's the one who gives you the ability to produce wealth. When a
channel narrows, the source hasn't moved an inch.

"My God will meet all your needs according to the riches of his glory."

All of them. Not most. Not what's left over.

SpeakLife hands you a scripture-rooted declaration over your finances every morning, so
you stop rehearsing the shortfall and start decreeing what God already said about your
provision. Job 22:28 calls it deciding on a thing and seeing it established.

Bills covered. Debt cleared. Doors opening you couldn't open yourself.

Try free for 3 days 👇
```

**Headline:** Your paycheck is not your source
**Description:** Speak God's Word over your finances daily
**CTA button:** Download

---

## 03 — ANXIETY (`ob=anxiety`)

**Image text:** If you're a Christian who loves God and **still lies awake at 3am**, this was made for you.

**Primary text:**

```
It's 3am again.

You love God. You read your Bible. You're in church every week. And your mind still
won't shut off long enough to let you sleep.

That's not weak faith. It means there's a weapon you haven't picked up yet.

Jesus didn't ask the Father to calm the water. He spoke to it. "Peace. Be still." Same
Spirit lives in you. Same Word is in your hands. Most of us have just never opened our
mouths and used it.

His peace was already handed to you on purpose. Not the kind the world gives and takes
back. The kind that guards your heart and your mind, and holds the line in the middle
of what you can't explain.

SpeakLife gives you one declaration to speak out loud every day, built for the exact
thing keeping you up. Your mind gets stayed on Him, and peace stops being a good day
and starts being your normal.

Try free for 3 days 👇
```

**Headline:** Peace that guards your mind
**Description:** Daily declarations for the 3am mind
**CTA button:** Download

---

## 04 — RENEWAL OF THE MIND (`ob=renewal`)

**Image text:** If you're a Christian who knows the Word but **can't stop the voice in your own head**, this is for you.

**Primary text:**

```
You know what the Bible says about you.

You just don't believe it at 7am when the voice in your head starts listing everything
you've failed at.

Head knowledge and heart knowledge are two different addresses. God never said He'd
transform you by rearranging your circumstances. He said be transformed by the renewing
of your mind, and everything downstream of that starts to move.

Here's the part most believers miss: your mind believes what it hears you say most.
Not what you read. What you say.

That's why you can know a verse for ten years and still talk to yourself like the old
version of you.

SpeakLife puts one scripture-rooted declaration in your mouth every morning, out loud,
until the way you see yourself finally matches the way He's always seen you. You take
every thought captive. You decide what stays.

You already have the mind of Christ. This is how you start agreeing with it.

Try free for 3 days 👇
```

**Headline:** Renew your mind, out loud, daily
**Description:** Replace the old script with His Word
**CTA button:** Download

---

## 05 — PURPOSE / CALLING (`ob=purpose`) — NEW ARM

**Image text:** If you're a Christian who knows **God called you to more** and you're still standing in the same spot, this is for you.

**Primary text:**

```
You know God put something on your life.

You just can't tell you're any closer to it than you were three years ago.

That gap will eat at a believer. Not a crisis. Just the quiet sense that you were made
for something you're not walking in yet, and the years keep moving.

Your days were written in His book before one of them came to be. He didn't call you
because of your resume or your record. He called you because of His own purpose and
grace, and He carries what He starts on to completion.

But here's the part nobody teaches: God calls things that are not as though they are.
You speak what He called you before the proof shows up. That's not hype. That's the
pattern He uses.

SpeakLife gives you a declaration over your calling every single morning, so your mouth
and your assignment finally agree, and your steps start lining up with what He said.

Direction you can act on. Doors opening at the right hour.

Try free for 3 days 👇
```

**Headline:** He finishes what He starts
**Description:** Daily declarations over your calling
**CTA button:** Download

---

## 06 — JOY (`ob=joy`) — NEW ARM

**Image text:** If you're a Christian **carrying a heaviness you can't explain** to anybody, this is for you.

**Primary text:**

```
You're functioning. You're showing up. Nobody would guess.

And there's a weight on you that you can't put words to, so you've stopped trying to
explain it to anybody.

You don't need to be talked out of it. You need what David did with it. He didn't wait
until he felt better. He talked to his own soul out loud: why are you downcast? Put
your hope in God. I will yet praise Him.

Your soul listens to your voice. That's not a nice thought, that's the mechanism.

God's joy isn't a mood you work up on a good day. It's His, given to you, and it's the
exact thing holding you up when nothing else is. He turns mourning into dancing. He
puts a limit on the night and sends the morning.

SpeakLife hands you His Word to speak over yourself every day until gladness stops
being a visitor.

Try free for 3 days 👇
```

**Headline:** The joy of the Lord is your strength
**Description:** Speak His Word until the heaviness lifts
**CTA button:** Download

---

## 07 — MORE OF GOD (`ob=more`) — NEW ARM

**Image text:** If you're a Christian who isn't in crisis but knows **there's more of God than you're living in**, this is for you.

**Primary text:**

```
Nothing's falling apart.

That's almost the problem. You're saved, you're steady, you're fine, and you know
there's more of God available than you're actually living in.

He never made nearness a guessing game. You will seek me and find me when you seek me
with all your heart. Come near to Him and He comes near to you. That's a promise with
no fine print on it.

And He's able to do immeasurably more than everything you've been asking Him for.

The thing that closes the gap isn't trying harder. Faith comes by hearing, and the
voice you hear most is your own. That's why speaking His Word out loud, daily, changes
what you actually believe.

SpeakLife gives you one declaration a day, rooted in scripture, so time in the Word
stops being a plan you restart every January and becomes something you actually keep.

Jesus said life to the full. Not managed. Full.

Try free for 3 days 👇
```

**Headline:** There's more, and He isn't hiding it
**Description:** A daily rhythm in His Word you'll keep
**CTA button:** Download

---

## Regenerating the images

`scripts/generate_variant_ads.py` in this folder. Poppins is pulled from the quote-card
skill's font assets. Edit the `ADS` list and re-run.
