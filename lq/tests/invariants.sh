#!/bin/sh
# Invariant guard: the native-OAuth cutover must NOT disturb the protected surfaces.
#   A) Structural (always): the guest backdoor + {} fallthrough in the helper are
#      intact, and the server still accepts the three credential types (guest shape,
#      OAuth issuer, Firebase cookie).
#   B) Diff (when a `main` ref exists): committed changes vs main touch none of the
#      forbidden paths (lib/* verifiers, the route.ts auth classifier), and the
#      helper's guest branch / {} fallthrough are byte-unchanged vs main.
#
# Exit 0 only if all enforced checks pass.

set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../../.." && pwd)
HELPER="$ROOT/plugin/lq/hooks/lq-auth-header.sh"
ROUTE="$ROOT/packages/lq-mcp/app/api/mcp/[transport]/route.ts"
fail=0
has(){  if grep -qE  "$2" "$1" 2>/dev/null; then echo "  PASS  $3"; else echo "  FAIL  $3"; fail=1; fi; }
hasF(){ if grep -qF  "$2" "$1" 2>/dev/null; then echo "  PASS  $3"; else echo "  FAIL  $3"; fail=1; fi; }

[ -r "$HELPER" ] || { echo "FATAL: missing $HELPER"; exit 2; }
[ -r "$ROUTE" ]  || { echo "FATAL: missing $ROUTE"; exit 2; }

echo "invariants.sh"

# A) Helper backdoor + fallthrough intact
hasF "$HELPER" 'LQ_MCP_TOKEN' "helper: guest \$LQ_MCP_TOKEN branch present"
hasF "$HELPER" "printf '{}'"  "helper: {} fallthrough present"

# A) Server still routes the three credential types
has "$ROUTE" 'isGuestToken'            "route.ts: guest token shape-check present"
has "$ROUTE" 'verifyOAuthAccessToken'  "route.ts: OAuth access-token verification present"
has "$ROUTE" 'verifySessionCookie'     "route.ts: Firebase session-cookie verification present"
has "$ROUTE" 'LQ_OAUTH_ISSUER'         "route.ts: OAuth issuer routing present"

# B) Committed-diff guard vs main (skips cleanly if no main ref)
if git -C "$ROOT" rev-parse --verify -q main >/dev/null 2>&1; then
  base=$(git -C "$ROOT" merge-base main HEAD 2>/dev/null || echo main)
  changed=$(git -C "$ROOT" diff --name-only "$base" HEAD 2>/dev/null)
  bad=$(printf '%s\n' "$changed" | grep -E '^packages/lq-mcp/lib/|^packages/lq-mcp/app/api/mcp/\[transport\]/route\.ts$' || true)
  if [ -n "$bad" ]; then
    echo "  FAIL  committed diff vs main touches forbidden paths:"; printf '        %s\n' $bad; fail=1
  else
    echo "  PASS  committed diff vs main touches no lib/* or route.ts auth classifier"
  fi
  if git -C "$ROOT" diff "$base" HEAD -- plugin/lq/hooks/lq-auth-header.sh 2>/dev/null \
       | grep -qE '^[-+].*(LQ_MCP_TOKEN|printf .\{\})'; then
    echo "  FAIL  helper guest branch / {} fallthrough changed vs main"; fail=1
  else
    echo "  PASS  helper guest branch / {} fallthrough unchanged vs main"
  fi
else
  echo "  SKIP  no 'main' ref — diff guard skipped (structural checks still enforced)"
fi

if [ "$fail" -eq 0 ]; then echo "invariants.sh: ALL PASS"; exit 0; fi
echo "invariants.sh: FAILURES"; exit 1
