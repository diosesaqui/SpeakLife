/**
 * Reads an on/off switch from the app's Firebase Remote Config, so one key
 * in the console turns a feature off on the phone and on the server at once.
 *
 * The server reads the parameter's default value. Conditional values
 * (percentage rollouts, platform conditions) only steer the app; to run the
 * server side the default has to be true.
 *
 * Cached for a few minutes, since a scheduler run checks it for every user.
 * Fails closed: if the template cannot be read and there is no earlier
 * answer, the feature is off.
 */

const DEFAULT_TTL_MS = 5 * 60 * 1000;

function makeRemoteFlag({ getTemplate, key, ttlMs = DEFAULT_TTL_MS, now = Date.now }) {
  let value = null;
  let readAt = 0;

  return async function isOn() {
    if (value !== null && now() - readAt < ttlMs) return value;
    try {
      const template = await getTemplate();
      const param = template && template.parameters && template.parameters[key];
      const raw = param && param.defaultValue && param.defaultValue.value;
      value = String(raw).trim().toLowerCase() === 'true';
      readAt = now();
    } catch (err) {
      console.warn(`Remote Config read for ${key} failed:`, err && err.message);
      if (value === null) return false;
    }
    return value;
  };
}

module.exports = { makeRemoteFlag };
