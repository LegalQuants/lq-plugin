#!/bin/sh
# Invariant guard: the native-OAuth-only connector must NOT regress.
#   A) Structural (always): the connector is headersHelper-free (a headersHelper
#      suppresses native-OAuth refresh-token persistence — the daily-reauth bug;
#      see plan/lq-oauth-refresh-fix), the dead auth hook is gone, and the SERVER
#      still accepts the three credential types (guest shape, OAuth issuer,
#      Firebase cookie) — server support is intentionally unchanged.
#   B) Diff (when a `main` ref exists): committed changes vs main touch none of the
#      forbidden paths (lib/* verifiers, the route.ts auth classifier).
#
# Exit 0 only if all enforced checks pass.

set -u
ROOT=$(CDPATH= cd "$(dirname "$0")/../../.." && pwd)
MCP_JSON="$ROOT/plugin/lq/.mcp.json"
HOOK="$ROOT/plugin/lq/hooks/lq-auth-header.sh"
ROUTE="$ROOT/packages/lq-mcp/app/api/mcp/[transport]/route.ts"
fail=0
has(){  if grep -qE  "$2" "$1" 2>/dev/null; then echo "  PASS  $3"; else echo "  FAIL  $3"; fail=1; fi; }

[ -r "$MCP_JSON" ] || { echo "FATAL: missing $MCP_JSON"; exit 2; }
[ -r "$ROUTE" ]    || { echo "FATAL: missing $ROUTE"; exit 2; }

echo "invariants.sh"

# A) Connector is pure native OAuth — no injected auth headers, no dead hook.
#    Either a `headersHelper` OR a static `headers` block makes Claude Code source
#    auth externally and stop persisting the native-OAuth refresh token → daily
#    re-auth (the bug this PR fixes). Guard BOTH.
if grep -qE '"(headersHelper|headers)"' "$MCP_JSON"; then
  echo "  FAIL  .mcp.json must inject no auth (headersHelper/headers break native-OAuth refresh persistence)"; fail=1
else
  echo "  PASS  .mcp.json injects no auth headers (pure native OAuth)"
fi
# Positive shape: it really is the http lq-mcp connector.
if grep -q '"type": "http"' "$MCP_JSON" && grep -q 'mcp.legalquants.com/api/mcp/mcp' "$MCP_JSON"; then
  echo "  PASS  .mcp.json registers the http lq-mcp connector"
else
  echo "  FAIL  .mcp.json missing the expected http lq-mcp registration"; fail=1
fi
if [ -e "$HOOK" ]; then
  echo "  FAIL  dead hook lq-auth-header.sh still present"; fail=1
else
  echo "  PASS  dead auth hook removed"
fi

# A) Server still routes the three credential types (support unchanged).
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
else
  echo "  SKIP  no 'main' ref — diff guard skipped (structural checks still enforced)"
fi

if [ "$fail" -eq 0 ]; then echo "invariants.sh: ALL PASS"; exit 0; fi
echo "invariants.sh: FAILURES"; exit 1
