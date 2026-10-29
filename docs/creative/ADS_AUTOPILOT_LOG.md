# Ads Autopilot Log

Daily `speaklife-ads-daily` run. Newest first. Meta cost per trial unless noted. Line: $14 ceiling, $12 target.

## 2026-10-29 (06:00 PT)

**State:** only live campaign is test 120247236092730227. Active ad sets: new pack 120247448738950227 ($120/day, raised from $100 on Oct 28 10:46 PT, not by this job), SL-USE-01 120247643548440227 ($100/day). Active total $220 of $600 cap.
**Yesterday (Oct 28):** $172.63 spend, 7 Meta trials ($24.66), 5 RevenueCat trials.
**7d check (Oct 22–28):** Meta 47 trials ($1,611 spend incl. what-if pack) vs RevenueCat 37 (79%). Above 60% floor.

Actions:
- PAUSED 120247613753980227 "Keep praying. Start speaking." lifetime $30.26, 0 trials, 50h old (rule: ≥ $30 with 0 trials). Also brought new pack from 7 active ads to 6 (cap). Verified PAUSED.
- WINNER still qualifies: 120247604519430227 "One less scroll" lifetime $79.60 / 8 trials / $9.95. Graduation FAILED again:
  - Created campaign 120247649587660227 with `is_skadnetwork_attribution: true` on create and again via update. Ad set create still rejected ("AEM ... must be an iOS14+ campaign", subcode 3955009). The flag does not take through this API. Renamed it "UNUSED - not iOS14 type - SL Winners attempt Oct 29", PAUSED, no ad sets, no spend.
  - Test original left ON.
  - **Next run:** do NOT retry the same call. Try `ads_create_campaign` with `source_campaign_id: 120247236092730227` (copy the iOS14 test campaign) if the owner has not built the Winners campaign by hand.
- LAUNCHED: none. New pack at 6 active, test campaign at its 5-ad-set cap, and today's one new campaign was used on the Winners attempt.
- SCALED: none. New pack last 3d $266.23 / 11 = $24.20; SL-USE-01 no spend yet.

Held:
- 120247604792060227 "Fix your thoughts..." OWNER HOLD. API lifetime $60.40 / 2 / $30.20; 7d $59.40 / 2.
- 120247621934830227 "Do you need a promise from God?" $55.72 / 0 trials, 7 installs. 40h old at run time. Pause candidate after Oct 29 14:00 PT.
- 120247636375750227 "F6 scroll phone (cliff)" $33.53 / 2 / $16.77, 20h old. Watch.
- 120247636376850227 "F12 scroll fivemin (lake)" $15.76 / 0, 20h old.
- 120247604791410227 "Let His Word speak louder." $8.79 / 0. Barely delivering.
- SL-USE-01 ads 120247643633550227, 120247644098610227, 120247644274890227: under $2 each, hours old.

## 2026-10-28 (09:30 PT)

**State:** test campaign 120247236092730227 live ad sets: new pack 120247448738950227 ($100/day), PAIN-06 relaunch 120247622449000227 ($50/day). Owner paused "women 25-65 Videos" 120247342134890227 (Oct 28 08:54 PT) and "Sofia" 120247598207200227 (Oct 27). Active daily budget total $150 of $600 cap.
**Yesterday (Oct 27):** $229.27 spend, 9 Meta trials ($25.47), 6 RevenueCat trials.
**7d check (Oct 21–27):** Meta 40 trials vs RevenueCat 35 (88%). Above 60% floor, budget changes allowed.

Actions:
- WINNER QUALIFIED: ad 120247604519430227 "One less scroll. One more moment with God." lifetime $52.27 / 5 trials / $10.45 (< $12, ≥ 5). Graduation attempted and NOT completed:
  - Created campaign 120247636282810227 "SL Winners | Oct 2026" without the iOS 14+ flag; ad set create failed ("AEM attribution needs an iOS14+ campaign"); flag can't be changed after creation. Renamed it "UNUSED - not iOS14 type - SL Winners attempt Oct 28", left PAUSED, no ad sets, no spend. Did not create a second campaign (1 new campaign per run).
  - Test original left ON (only pause it once the Winners copy is ACTIVE).
  - **Next run:** create "SL Winners | Oct 2026" with `is_skadnetwork_attribution: true` on ads_create_campaign, then the $50/day ad set + ad from creative 3691565081009188.
