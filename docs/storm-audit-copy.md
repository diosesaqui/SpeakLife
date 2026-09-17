# The Storm Audit — Final Copy

**Status:** final. This is the string source of truth for the audit page, the result page,
the eight-email sequence and the PDF.
**Companion:** `storm-audit-web-spec.md` (the build spec, logic and routing). This doc is
words only.

**Three rules for anyone editing this file:**
1. **No em dashes or en dashes.** Anywhere. Two sentences instead. This is a brand rule the
   app's own tests enforce.
2. **Declarations are verbatim** from `declarationsv10.json`. Do not reword, re-punctuate or
   "fix" them. If one looks wrong, it is not. Ask.
3. **Never score, grade or diagnose the reader's faith**, and never imply the storm is their
   fault. The gap is a method nobody handed them.

---

## Part 1 — The audit

### Landing

> **The Storm Audit**
> ## Eight questions. Sixty seconds.
> Find out which storm you are standing in, why it has not moved, and the one thing to do
> tomorrow morning.
>
> `[ Start ]`
> Free. No card, no account.

### Q1 — the storm

> **What is heaviest right now?**

| value | Option label |
|---|---|
| `mind` | My mind will not stop. |
| `body` | My body. |
| `money` | Money, work, the bills. |
| `self` | How I see myself. |
| `calling` | What I am supposed to be doing with my life. |
| `heart` | My joy, or something I lost. |
| `people` | Someone I love. |
| `all` | Everything at once. |

### Q1b — only when `heart`

> **Which one is closer?**

| value | Option label |
|---|---|
| `loss` | I lost someone. |
| `flat` | Everything feels flat. The joy is gone. |

### Q1b — only when `people`

> **Who is on your heart?**

| value | Option label |
|---|---|
| `spouse` | My marriage. |
| `child` | My kids. |
| `prodigal` | Someone who has walked away from God. |

### Q2 — their words

> **Say it in your own words.**
> One line. Nobody reads this but you.
>
> *placeholder:* `The thing I keep carrying is...`
> `[ Skip ]`

### Q3 — duration

> **How long has it been like this?**

`weeks` A few weeks · `months` A few months · `year` About a year · `years` Years

### Q4 — response

> **When it hits, what do you do?**

`pray_about` I pray about it · `read_verse` I read a verse · `distract` I try not to think
about it · `tell_someone` I tell someone · `nothing` Nothing, mostly

### Q5 — the hinge

> **Have you ever said God's Word out loud over this, by name?**
> Out loud. Not read, not thought.

`never` Never · `once_twice` Once or twice · `sometimes` Sometimes · `most_days` Most days

### Q6 — first hour

> **What does the first hour of your day sound like?**

`phone` My phone · `news` The news · `silence` Silence · `worship` Worship · `the_word`
God's Word

### Q7 — loudest voice

> **Whose voice do you hear most about this?**

`diagnosis` The diagnosis, or the report · `numbers` The numbers · `someone_said` What
someone said about me · `my_own` My own · `gods` God's

### Q8 — verse knowledge

> **Do you know a verse that speaks to this exact thing?**

`no` No · `one` One · `a_few` A few · `several` Yes, several

### Email

> **Where should we send your plan?**
> Seven declarations for your storm, one for each morning. Yours to keep.
>
> `[ email field ]`  `[ Show me my result ]`
>
> We send the plan and a short note each morning for a week. Leave whenever you want.

---

## Part 2 — Derived copy

### 2a. Method labels (beat 2)

Three variants. The label never appears without the reassurance under it.

| `method` | Line | Label | Reassurance |
|---|---|---|---|
| `Asker` | And you have been praying about it. Not to it. | You are an Asker. | Most people are. It is exactly what we were taught, and it is half the instruction. |
| `Reader` | And you have been reading it. Not saying it. | You are a Reader. | You know more Scripture than you give yourself credit for. It just has not made the trip from the page to your mouth yet. |
| `Speaker` | And you have already started speaking. Nobody gave you a way to keep it up. | You are a Speaker. | You are further along than most people who take this. What you need is not convincing. It is a rhythm that survives a bad week. |

### 2b. The six gap cards (beat 3)

Show at most three, in this priority order.

**1. `praying_about`**
> ### You have been praying about it, not to it.
> Jesus prayed constantly. But at the storm, the sickness and the grave, He did not ask the
> Father to handle it. He opened His mouth and spoke to the thing. Asking is real. It is
> also not the only instruction He left us.

