#!/bin/sh
# Live smoke test for the lq-mcp OAuth 2.1 surface the native-OAuth sign-in depends
# on. REQUIRES NETWORK. Asserts the four links of the discovery chain that must stay
# healthy (these all passed at cutover; this guards against silent regression / a
# Vercel .well-known routing break like the original 404):
#   1. MCP endpoint, no creds      -> 401 + WWW-Authenticate (RFC 6750 / 9728 challenge)
#   2. Protected Resource Metadata -> JSON advertising authorization_servers (RFC 9728)
#   3. Authorization Server Metadata -> PKCE S256 + authorization_code (RFC 8414)
#   4. JWKS                         -> at least one signing key
#
# Exit 0 only if all four pass. (No member token is used or needed — this probes the
# unauthenticated discovery surface only.)

set -u
MCP="https://mcp.legalquants.com/api/mcp/mcp"
PRM="https://mcp.legalquants.com/.well-known/oauth-protected-resource/api/mcp/mcp"
AS="https://www.legalquants.com/.well-known/oauth-authorization-server"
JWKS="https://mcp.legalquants.com/.well-known/jwks.json"
fail=0
ok(){ echo "  PASS  $1"; }
no(){ echo "  FAIL  $1"; fail=1; }

command -v curl >/dev/null 2>&1 || { echo "FATAL: curl not found"; exit 2; }
echo "oauth-smoke.sh (requires network)"

# Reachability precheck — SKIP (exit 0) on a transport/connectivity failure so this
# external-dependency smoke test never reports a *regression* when the network or the
# host is simply down. Without -f, curl exits 0 for ANY HTTP response (even 4xx/5xx),
# and non-zero ONLY on a transport error (DNS/connect/timeout/TLS). So `! curl` here
# means "couldn't reach the host" -> skip; a reachable-but-wrong response still exits
# 0 and falls through to the real assertions below (which is where a true regression
# is caught). Do NOT add -f: it would turn a server-side regression into a skip.
if ! curl -sS -m 25 -o /dev/null "$JWKS" 2>/dev/null; then
  echo "  SKIP  lq-mcp host unreachable (network/transport failure) — not a regression"
  echo "oauth-smoke.sh: SKIPPED (offline)"
  exit 0
fi

# 1. 401 + WWW-Authenticate challenge
hdrs=$(curl -sS -m 25 -o /dev/null -D - -X POST "$MCP" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}' 2>/dev/null)
status=$(printf '%s' "$hdrs" | sed -n 's,^HTTP/[0-9.]* \([0-9][0-9][0-9]\).*,\1,p' | tail -1)
if [ "$status" = "401" ] && printf '%s' "$hdrs" | grep -qi '^www-authenticate:.*resource_metadata'; then
  ok "1. MCP no-auth -> 401 + WWW-Authenticate(resource_metadata)"
else
  no "1. MCP no-auth challenge (status=$status)"
fi

# 2. Protected Resource Metadata
prm=$(curl -sS -m 25 "$PRM" 2>/dev/null)
if printf '%s' "$prm" | grep -q '"authorization_servers"' && printf '%s' "$prm" | grep -q 'legalquants\.com'; then
  ok "2. Protected Resource Metadata advertises authorization_servers"
else
  no "2. Protected Resource Metadata (authorization_servers)"
fi

# 3. Authorization Server Metadata
as=$(curl -sS -m 25 "$AS" 2>/dev/null)
if printf '%s' "$as" | grep -q 'S256' && printf '%s' "$as" | grep -q 'authorization_code'; then
  ok "3. AS metadata: PKCE S256 + authorization_code"
else
  no "3. AS metadata (S256 / authorization_code)"
fi

# 4. JWKS
jwks=$(curl -sS -m 25 "$JWKS" 2>/dev/null)
if printf '%s' "$jwks" | grep -q '"keys"' && printf '%s' "$jwks" | grep -q '"kid"'; then
  ok "4. JWKS serves >=1 signing key"
else
  no "4. JWKS"
fi

if [ "$fail" -eq 0 ]; then echo "oauth-smoke.sh: ALL PASS"; exit 0; fi
echo "oauth-smoke.sh: FAILURES"; exit 1
