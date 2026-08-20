# Apple root certificates

`gifting.js` verifies StoreKit 2 signed transactions offline, against Apple's
root certificates. That verification is the only proof a gift was actually paid
for, so these files are load-bearing: without them `giftCreate` throws rather
than falling back to trusting the client.

They are public downloads, not secrets. They live here as files because they are
binary (DER), which does not travel well in an environment variable.

## What to download

From <https://www.apple.com/certificateauthority/>, save into this directory:

- `AppleRootCA-G3.cer` — the one that currently signs App Store JWS data
- `AppleRootCA-G2.cer` — kept alongside so an Apple chain change does not take
  purchases down before anyone notices

`gifting.js` reads every `.cer` in this directory, so adding a future root is a
matter of dropping the file in and redeploying.

## Verifying what you downloaded

    openssl x509 -inform DER -in AppleRootCA-G3.cer -noout -subject -fingerprint -sha256

The subject should read `Apple Root CA - G3` and the SHA-256 fingerprint should
match the one Apple publishes on the certificate authority page above.

## Note on testing

Xcode's StoreKit Testing signs transactions with a locally generated CA that
does not chain to these roots, so those transactions will not verify. Sandbox
testing of the gift flow needs a real Sandbox Apple ID, signed in on a device
through Settings → App Store → Sandbox Account.