**2. `never_spoken`**
> ### You know the verse. It has never been in your mouth.
> Faith comes by hearing. Your own voice is the one source of hearing you carry everywhere,
> for free, and it is the one almost nobody uses.

**3. `dont_know`**
> ### You do not know what God says about this exact thing.
> Not a general verse about trusting Him. The one written for a body, a bank account, a
> marriage, a child. It exists. Most of us were never shown where.

**4. `first_hour`**
> ### Your first hour belongs to something else.
> Whatever speaks first writes the script for the other fifteen hours. Right now something
> else is holding the pen, and it writes the same thing every day.

**5. `never_ran_it`**
> ### You have never run it longer than a few days.
> You have said it. You have just never said it long enough for it to become what you
> believe. Said once, it is a moment. Said for thirty mornings, it is a mind.

**6. `other_voice`**
> ### The loudest voice about this is not God's.
> The report. The numbers. The thing someone said about you. Whichever one gets the most
> airtime is the one you end up agreeing with.

### 2c. Waiting cost (shown unless `duration` = `weeks`)

> You have been carrying this for **{a few months / about a year / years}**. That is roughly
> **{120 / 360 / 1,080}** mornings your mind started on something other than what God said
> about it.

### 2d. Input ledger

If `loudest` is not `gods`:
> This week, the thing you are carrying got hundreds of run-throughs. What God says about it
> got a handful.

Otherwise, if `first_hour` is `phone` or `news`:
> Your first hour sets the script for the other fifteen. Right now something else is writing
> it.

---

## Part 3 — The eleven result pages

Beat 2 comes from Part 2a, beat 3 from 2b, and beat 4's shared block is identical
everywhere. Only **beat 1**, the **identity line** and the **first declaration** change.

### The shared beat 4 block

> **Jesus never prayed about a storm.**
>
> He was asleep in the boat while it filled with water. His friends woke Him up terrified.
> He did not ask the Father to calm it. He stood up and spoke to the weather.
>
> *"Quiet! Be still!" Then the wind died down and it was completely calm.*
> **Mark 4:39**
>
> Then He told us to do the same thing.
>
> *"Truly I tell you, if anyone says to this mountain, 'Go, throw yourself into the sea,'
> and does not doubt in their heart but believes that what they say will happen, it will be
> done for them."*
> **Mark 11:23**
>
> Says. Not thinks about. Not reads. Says.

### The eleven

| Route | Beat 1 headline | Identity line | First declaration (beat 5) |
|---|---|---|---|
| `mind` | You are standing in a storm in your mind. | You have the mind of Christ. | You gave me Your own peace, and I carry it into every room. *(John 14:27)* |
| `body` | You are standing in a storm over your body. | You are healed and whole. | Thank You Jesus, by Your wounds I am healed and whole. *(Isaiah 53:5)* |
| `money` | You are standing in a storm over your provision. | You are an heir, not a beggar. | You meet every need of mine from the riches of Your glory. *(Philippians 4:19)* |
| `self` | You are standing in a storm over who you are. | You are who God says you are. | I am a new creation in You, and the old is gone for good. *(2 Corinthians 5:17)* |
| `calling` | You are standing in a storm over your calling. | You are called, and already equipped. | Your plans for me are hope and a future, and I walk in them today. *(Jeremiah 29:11)* |
| `loss` | You are carrying a loss. | You are held, and you are not alone. | You hold me close and steady my spirit with Your own strength today. *(Psalm 34:18)* |
| `flat` | The joy has gone quiet. | The joy of the Lord is your strength. | You fill me with joy and peace, and I overflow with hope. *(Romans 15:13)* |
| `spouse` | You are standing in a storm over your marriage. | You carry peace into your home. | You build my house Yourself, and what You raise stands firm. *(Psalm 127:1)* |
| `child` | You are carrying your children. | You are the one who stands for them. | You are a shield around my children, and You lift their heads high. *(Psalm 3:3)* |
| `prodigal` | You are standing in the gap for someone. | You are the one who stands for them. | Jesus came to seek and save, and He is seeking the people I love right now. *(Luke 19:10)* |
| `all` | You are carrying everything at once. | You carry the authority Jesus gave you. | You are my refuge and my strength, and You are here the second I call. *(Psalm 46:1)* |

