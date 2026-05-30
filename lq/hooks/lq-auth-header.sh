#!/bin/sh
# lq plugin — headersHelper for the lq-mcp HTTP connector.
#
# Prints the Authorization header for lq-mcp, resolved FRESH on every connection.
# Claude Code runs this via `.mcp.json`'s `headersHelper` and expects ONLY a JSON
# object of header name->value on stdout (10s timeout; ${CLAUDE_PLUGIN_ROOT} is
# expanded to the plugin dir before the command runs).
#
# WHY POSIX sh, not node: Claude Code spawns the headersHelper with a minimal
# environment (no PATH set -> OS default /usr/bin:/bin). That does NOT include
# Homebrew/nvm/volta node dirs, so an unqualified `node` is "command not found",
# the helper emits nothing, and CC falls back to OAuth discovery -> the server's
# Vercel 404 HTML -> "Invalid OAuth error response". /bin/sh and the coreutils
# below are always on the default PATH, so this helper has no PATH dependency.
#
# Token order: member cookie (~/.config/lq/token.json .access_token) -> the
# LQ_MCP_TOKEN guest bearer -> {} (no auth; the server 401s and the skill's
# pre-flight routes the user to /lq:start). The cookie is opaque and the server
# re-verifies it, so expiry is not checked here.
#
# HARD CONTRACT: print ONLY valid JSON to stdout in every path; never log to
# stdout; never print the token anywhere but the stdout JSON; exit 0 always.

# Ensure coreutils resolve even if CC passes an empty PATH.
export PATH="/usr/bin:/bin${PATH:+:$PATH}"

base="${XDG_CONFIG_HOME:-$HOME/.config}"
tf="$base/lq/token.json"

tok=""
if [ -r "$tf" ]; then
  # token.json is our own JSON ({"access_token":"<jwt>","expires_at":"..."}).
  # Strip newlines, then extract the access_token string value. The JWT is
  # base64url + dots — it contains no double-quote, so [^"]* is exact.
  tok=$(tr -d '\r\n' < "$tf" 2>/dev/null | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

if [ -z "$tok" ] && [ -n "${LQ_MCP_TOKEN:-}" ]; then
  tok="$LQ_MCP_TOKEN"
fi

if [ -n "$tok" ]; then
  printf '{"Authorization":"Bearer %s"}' "$tok"
else
  printf '{}'
fi
