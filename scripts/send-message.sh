#!/usr/bin/env bash
#
# send-message.sh — send a personalized in-app push message via the
# sendPersonalMessage Cloud Function (no 200-char console limit).
#
# Setup (once):
#   1) cp scripts/send-message.env.example scripts/send-message.env
#   2) edit scripts/send-message.env and fill in MSG_FN_URL + MSG_BROADCAST_SECRET
#      (this file is gitignored so your secret never gets committed)
#
# Examples:
#   # Test to your own phone (paste your device's FCM token):
#   ./scripts/send-message.sh --test "<FCM_TOKEN>" \
#       --title "Jesus" --banner "I have a word for you. Tap to read." \
#       --message-title "I See You" \
#       --message "I see you. Not the version you show the world..."
#
#   # Same, but read the long message from a file:
#   ./scripts/send-message.sh --test "<FCM_TOKEN>" --message-file note.txt
#
#   # Broadcast to ALL users (omit --test, add --broadcast):
#   ./scripts/send-message.sh --broadcast --title "Jesus" \
#       --message-file note.txt
#
#   # See how many people it WOULD reach without sending:
#   ./scripts/send-message.sh --broadcast --dry-run --message "hi"
#
#   # Schedule instead of sending now (pick ONE):
#   ./scripts/send-message.sh --broadcast --message "hi" --delay-min 90
#   ./scripts/send-message.sh --broadcast --message "hi" --send-at "2026-07-08T19:00:00-04:00"
#
#   # Manage pending scheduled sends:
#   ./scripts/send-message.sh --list
#   ./scripts/send-message.sh --cancel "<doc id from --list>"

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$DIR/send-message.env" ] && source "$DIR/send-message.env"

usage() {
  sed -n '2,34p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

: "${MSG_FN_URL:?Missing MSG_FN_URL. Add it to scripts/send-message.env (the deployed function URL).}"
: "${MSG_BROADCAST_SECRET:?Missing MSG_BROADCAST_SECRET. Add it to scripts/send-message.env (same value you set with firebase functions:secrets:set).}"

TITLE="Jesus"
BANNER="I have a word for you. Tap to read."
MSG_TITLE=""
MESSAGE=""
TOKEN=""
BROADCAST=0
DRYRUN=0
SEND_AT=""
DELAY_MIN=""
LIST=0
CANCEL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)         TITLE="$2"; shift 2;;
    --banner)        BANNER="$2"; shift 2;;
    --message-title) MSG_TITLE="$2"; shift 2;;
    --message)       MESSAGE="$2"; shift 2;;
    --message-file)  MESSAGE="$(cat "$2")"; shift 2;;
    --test)          TOKEN="$2"; shift 2;;
    --broadcast)     BROADCAST=1; shift;;
    --dry-run)       DRYRUN=1; shift;;
    --send-at)       SEND_AT="$2"; shift 2;;
    --delay-min)     DELAY_MIN="$2"; shift 2;;
    --list)          LIST=1; shift;;
    --cancel)        CANCEL="$2"; shift 2;;
    -h|--help)       usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage; exit 1;;
  esac
done

if [[ "$LIST" -eq 0 && -z "$CANCEL" && -z "$TOKEN" && "$BROADCAST" -eq 0 ]]; then
  echo "Error: specify --test <FCM_TOKEN> or --broadcast (or --list / --cancel)" >&2
  exit 1
fi

if [[ -n "$TOKEN" && "$BROADCAST" -eq 1 ]]; then
  echo "Error: --test and --broadcast are mutually exclusive. Drop --test to reach all users." >&2
  exit 1
fi

# Build JSON + POST in python3 (ships with macOS dev tools) so message text
# with quotes/newlines is escaped safely — no shell-quoting headaches.
MSG_FN_URL="$MSG_FN_URL" \
SECRET="$MSG_BROADCAST_SECRET" \
TITLE="$TITLE" BANNER="$BANNER" MSG_TITLE="$MSG_TITLE" MESSAGE="$MESSAGE" \
TOKEN="$TOKEN" BROADCAST="$BROADCAST" DRYRUN="$DRYRUN" \
SEND_AT="$SEND_AT" DELAY_MIN="$DELAY_MIN" LIST="$LIST" CANCEL="$CANCEL" \
python3 - <<'PY'
import os, json, urllib.request, urllib.error

payload = {"secret": os.environ["SECRET"]}
if os.environ.get("LIST") == "1":
    payload["list"] = True
elif os.environ.get("CANCEL"):
    payload["cancel"] = os.environ["CANCEL"]
else:
    payload["title"] = os.environ["TITLE"]
    payload["body"] = os.environ["BANNER"]
    if os.environ.get("MSG_TITLE"): payload["messageTitle"] = os.environ["MSG_TITLE"]
    if os.environ.get("MESSAGE"):   payload["messageBody"]  = os.environ["MESSAGE"]
    if os.environ.get("TOKEN"):     payload["token"] = os.environ["TOKEN"]
    if os.environ.get("BROADCAST") == "1": payload["broadcast"] = True
    if os.environ.get("DRYRUN") == "1":    payload["dryRun"] = True
    if os.environ.get("SEND_AT"):   payload["sendAt"] = os.environ["SEND_AT"]
    if os.environ.get("DELAY_MIN"): payload["delayMinutes"] = float(os.environ["DELAY_MIN"])

req = urllib.request.Request(
    os.environ["MSG_FN_URL"],
    data=json.dumps(payload).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req) as r:
        print(r.read().decode())
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.read().decode()}")
PY
