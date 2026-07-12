# SpeakLife Web-to-App Funnel — Research & Phased Plan

*Researched July 2026. Legal/benchmark claims below were multi-source verified (adversarial 3-vote
fact-check, 103 research agents, 21 sources). Items marked "unverified" are gaps to confirm before
committing budget.*

---

## 1. Executive summary

**Yes — we can put a "pay on our website" button on the native paywall today at 0% Apple
commission (US storefront).** But the verified data says the naive version of that button
**loses money**, and the real prize is different:

1. **The steering button is not free money.** The only large public A/B test (RevenueCat ×
   Dipsea, ~12,500 US users, May 2025) showed link-out web checkout converts at **18.1% vs
   27.0%** for IAP — a 33% relative drop that fee savings don't cover. Net take-home was
   **$0.93 per $1.00 of IAP** at Apple's 30% rate, and ~**$0.86** at the 15% Small Business
   rate. Ship it only as a carefully designed, A/B-tested experiment (discounted web annual +
   Apple Pay express checkout), never as a default.
2. **The standalone web funnel (ads/social/search → web quiz → web paywall → app download) is
   the real play.** Web-acquired users overlap only ~15% with mobile-acquired users — it's an
   audience-expansion channel, not fee arbitrage. It also unlocks email capture, real ad
   attribution (no SKAdNetwork), unlimited pricing/promo freedom, and cancel-flow win-backs
   Apple forbids.
3. **The scaling premise works in our favor.** At 100k–300k subscribers we're far past the $1M
   Small Business cap and paying Apple 30%. At the 30% rate, web economics go from "loses ~14%"
   to "roughly break-even naive, positive once optimized." The bigger we get, the better web gets.
4. **Build now, but stress-test the P&L.** The 0% window is interim: the Ninth Circuit ordered a
   future cost-based Apple fee on link-outs (amount TBD on remand, expected well below 27%), and
   SCOTUS hears Apple's appeal in the Oct 2026 term (decision ~2027). Model the funnel assuming a
   future low-single-digit-to-low-teens Apple fee, and make sure the standalone web channel
   stands on its own economics either way.

---

## 2. Legal landscape (verified, as of July 2026)

| Question | Status |
|---|---|
| Can a US iOS app link to web checkout from its native paywall? | **Yes.** April 30, 2025 contempt order (Epic v. Apple) applies to all US developers. Apple's 12–27% link-out fee and scare screens were struck down. |
| Apple commission on those web purchases | **0% today.** Ninth Circuit (Dec 11, 2025) affirmed contempt but vacated the *permanent* zero-fee mandate; district court will set a cost-based fee ("genuinely and reasonably necessary" coordination costs + some IP, security/privacy costs excluded). Apple collects nothing until a rate is approved. |
| Scare screens / blocking | Prohibited. Only neutral leave-notices allowed. Apple cannot block buttons, links, or CTAs. |
| Design constraints | Apple regained **prominence parity** latitude: the web button cannot be *more* prominent than the IAP option (fonts, size, quantity, placement). Design for parity, not dominance. |
| Can we drop IAP entirely? | **No.** Web-only paywalls are legal only for "reader" apps (3.1.3(a)). SpeakLife must keep IAP on the native paywall; the web option sits alongside it. |
| Risk horizon | SCOTUS granted cert June 30, 2026 (No. 25-1311, argued Oct 2026 term, decided ~2027) — could unwind the remedy. District-court remand will set the future fee. **Assume the steering economics change; don't build anything that only works at 0%.** |
| EU / rest of world | **Not covered by verified research** — DMA external-purchase terms and Core Technology Fee/Commission need a separate check before enabling outside the US. Gate everything US-storefront-only at launch. |

Sources: Ninth Circuit opinion No. 25-2935 (cdn.ca9.uscourts.gov), SCOTUS order list 6/30/2026,
Perkins Coie and IPWatchdog analyses, MacRumors 12/11/2025.

## 3. Economics (verified benchmarks)

**RevenueCat × Dipsea four-way test** (new US iOS users, ~3,100+/variant, 3 weeks, May 2025 —
single app, ~190 payers/variant, treat as directional):

| Variant | Initial conversion | Notes |
|---|---|---|
| A: IAP only | **27.0%** | baseline |
| B: web link-out checkout | **18.1%** | −33% relative |
| C: IAP at standard price + web annual at 30% off | **23.5%** | best web hybrid |
| Trial→paid | 26.3% web vs 25.0% IAP | web slightly better, doesn't offset top-of-funnel |

- Net revenue: web button ≈ **$0.93 per $1.00** of IAP take-home at Apple 30%; ≈ **$0.86 at 15%**.
- Retention (Adapty/Paddle data via Airbridge — directional): web subs retain **better early**
  (Month 1: 84.5% vs 48.2%) but **worse long-run** (Month 8: ~20% vs ~30%).
- Audience overlap web vs mobile acquisition: **~15%** → web funnel = mostly *new* customers.
- Airbridge break-even model: a web funnel needs ≥ ~18% web conversion against a 25% IAP
  baseline at standard fees to pencil.
- Do **not** cite the "$10.8 web vs $40.1 in-app LTV" figure floating around — refuted (0–3) in
  verification.

**SpeakLife-specific math:** at 100k–300k subs on yearly plans ($19.99–$49.99), gross is well
past the $1M Small Business cap → Apple takes 30% (~$0.9M–$4.5M/yr at scale). Every subscriber
acquired or converted on web at Stripe ~3% instead saves ~27 points. That margin is the prize;
the Dipsea data just says *how* to chase it (new-audience web funnel first, cannibalizing
steering button second, and only with a discount + express checkout).

## 4. What exists today (codebase audit)