- LAUNCHED in new pack (variations of the winner, rule: winner qualified + new pack < 6 active):
  - 120247636375750227 "F6-Moment-mornings-S-none | scroll phone (cliff)", creative 1530555045542488, video 2935847180101720. IN_PROCESS.
  - 120247636376850227 "F12-GutCheck-mornings-S-none | scroll fivemin (lake)", creative 2432783637253171, video 1002198402925618. IN_PROCESS.
- PAUSED: none. SCALED: none (no ad set under $12 over last 3 days with ≥ 3 trials; new pack 3d ≈ $140 / 5 = $28, PAIN-06 relaunch $28.78 / 2 = $14.39).

Held (under 48h old, re-check next run):
- 120247604792060227 "Fix your thoughts..." $53.81 / 2 / $26.91. Created Oct 26 17:02 PT. Pause candidate after Oct 28 17:02 PT.
- 120247621934830227 "Do you need a promise from God?" $35.88 / 0 trials. Created Oct 27 14:00 PT. Pause candidate after Oct 29 14:00 PT.
- 120247622450100227 "PAIN-06 fever what-if | relaunch" $46.64 / 2 / $23.32. Created Oct 27 14:57 PT. Pause candidate after Oct 29 14:57 PT unless it drops under $14.
- 120247613753980227 "Keep praying. Start speaking." $17.45 / 0; 120247604791410227 "Let His Word speak louder." $7.89 / 0. Not enough spend.

## 2026-10-29 (owner request, interactive)
- DELETED ad set 120247622449000227 "PAIN-06 relaunch" ($74.57, 2 trials, $37.29/trial), owner asked; freed the 5th ad-set slot in test campaign 120247236092730227.
- CREATED ad set 120247643548440227 "SL-USE-01 morning routine (Bend remix) | women 25-65 | Oct 29", $50/day, same AEM setup. ACTIVE.
- Ads (IN_PROCESS): 120247643633550227 hardtimes-week, 120247643634340227 promises-7days, 120247643634620227 gratitude-phone. Each hook paired with the owner's matching feed recording (Hard Times / Destiny / Gratitude).
- First versions (120247643570150227, 120247643570950227, 120247643571050227) archived before ever running; replaced by v2 cuts with new recordings and music.
- Owner: give each cut its own opening so Meta doesn't treat them as one ad. New openings: Grace on the edge of her bed (7days), Naomi reaching for her phone in bed (phone); week keeps Sofia in the kitchen. Archived 120247643634340227 and 120247643634620227 (minutes old, never delivered). New ACTIVE ads: 120247643845460227 7days-grace, 120247643845880227 phone-naomi. Higgsfield ~73 credits.
- Owner: the Grace/Naomi cuts cut back to Sofia mid-video; redo so each ad is one woman start to finish. Generated 6 new scenes (Grace couch/park/balcony, Naomi kitchen table/city sidewalk/window), ~220 credits. Archived 120247643845460227 (7days, mixed cast). New ACTIVE 120247644058860227 "7days-grace-full". Naomi version replaces 120247643845880227 (see next line).
- Archived 120247643845880227 (phone, mixed cast). New ACTIVE 120247644098610227 "phone-naomi-full". Ad set 120247643548440227 left PAUSED (paused outside this session at 23:14 PT); owner to turn on.
- Owner: Grace ad showed the owner's hand (different skin tone) on the phone close-ups. Built clips/grace-hand.mp4: AI still of Grace's hand on a green-screen phone + owner's Hard Times screen recording keyed in (make_hand.py); floating cards now use the plain screen recording. ~3 credits.
- Archived 120247644058860227 (7days-grace-full, $0 spent, still in review). New ACTIVE 120247644274890227 "7days-grace-hand". Ad set back ON (owner). Live: week 120247643633550227, phone-naomi-full 120247644098610227, 7days-grace-hand 120247644274890227.