**`loss` and `prodigal` deliberately do not say "storm."** Grief is not a thing to rebuke,
and a person who has walked away is not weather. Do not template these two back into the
pattern.

### Beat 5 wrapper (all routes)

> `[ Say it out loud ]`
>
> *(on tap, reveal the declaration large, hold 3s, then the CTA)*
>
> Not in your head. Out loud, where your ears can hear it.
>
> **That is the whole method.** The other six are in your plan.
>
> `[ Get the app ]` · `[ Download my plan ]`

### The CTA block

> **You now have seven declarations for one storm.**
> SpeakLife has 3,586, across 80 categories, matched to the exact thing you are walking
> through.
>
> · **Your exact storm, not a category.** Say what you are facing in your own words and it
>   finds the Scripture written for it.
> · **Sixty seconds, before the day starts.** Ready when you open your eyes.
> · **Spoken over you while your hands are busy.** For the commute, the gym, the sleepless
>   night.
> · **Thirty days, not one good day.** A plan that carries you past the week your feelings
>   quit.
>
> 4.9 on the App Store. Free to start. No card to look around.

---

## Part 4 — The eleven declaration sets

Seven per route, one per morning. **All verbatim from the live app.**

### `mind`
1. You gave me Your own peace, and I carry it into every room. *(John 14:27)*
2. Your peace beyond all understanding guards my heart and my mind in Christ. *(Philippians 4:7)*
3. My mind stays fixed on You, and You keep me in perfect peace. *(Isaiah 26:3)*
4. You gave me power, love, and a sound mind, and my thinking stays clear. *(2 Timothy 1:7)*
5. You carry every care I hand You, because You care for me deeply. *(1 Peter 5:7)*
6. You sustain me, and I am never shaken, no matter what the day brings. *(Psalm 55:22)*
7. I am calm and quiet in You, resting like a child held close and content. *(Psalm 131:2)*

### `body`
1. Thank You Jesus, by Your wounds I am healed and whole. *(Isaiah 53:5)*
2. Thank You Jesus, You took all my sickness, and strength rises in this body every morning. *(Matthew 8:17)*
3. You carried sickness in Your own body, and by Your wounds I am healed. *(1 Peter 2:24)*
4. I live and do not die, and I tell what You have done. *(Psalm 118:17)*
5. The Spirit who raised Jesus lives in me and gives life to this body. *(Romans 8:11)*
6. My healing appears quickly, and Your light breaks over my body like the dawn. *(Isaiah 58:8)*
7. I am fearfully and wonderfully made, and every part of me works as You designed. *(Psalm 139:14)*

### `money`
1. You meet every need of mine from the riches of Your glory. *(Philippians 4:19)*
2. You provide for me, and my supply waits on the mountain before I arrive. *(Genesis 22:14)*
3. I am Your child and Your heir, and I step into my full inheritance. *(Galatians 4:7)*
4. You are my shepherd, and everything I need is already mine. *(Psalm 23:1)*
5. You did not spare Your own Son, so You freely give me all things. *(Romans 8:32)*
6. You bless me abundantly, so I have all I need and abound in every good work. *(2 Corinthians 9:8)*
7. Your blessing makes me rich, and it comes with rest and joy. *(Proverbs 10:22)*

### `self`
1. I am a new creation in You, and the old is gone for good. *(2 Corinthians 5:17)*
2. I am Your righteousness in Christ, and I stand right before You today. *(2 Corinthians 5:21)*
3. You formed me, redeemed me, and called me by name, and I am Yours forever. *(Isaiah 43:1)*
4. You call me Your child, and that is exactly what I am right now. *(1 John 3:1)*
5. You chose me, set me apart, and call me holy and dearly loved. *(Colossians 3:12)*
6. I am complete in You, and nothing in me is missing or unfinished. *(Colossians 2:10)*
7. You call me Your friend and not Your servant, and that is who I am. *(John 15:15)*

### `calling`
1. Your plans for me are hope and a future, and I walk in them today. *(Jeremiah 29:11)*
2. Every day of mine is written in Your book, and it unfolds right on time. *(Psalm 139:16)*
3. You called me by Your own purpose and grace before time began. *(2 Timothy 1:9)*
4. I am Your handiwork, and I walk today in the good works You prepared for me. *(Ephesians 2:10)*
5. Your purpose for me prevails over every plan I could make. *(Proverbs 19:21)*
6. I have the mind of Christ, so I know exactly what to do next. *(1 Corinthians 2:16)*
7. I am a new creation, the old is gone, and my future is wide open. *(2 Corinthians 5:17)*

