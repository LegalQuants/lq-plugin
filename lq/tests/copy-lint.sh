#!/bin/sh
# Copy regression guard: asserts the member-facing copy keeps native OAuth as the
# PRIMARY sign-in and device-code as a clearly-labelled fallback (the steering the
# cutover shipped in #34), and that public docs use the business email. Greps the
# live source files; exit 0 only if every assertion holds.

set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../../.." && pwd)   # plugin/lq/tests -> repo root
START="$ROOT/plugin/lq/skills/start/SKILL.md"
ASK="$ROOT/plugin/lq/skills/ask/SKILL.md"
CLAUDE="$ROOT/plugin/lq/CLAUDE.md"
PREADME="$ROOT/plugin/lq/README.md"
fail=0

has(){    if grep -qiE "$2" "$1" 2>/dev/null; then echo "  PASS  $3"; else echo "  FAIL  $3 [$1]"; fail=1; fi; }
hasnt(){  if grep -qiE "$2" "$1" 2>/dev/null; then echo "  FAIL  $3 [$1]"; fail=1; else echo "  PASS  $3"; fi; }

for f in "$START" "$ASK" "$CLAUDE" "$PREADME"; do
  [ -r "$f" ] || { echo "FATAL: missing $f"; exit 2; }
done

echo "copy-lint.sh"

# start/SKILL.md — old force-run removed; native named primary
hasnt "$START" "no other way in|don'?t ask first" "start: old device-code force-run removed"
has  "$START" "primary = native OAuth|native OAuth.*primary|primary.*native OAuth" "start: native OAuth named primary"

# start/SKILL.md — the native-primary framing precedes the actual device-code step.
# Match the INTENT (native + primary on one line) rather than an exact phrase, so a
# benign reword ("native OAuth (primary)" etc.) doesn't trip the lint.
pn=$(grep -niE "native OAuth.*primary|primary.*native OAuth" "$START" | head -1 | cut -d: -f1)
dn=$(grep -nF "api/device/code" "$START" | head -1 | cut -d: -f1)
if [ -n "$pn" ] && [ -n "$dn" ] && [ "$pn" -lt "$dn" ]; then
  echo "  PASS  start: native-primary framing (L$pn) precedes device-code step (L$dn)"
elif [ -n "$pn" ] && [ -z "$dn" ]; then
  echo "  PASS  start: native-primary framing present (no device step found to order against)"
else
  echo "  FAIL  start: native-primary must precede device-code step (primary L$pn, device L$dn)"; fail=1
fi

# ask/SKILL.md — references native Authenticate
has "$ASK" "authenticate|native oauth" "ask: references native Authenticate"

# CLAUDE.md — leads native, device-code labelled legacy
has "$CLAUDE" "native OAuth access token \(primary\)|primary = native OAuth|native OAuth.*primary" "CLAUDE.md: native OAuth named primary"
has "$CLAUDE" "legacy" "CLAUDE.md: device-code labelled legacy"

# plugin README — native-first section + fallback label + business email, no personal gmail
has   "$PREADME" "native OAuth" "README: native OAuth sign-in section"
has   "$PREADME" "legacy fallback|fallback \(device-code\)" "README: device-code labelled fallback"
has   "$PREADME" "j\.tso@legalquants\.com" "README: business email present"
hasnt "$PREADME" "jamietso@gmail\.com" "README: no personal gmail"

# CLAUDE.md is the other member-facing doc bundled into the plugin — guard it too.
# (Root README.md is the internal monorepo readme, not mirrored to the public plugin
#  repo, so it is intentionally out of this lint's scope.)
hasnt "$CLAUDE" "jamietso@gmail\.com" "CLAUDE.md: no personal gmail"

if [ "$fail" -eq 0 ]; then echo "copy-lint.sh: ALL PASS"; exit 0; fi
echo "copy-lint.sh: FAILURES"; exit 1
