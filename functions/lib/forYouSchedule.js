/**
 * When each user's weekly For You set is due: Sunday 6pm in their own time
 * zone. Stored as an absolute instant (nextRunAt) so the hourly scheduler
 * only has to ask "who is due by now", and daylight saving is handled once,
 * here, when the instant is computed.
 */

const DROP_WEEKDAY = 0; // Sunday
const DROP_HOUR = 18;
const DEFAULT_TIME_ZONE = 'America/New_York';

const WEEKDAYS = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };

function isValidTimeZone(tz) {
  if (typeof tz !== 'string' || !tz) return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

function localParts(date, tz) {
  const parts = {};
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    hourCycle: 'h23',
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
    weekday: 'short',
  });
  for (const p of fmt.formatToParts(date)) parts[p.type] = p.value;
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
    weekday: WEEKDAYS[parts.weekday],
  };
}

/** Milliseconds the zone is ahead of UTC at that instant. */
function offsetAt(date, tz) {
  const p = localParts(date, tz);
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return asUtc - Math.floor(date.getTime() / 1000) * 1000;
}

/** The instant a wall-clock time happens in a zone. */
function wallTimeToUtc(year, month, day, hour, tz) {
  const guess = Date.UTC(year, month - 1, day, hour);
  const first = guess - offsetAt(new Date(guess), tz);
  // Re-check at the result: if a DST change falls between the guess and the
  // real instant, the offset there is the one that applies.
  return new Date(guess - offsetAt(new Date(first), tz));
}

function pad(n) {
  return String(n).padStart(2, '0');
}

/**
 * The next Sunday 6pm local strictly after `now`.
 * → { at: Date, weekId: "YYYY-MM-DD" (that Sunday's local date) }
 */
function nextDrop(now, tz) {
  const zone = isValidTimeZone(tz) ? tz : DEFAULT_TIME_ZONE;
  const p = localParts(now, zone);
  let daysAhead = (DROP_WEEKDAY - p.weekday + 7) % 7;
  // Calendar arithmetic on a UTC date so month and year rollovers are free.
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const day = new Date(Date.UTC(p.year, p.month - 1, p.day + daysAhead));
    const at = wallTimeToUtc(day.getUTCFullYear(), day.getUTCMonth() + 1, day.getUTCDate(), DROP_HOUR, zone);
    if (at.getTime() > now.getTime()) {
      return {
        at,
        weekId: `${day.getUTCFullYear()}-${pad(day.getUTCMonth() + 1)}-${pad(day.getUTCDate())}`,
      };
    }
    daysAhead += 7;
  }
  throw new Error('nextDrop: unreachable');
}

module.exports = {
  nextDrop,
  isValidTimeZone,
  DROP_HOUR,
  DEFAULT_TIME_ZONE,
};
