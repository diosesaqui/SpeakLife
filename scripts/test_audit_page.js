/**
 * Drive the built Storm Audit page in a real browser, once per route.
 *
 * Checks the things a screenshot cannot: that every route reaches a result, that
 * the branching picks the right copy, that the deep link carries the right ob=
 * code, that the gap list never exceeds three, and that no console error fires
 * anywhere in the run.
 *
 *   node scripts/test_audit_page.js
 */
const { chromium } = require('playwright');
const path = require('path');

// The environment ships Chromium at a pinned path; the npm playwright version
// here expects a different revision, so point it at the installed one.
const EXE = process.env.CHROMIUM_PATH || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const LAUNCH = { executablePath: EXE, args: ['--no-sandbox', '--ignore-certificate-errors'] };

const PAGE = 'file://' + path.resolve(__dirname, '../marketing/storm-audit/index.html');

// route -> the Q1 answer, and the Q1b answer when the route needs one
const ROUTES = {
  mind:     ['mind'],
  body:     ['body'],
  money:    ['money'],
  self:     ['self'],
  calling:  ['calling'],
  loss:     ['heart', 'loss'],
  flat:     ['heart', 'flat'],
  spouse:   ['people', 'spouse'],
  child:    ['people', 'child'],
  prodigal: ['people', 'prodigal'],
  all:      ['all'],
};

const EXPECTED_OB = {
  mind: 'anxiety', body: 'healing', money: 'provision', self: 'renewal',
  calling: 'outcomes', loss: 'grief', flat: 'depression', spouse: 'marriage',
  child: 'parenting', prodigal: 'prodigal', all: 'hardtimes',
};

// Answers after Q2. Chosen to trigger several gaps at once so the cap is tested.
const TAIL = {
  q3: 'years', q4: 'pray_about', q5: 'once_twice',
  q6: 'phone', q7: 'diagnosis', q8: 'one',
};

let failures = 0;
function check(cond, msg) {
  if (!cond) { console.log('     FAIL ' + msg); failures++; }
  return cond;
}

async function pick(page, value) {
  const btn = page.locator(`#s-q .opt[data-v="${value}"]`);
  await btn.waitFor({ state: 'visible', timeout: 5000 });
  await btn.click();
}

async function run(route, answers) {
  const browser = await chromium.launch(LAUNCH);
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await ctx.newPage();

  const errors = [];
  // The sandbox proxies HTTPS with its own CA, so the Google Fonts request logs
  // a cert error here that does not exist in production. The page renders with a
  // system fallback either way; everything else is a real defect.
  const ignorable = /ERR_CERT_AUTHORITY_INVALID|fonts\.(googleapis|gstatic)\.com/;
  page.on('console', m => {
    if (m.type() === 'error' && !ignorable.test(m.text())) errors.push(m.text());
  });
  page.on('pageerror', e => errors.push(String(e)));

  await page.goto(PAGE);
  await page.click('#start');

  for (const a of answers) await pick(page, a);

  // Q2, free text
  await page.fill('#free', 'the thing I keep carrying');
  await page.click('#next');

  for (const q of ['q3', 'q4', 'q5', 'q6', 'q7', 'q8']) await pick(page, TAIL[q]);

  // email
  await page.waitForSelector('#s-email.on');
  await page.fill('#email', 'test@example.com');
  await page.click('#email-go');
  await page.waitForSelector('#s-result.on');

  const got = await page.evaluate(() => ({
    headline: document.querySelector('#r-h').textContent,
    quoted: (document.querySelector('.quoted') || {}).textContent || '',
    label: (document.querySelector('.label') || {}).textContent || '',
    gaps: document.querySelectorAll('.gap').length,
    identity: (document.querySelector('.identity') || {}).textContent || '',
    ledgers: document.querySelectorAll('.ledger').length,
    ctaHidden: !document.querySelector('#cta').classList.contains('on'),
    revealHidden: !document.querySelector('#reveal').classList.contains('on'),
    href: document.querySelector('#get').getAttribute('href'),
    pdf: document.querySelector('#dl').getAttribute('href'),
    bodyText: document.body.innerText,
  }));

  console.log(`  ${route}`);
  check(got.headline.length > 8, 'no result headline');
  check(got.quoted.includes('the thing I keep carrying'), 'Q2 not quoted back');
  check(/\bAsker\b/.test(got.label), `method label was "${got.label}", expected an Asker label`);
  check(got.gaps > 0 && got.gaps <= 3, `${got.gaps} gap cards, must be 1 to 3`);
  check(got.identity.length > 8, 'no identity line');
  check(got.ledgers >= 1, 'no waiting cost or ledger line');
  check(got.revealHidden, 'declaration revealed before the button was pressed');
  check(got.ctaHidden, 'CTA shown before the declaration');
  check(got.href.includes('ob=' + EXPECTED_OB[route]),
        `deep link is "${got.href}", expected ob=${EXPECTED_OB[route]}`);
  check(got.href.includes('utm_campaign=storm_audit'), 'deep link is missing UTMs');
  check(got.pdf.endsWith(`unshakable-${route}.pdf`), `plan link is "${got.pdf}"`);
  check(!/[—–]/.test(got.bodyText), 'em or en dash in rendered copy');
  check(!/\b(score|out of ten|\/10)\b/i.test(got.bodyText), 'a score appears on the result');

  // the reveal, and the three second hold before the CTA
  await page.click('#say');
  await page.waitForSelector('#reveal.on');
  const early = await page.evaluate(() =>
    document.querySelector('#cta').classList.contains('on'));
  check(!early, 'CTA appeared immediately instead of after the hold');
  await page.waitForSelector('#cta.on', { timeout: 6000 });

  check(errors.length === 0, 'console errors: ' + errors.join(' | '));
  await browser.close();
}

(async () => {
  console.log('Driving ' + Object.keys(ROUTES).length + ' routes\n');
  for (const [route, answers] of Object.entries(ROUTES)) await run(route, answers);

  // Back must preserve answers, and re-answering Q1 must clear a stale Q1b.
  const browser = await chromium.launch(LAUNCH);
  const page = await browser.newPage();
  await page.goto(PAGE);
  await page.click('#start');
  await pick(page, 'heart');
  await pick(page, 'loss');
  await page.click('#back');
  await page.click('#back');
  await pick(page, 'mind');
  const sub = await page.evaluate(() => {
    const s = JSON.parse(sessionStorage.getItem('speaklife.storm-audit.v1'));
    return { storm: s.storm, substorm: s.substorm };
  });
  console.log('\n  back navigation');
  check(sub.storm === 'mind', 'Q1 did not update on re-answer');
  check(sub.substorm === undefined, 'stale Q1b answer survived a Q1 change');
  await browser.close();

  console.log(failures ? `\n${failures} failure(s).` : '\nAll checks passed.');
  process.exit(failures ? 1 : 0);
})();
