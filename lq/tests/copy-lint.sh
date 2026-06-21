#!/bin/sh
# Copy regression guard: asserts the member-facing copy keeps native OAuth as the
# ONLY in-plugin sign-in (device-code retired in v0.7.0 — see plan/lq-oauth-refresh-fix),
# and that public docs use the business email. Greps the live source files; exit 0
# only if every assertion holds.

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

# start/SKILL.md — native Authenticate is the sign-in; device-code flow is gone.
has   "$START" "Authenticate"      "start: native Authenticate is the sign-in path"
hasnt "$START" "api/device/code"   "start: device-code flow removed"

# ask/SKILL.md — references native Authenticate
has "$ASK" "authenticate|native oauth" "ask: references native Authenticate"

# CLAUDE.md — native OAuth present, no actionable device-code endpoint
has   "$CLAUDE" "native OAuth"      "CLAUDE.md: native OAuth documented"
hasnt "$CLAUDE" "api/device/code"   "CLAUDE.md: no actionable device-code endpoint"

# plugin README — native sign-in, no device-code framing, business email only
has   "$PREADME" "native OAuth|Authenticate"   "README: native OAuth sign-in section"
hasnt "$PREADME" "device-code"                 "README: device-code framing removed"
has   "$PREADME" "j\.tso@legalquants\.com"     "README: business email present"
hasnt "$PREADME" "jamietso@gmail\.com"         "README: no personal gmail"

# CLAUDE.md is the other member-facing doc bundled into the plugin — guard it too.
hasnt "$CLAUDE" "jamietso@gmail\.com" "CLAUDE.md: no personal gmail"

if [ "$fail" -eq 0 ]; then echo "copy-lint.sh: ALL PASS"; exit 0; fi
echo "copy-lint.sh: FAILURES"; exit 1
