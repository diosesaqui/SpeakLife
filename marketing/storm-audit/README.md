# The Storm Audit

The lead-magnet quiz. One static page, no backend.

| | |
|---|---|
| Deploy | `index.html` only. Serve the plans from `CONFIG.PDF_BASE`. |
| Edit markup / behaviour | `template.html` |
| Edit words | `docs/storm-audit-copy.md` |
| Spec | `docs/storm-audit-web-spec.md` |

## Build and test

```
python3 scripts/build_audit_page.py    # copy deck -> index.html
node scripts/test_audit_page.js        # drives all 11 routes in Chromium
```

**Never hand-edit `index.html`.** It is generated. Edit the template or the copy
deck and rebuild, or the page stops saying what the PDFs and the app say.

The build refuses to run if an `ob=` code is not a real `OnboardingVariant` case,
if the deck's question values drift from the routing table, or if an em dash
reaches rendered copy. The browser test drives every route end to end and checks
the deep link, the gap cap, the hold before the CTA, and the console.

## Before it goes live

Three values in `CONFIG` at the top of the script block, and **marketing owns the
first two. Do not guess them:**

- `KLAVIYO_COMPANY_ID`
- `KLAVIYO_LIST_ID`
- `POSTHOG_KEY`

Until Klaviyo is configured the page still works: the subscribe is skipped and
the result renders. That is deliberate. The result must never wait on a network
call, and must render if one fails.

## Two things not to change without reading the spec

**`own_words` (Q2) goes to Klaviyo and never to PostHog.** It is free text about
somebody's marriage, diagnosis or child. The analytics event carries
`has_own_words` as a boolean instead.

**There is no score.** The result gives a storm, three gaps and a next step. A
number grading a person reads as a verdict on their faith, which is the wrong
product and the wrong theology. See the spec, section 5e.