### `loss`
1. You hold me close and steady my spirit with Your own strength today. *(Psalm 34:18)*
2. Every tear of mine is on Your scroll, and Your comfort covers me completely. *(Psalm 56:8)*
3. Underneath me are Your everlasting arms, and You are my refuge forever. *(Deuteronomy 33:27)*
4. Like a shepherd You gather me in Your arms and carry me close to Your heart. *(Isaiah 40:11)*
5. You heal my heart and bind up my wounds, and I am whole again. *(Psalm 147:3)*
6. Everyone I love in You lives forever, because You rose again. *(1 Thessalonians 4:14)*
7. You turned my grief into joy, and no one takes that joy from me. *(John 16:22)*

### `flat`
1. You fill me with joy and peace, and I overflow with hope. *(Romans 15:13)*
2. Your mercies meet me brand new every morning, and I rise into a clean start today. *(Lamentations 3:22-23)*
3. Your joy is my strength, and that well never once runs dry. *(Nehemiah 8:10)*
4. You crown me with beauty instead of ashes and clothe me in the oil of joy. *(Isaiah 61:3)*
5. You show me the path of life, and Your presence fills me with joy. *(Psalm 16:11)*
6. My comeback is already moving, and You restore me strong, firm, and steadfast. *(1 Peter 5:10)*
7. Joy is my clothing now, and dancing is back in my feet. *(Psalm 30:11)*

### `spouse`
1. You build my house Yourself, and what You raise stands firm. *(Psalm 127:1)*
2. My marriage is joined by Your own hand, and I let no one separate it. *(Matthew 19:6)*
3. You are the Rock, and I build my marriage on Your words so it stands. *(Matthew 7:24)*
4. With You as the third strand, my marriage is a cord that holds. *(Ecclesiastes 4:12)*
5. Your love holds me, and I honor my spouse above myself every day. *(Romans 12:10)*
6. Your wisdom is mine, and I build my home stone by steady stone. *(Proverbs 14:1)*
7. I am clothed in Your love, and it binds my marriage in perfect unity. *(Colossians 3:14)*

### `child`
1. You are a shield around my children, and You lift their heads high. *(Psalm 3:3)*
2. You began a good work in my children, and You carry it to completion. *(Philippians 1:6)*
3. You know Your plans for my children, plans to prosper them and give them hope. *(Jeremiah 29:11)*
4. You teach my children Yourself, and great is their peace. *(Isaiah 54:13)*
5. My words carry life over my children, and the blessing I speak takes root. *(Proverbs 18:21)*
6. You command Your angels over my children, and they are guarded on every road they walk. *(Psalm 91:11)*
7. As for me and my household, we serve You all the days of our lives. *(Joshua 24:15)*

### `prodigal`
1. Jesus came to seek and save, and He is seeking the people I love right now. *(Luke 19:10)*
2. You draw people to Jesus, and You are drawing the ones I love to Him now. *(John 6:44)*
3. You are patient toward everyone I love, and You want every one of them home. *(2 Peter 3:9)*
4. Your word never returns empty, and I speak it over my family every day. *(Isaiah 55:11)*
5. Your compassion never forgets the ones I love, and it lasts forever. *(Isaiah 49:15)*
6. I pray always and never give up, and I keep asking until the answer comes. *(Luke 18:1)*
7. You made me righteous, so my prayers are powerful and effective every time. *(James 5:16)*

**Why this set is shaped the way it is.** Scripture does not promise that another free
person will change, so not one of these declares what the prodigal will do. Every line
stands on God's heart toward them and on the speaker's own footing. **Do not add a line
promising they will come back.** It is the one thing this page must not say.

### `all`
1. You are my refuge and my strength, and You are here the second I call. *(Psalm 46:1)*
2. I stand strong because You are the strength of my heart and my portion forever. *(Psalm 73:26)*
3. You began a good work in me, and You carry it through to completion. *(Philippians 1:6)*
4. I am more than a conqueror, and Your love carries me into victory. *(Romans 8:37)*
5. You are the anchor of my soul, firm and secure, and I never drift. *(Hebrews 6:19)*
6. Your name is a strong tower, and I run into it and stand safe. *(Proverbs 18:10)*
7. You hold me steady, and I rise stronger by Your power every day. *(2 Corinthians 4:8-9)*

