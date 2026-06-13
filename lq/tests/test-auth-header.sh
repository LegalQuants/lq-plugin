#!/bin/sh
# Regression guard for plugin/lq/hooks/lq-auth-header.sh — the headersHelper that
# decides which Authorization header (if any) the lq-mcp connector sends.
#
# Pins the behaviour shipped in the native-OAuth cutover (#34): an EXPIRED member
# cookie is DROPPED (so the connector falls through to native OAuth instead of
# looping on a dead cookie), while the guest backdoor ($LQ_MCP_TOKEN) and the {}
# fallthrough stay intact, and a missing/unparseable expiry FAILS OPEN (keep the
# cookie — the server re-verifies and remains the source of truth).
#
# Pure POSIX sh; deps are the helper's own (sh + coreutils + date). Each case runs
# the real helper under an isolated env -i with a temp XDG_CONFIG_HOME so it can
# never read the developer's actual ~/.config/lq/token.json.
#
# NOTE: token.json fixtures are built by single-quote concatenation (no \"-escaping)
# and captured into a variable before comparison — escaped quotes nested inside
# "$(...)" get un-escaped by the outer quote layer and corrupt the argument.
#
# Exit 0 only if every case passes.

set -u
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
HELPER="$HERE/../hooks/lq-auth-header.sh"
COOKIE="COOKIEfake_eyJhbGc.payload.sig"
GUEST="GUESTfake_bearer_123"
FUTURE="2099-01-01T00:00:00Z"   # always in the future -> cookie valid
PAST="2000-01-01T00:00:00Z"     # always in the past   -> cookie expired
BEARER_COOKIE='{"Authorization":"Bearer '"$COOKIE"'"}'
BEARER_GUEST='{"Authorization":"Bearer '"$GUEST"'"}'
fail=0

[ -r "$HELPER" ] || { echo "FATAL: helper not found at $HELPER"; exit 2; }

# token.json fixtures (single-quote concatenation — no backslash-escaped quotes)
J_FUTURE='{"access_token":"'"$COOKIE"'","expires_at":"'"$FUTURE"'"}'
J_PAST='{"access_token":"'"$COOKIE"'","expires_at":"'"$PAST"'"}'
J_BAD='{"access_token":"'"$COOKIE"'","expires_at":"not-a-date"}'
J_NOEXP='{"access_token":"'"$COOKIE"'"}'

# run <token.json-contents | __NONE__> <LQ_MCP_TOKEN | __UNSET__>  -> helper stdout
run() {
  _tmp=$(mktemp -d) || { echo "FATAL: mktemp"; exit 2; }
  mkdir -p "$_tmp/config/lq"
  [ "$1" = "__NONE__" ] || printf '%s' "$1" > "$_tmp/config/lq/token.json"
  if [ "$2" = "__UNSET__" ]; then
    _out=$(env -i XDG_CONFIG_HOME="$_tmp/config" /bin/sh "$HELPER")
  else
    _out=$(env -i XDG_CONFIG_HOME="$_tmp/config" LQ_MCP_TOKEN="$2" /bin/sh "$HELPER")
  fi
  rm -rf "$_tmp"
  printf '%s' "$_out"
}

check() {  # <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    echo "  PASS  $1"
  else
    echo "  FAIL  $1"
    echo "        expected: $2"
    echo "        actual:   $3"
    fail=1
  fi
}

echo "test-auth-header.sh"

got=$(run __NONE__ __UNSET__)
check "(a) no token.json, no LQ_MCP_TOKEN -> {}" '{}' "$got"

got=$(run "$J_FUTURE" __UNSET__)
check "(b) FUTURE expires_at -> Bearer cookie" "$BEARER_COOKIE" "$got"

# Cases (c) and (g) assert the guardrail FIRES on a past date, which requires the
# helper's date parsing (`date -j -f` BSD / `date -d` GNU) to work on this host. On a
# platform where neither parses, the helper deliberately fails OPEN (keeps the cookie)
# and these two cases go RED — that is the correct signal that the guardrail is
# inoperative there, not a test defect.
got=$(run "$J_PAST" __UNSET__)
check "(c) PAST expires_at -> {} (the guardrail)" '{}' "$got"

got=$(run "$J_BAD" __UNSET__)
check "(d1) malformed expires_at -> Bearer cookie (fail-open)" "$BEARER_COOKIE" "$got"

got=$(run "$J_NOEXP" __UNSET__)
check "(d2) absent expires_at -> Bearer cookie (fail-open)" "$BEARER_COOKIE" "$got"

got=$(run __NONE__ "$GUEST")
check "(e) no cookie + LQ_MCP_TOKEN -> Bearer guest (backdoor intact)" "$BEARER_GUEST" "$got"

got=$(run "$J_FUTURE" "$GUEST")
check "(f) valid cookie + LQ_MCP_TOKEN -> cookie wins (order preserved)" "$BEARER_COOKIE" "$got"

got=$(run "$J_PAST" "$GUEST")
check "(g) EXPIRED cookie + LQ_MCP_TOKEN -> falls through to guest" "$BEARER_GUEST" "$got"

if [ "$fail" -eq 0 ]; then echo "test-auth-header.sh: ALL PASS"; exit 0; fi
echo "test-auth-header.sh: FAILURES"; exit 1
