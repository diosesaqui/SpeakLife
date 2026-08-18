# Forced update gate

Retires an old build: users below a published minimum version get a blocking
screen whose only affordance is the App Store.

## Turning it on

Four Remote Config parameters, all registered with inert defaults in
`AppDelegate.didFinishLaunchingWithOptions`:

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `forceUpdateEnabled` | Boolean | `false` | Master switch. |
| `minimumAppVersion` | String | `""` | Oldest allowed `CFBundleShortVersionString`, e.g. `2.4.0`. |
| `forceUpdateTitle` | String | `""` | Optional headline override. Empty uses the shipped copy. |
| `forceUpdateMessage` | String | `""` | Optional body override. Empty uses the shipped copy. |

To retire everything below 2.4.0:

1. Publish the new build to the App Store and **wait for it to be live**. A
   floor above the newest available version locks every user out with nowhere
   to go.
2. Set `minimumAppVersion` to `2.4.0`.
3. Set `forceUpdateEnabled` to `true`.
4. Publish.

To release everyone again, set `forceUpdateEnabled` back to `false`. That alone
is enough — the floor is ignored while the switch is off, which is why the
switch, not the version string, is the thing to reach for in an incident.

## When it re-checks

`SubscriptionStore.evaluateForcedUpdate()` runs on every Remote Config apply:
the launch fetch, `HomeView`'s `willEnterForeground` fetch, and Firebase's
real-time config-update listener (which pushes a console change to running apps
within seconds, bypassing the fetch interval).

`ForceUpdateGate` additionally re-decides on every foreground from the config
already activated, so a user returning to a retired build is stopped before the
network round trip rather than after it.

Note the fetch interval: `minimumFetchInterval` is 5 hours in release builds, so
a foreground inside that window reuses the cached config. The real-time listener
covers apps that are already running; a cold launch after a long absence fetches
fresh. Neither path is instant for every user at once — plan a rollout, not a
switch-flip deadline.

## Safety properties

The decision is `MinimumVersionPolicy` in `SpeakLifeCore`
(`Packages/SpeakLifeKit/Sources/SpeakLifeCore/MinimumAppVersion.swift`), which
**fails open** on every ambiguity:

* switch off → allowed, whatever the floor says
* floor empty or unparseable (`v2.4.0`, `2.4.0-beta`, a typo) → allowed
* `CFBundleShortVersionString` unreadable → allowed
* floor equal to the current version → allowed (the floor is inclusive)

`2.4` and `2.4.0` are the same version, and components compare numerically, so
`2.10` is newer than `2.9`. Covered by `MinimumAppVersionTests`.

## Presentation

The screen is presented in its own `UIWindow` at `.alert + 1`, not as a
`.fullScreenCover`. SwiftUI presents one cover per context, and the app already
puts paywalls, onboarding and the daily burst up as covers — any of which would
otherwise sit on top of the gate.

That level is deliberately the same as the debug panel's, so a TestFlight tester
can shake past the gate (the later window wins the tie) and clear the override.
On the App Store the panel does not exist and the gate is absolute.

## Testing it without touching Firebase

Shake on a Debug or TestFlight build → **Forced update** section: type a minimum
above the running build (e.g. `99.0.0`), tap **Apply minimum version**, and turn
**Forced update gate** on. The gate appears immediately. Shake twice to bring the
panel back over it, then clear the overrides.

## Analytics

* `force_update_shown` — the gate went up. Params: `current_version`, `minimum_version`.
* `force_update_cta_tapped` — the user tapped through to the App Store.

A large gap between the two is the signal that the copy or the button is not
landing.