---

## Part 5 — The PDF shared pages

Seven shared pages plus three branched ones. Branched content comes from Part 3 (cover,
result) and Part 4 (the seven declarations).

**Page 1: cover (branched)**
> UNSHAKABLE
> ## Your 7-day plan for {storm}
> Seven declarations. Seven mornings. Sixty seconds each.

**Page 2: your result (branched)**
Their beat 1 headline, their Q2 line quoted, their three gaps as one line each.
> This is what you told us. Here is what to do with it.

**Page 3: the turn (shared)**
> ## Jesus never prayed about a storm.
> *(nothing else on the page)*

**Page 4: the proof (shared)**
> **He spoke to three things nobody speaks to.**
>
> **The storm.** *"Quiet! Be still!"* and the wind stopped. (Mark 4:39)
> **The sickness.** *"Be clean."* and the leprosy left. (Matthew 8:3)
> **The grave.** *"Lazarus, come out!"* and a dead man walked. (John 11:43)
>
> Not one of those was a request.

**Page 5: the hinge (shared)**
> **Then He said we do the same.**
>
> *"Truly I tell you, if anyone **says** to this mountain, 'Go, throw yourself into the
> sea,' and does not doubt in their heart but believes that what they **say** will happen,
> it will be done for them. Therefore I tell you, whatever you ask for in prayer, believe
> that you have received it, and it will be yours."*
> **Mark 11:23-24**
>
> Speaking is not our idea. It is the part He named.

**Page 6: the four rules (shared)**
> ## What makes a declaration work
>
> **First person.** You are the one speaking. Not a quote about someone else.
> **Present tense.** Faith says it done. Not one day, not please. Now.
> **One sentence.** The mouth cannot carry a paragraph with conviction.
> **Out loud.** Faith comes by hearing. Your ears are the delivery.
>
> That is the whole craft. Everything else is decoration.

**Page 7: call higher (shared)**
> ## Never say the low thing over yourself
>
> A declaration does not argue with the problem. It does not name it, rebuke it or ask it
> to settle down. It says the higher thing that makes the problem irrelevant.
>
> **Not this:** "Worry, calm down. I am trying not to be anxious."
> **This:** "I have the mind of Christ. It is clear, sound, and at rest."
>
> One of those keeps the problem in the room. The other one changes the subject to
> something truer.

**Page 8: your seven declarations (branched)**
The Part 4 set for their route, one per card, with the storm's verse at the top.

**Page 9: seven mornings (shared)**
> ## How to run it
>
> One declaration. Out loud. Before you touch your phone.
>
> Day one is the first line. Day seven is the last. If you miss a morning, say it in the car.
> The point is not a perfect week. The point is that your voice gets there before everything
> else does.
>
> **Then what.** Seven mornings changes a week. Thirty changes what you expect. That is not
> a motivational claim, it is what training is. *"Those who receive God's abundant provision
> of grace reign in life through Jesus Christ."* (Romans 5:17) Reigning is trained.
>
> You are not trying to feel unshakable. You are becoming it.

**Page 10: the ask (shared)**
The CTA block from Part 3, plus QR and App Store badge.

---

## Part 6 — The email sequence

Five emails, seven days. Each one branches on `audit_storm`. Subject lines only here; bodies
are one short idea and the same CTA.

| Day | Subject | The one idea |
|---|---|---|
| 0 | Your 7-day plan for {storm} | Delivery. Nothing else. One line: start tomorrow morning. |
| 1 | Did you say it out loud? | The one step everyone skips. Reading it in your head is not the method. |
| 3 | The verse written for {storm} | Their storm, one verse, expanded. A real matched testimonial where one exists. **Never fabricate one.** |
| 5 | Seven is not the number | The gap: seven declarations for one storm against 3,586 matched to the exact thing. |
| 7 | Thirty mornings | Rom 5:17, training for reigning, and the trial. |

**Do not send a sixth.** A free gift that turns into a drip campaign stops reading as a
gift, and the asset's whole job was to make the paid thing look like the free thing's
bigger sibling.

---

*Declarations verbatim from `declarationsv10.json`. Identity lines from `UserPain.problem`.
Verified against the live app, not written from memory.*