| Piece | Status |
|---|---|
| Payments | RevenueCat (`SubscriptionStore.swift`, `RevenueCatManager.swift`), entitlement `premium`. Server-side RC verification already exists in `functions/bibleChat.js`. |
| RC identity | **Anonymous per-install. `Purchases.shared.logIn` never called.** Web purchase currently has no way to reach an app install. **Blocking gap.** |
| Auth | Firebase Auth (email) + Sign in with Apple exist but optional and not linked to RC. |
| Paywall | `HighConversionPaywallView` (all onboarding variants, `source:"onboarding"`), gated by Firebase Remote Config flags on `SubscriptionStore`. |
| Deep linking | Branch SDK integrated (deferred deep links work); `speaklife://` scheme; **no universal links / associated domains**. |
| Analytics | PostHog (funnels), Firebase, Meta, TikTok SDKs. Funnel events documented in `docs/ANALYTICS_FUNNELS.md`. |
| Web | **Nothing.** No landing site, Firebase Hosting not configured. Firebase project `speaklife-3e5c4` + Cloud Functions (nodejs22) ready to host. |

## 5. Phased plan

### Phase 0 — Identity & entitlement plumbing (prerequisite, ~1–2 wks)
The foundation both funnels share. No user-visible change.

- [ ] Call `Purchases.shared.logIn(firebaseUID)` on auth; alias anonymous RC IDs. Add a
      lightweight account-creation path (email magic-link or Sign in with Apple) that doesn't
      block existing anonymous users.
- [ ] Stand up **RevenueCat Web Billing** (Stripe) in the same RC project → web purchase grants
      the same `premium` entitlement with zero custom sync code. *(Verify current Web Billing
      fee % and tax handling — not covered by verified research; compare vs Paddle MoR ~5% for
      sales-tax/VAT offload.)*
- [ ] Universal links: associated-domains entitlement + `apple-app-site-association` on our
      domain (Firebase Hosting), wired through existing Branch setup.
- [ ] PostHog events for every new step: `web_checkout_viewed/started/completed`,
      `web_funnel_quiz_*`, `app_login_from_web`.

### Phase 1 — Standalone web funnel MVP (the revenue play, ~4–8 wks)
Ads/social/email → web quiz → web paywall → account → app download → auto-login.

- [ ] Landing + **web quiz** mirroring the winning onboarding variant (warfare/quiz flow):
      question → belief mirror → personalized declaration → **email capture**.
- [ ] **Web paywall**: RC Web Billing / Stripe Checkout with Apple Pay + Google Pay express
      buttons (express checkout is the single biggest web-conversion lever), trial, annual-first
      pricing. Full pricing freedom — bundles, promos, pay-what-you-can.
- [ ] Post-purchase handoff: account auto-created with captured email → "Download SpeakLife" →
      Branch deferred deep link → app opens → magic-link/6-digit auto-login → `Purchases.logIn`
      → premium active, zero re-entry.
- [ ] Point Meta/TikTok campaigns at the web funnel (web pixels beat SKAdNetwork attribution);
      reuse `ob=` variant routing concept from `docs/AD_ONBOARDING_ROUTING.md`.
- [ ] Success bar: **≥18% paywall conversion** (Airbridge break-even threshold) and CAC payback
      ≤ existing app-install campaigns.

### Phase 2 — Native-paywall steering button (careful experiment, ~2–3 wks after Phase 0)
Not a default win — test it like the data demands.

- [ ] Variant C pattern, not naive link-out: keep IAP at standard price, offer **web annual at a
      meaningful discount** (we keep more even after the discount at 30% Apple rate), with Apple
      Pay express on the web page.
- [ ] Respect prominence parity: web button styled equal-or-lesser to the IAP CTA.
- [ ] Gate: US storefront only + Remote Config kill switch (`showWebCheckoutOption`), A/B via
      existing Remote Config + PostHog machinery.
- [ ] Decision metric: **net revenue per paywall viewer** (not conversion) vs control, plus
      refund/chargeback rate. Kill or keep per data. Re-run the math when the district court
      sets Apple's link-out fee.

### Phase 3 — Scale & compound (ongoing)
- [ ] Email/CRM lifecycle on the captured emails (today the app captures none): welcome
      sequence, win-back, dunning, cancel-flow save offers — all impossible under Apple rules.
- [ ] Web funnel A/B program in PostHog (quiz length, paywall design, price points).
- [ ] Tax/MoR decision at scale (Stripe Tax vs Paddle merchant-of-record) once web revenue is
      material.
- [ ] EU/DMA review before enabling steering outside the US.
- [ ] Watch: district-court remand fee ruling; SCOTUS decision (~2027). Re-model Phase 2
      economics when either lands.

## 6. Open questions before spending

1. Exact RevenueCat Web Billing pricing + tax handling vs Paddle MoR vs raw Stripe + Stripe Tax
   (research couldn't verify current tool pricing — confirm on vendor pricing pages).
2. What Apple link-out fee should the 2027 P&L assume (remand outcome)?
3. Does the Dipsea result replicate for our faith/wellness demo — specifically can discounted
   web annual + Apple Pay express flip the steering button net-positive? (That's what Phase 2
   measures.)
4. EU/DMA terms for a later international rollout.

## 7. Verified sources (key)

- Ninth Circuit opinion, Epic v. Apple No. 25-2935 (Dec 11, 2025) — cdn.ca9.uscourts.gov
- SCOTUS order list June 30, 2026 (cert granted, No. 25-1311) — supremecourt.gov
- Perkins Coie & IPWatchdog case analyses; MacRumors Dec 11, 2025
- RevenueCat × Dipsea IAP-vs-web A/B test — revenuecat.com/blog/growth/iap-vs-web-purchases-conversion-test
- Airbridge web-to-app profitability analysis (Adapty 2026 / Paddle data) — airbridge.io
