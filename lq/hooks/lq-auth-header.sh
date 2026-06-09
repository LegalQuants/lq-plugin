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
# re-verifies it, so the server remains the source of truth. The cookie is
# emitted only if present, non-empty, AND not past its `expires_at` (fail-open
# if `expires_at` is missing/unparseable — keep emitting). An expired cookie is
# dropped so the helper emits {} / falls through to guest -> 401 -> Claude Code
# native OAuth, instead of looping on a dead cookie.
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
  raw=$(tr -d '\r\n' < "$tf" 2>/dev/null)
  tok=$(printf '%s' "$raw" | sed -n 's/.*"access_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  # Expiry-awareness: drop an EXPIRED cookie so the helper falls through to
  # guest/{} -> 401 -> native OAuth, instead of looping on a dead cookie.
  # Fail OPEN: a missing/unparseable expires_at leaves tok intact (the server
  # re-verifies and remains the source of truth).
  exp=$(printf '%s' "$raw" | sed -n 's/.*"expires_at"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  if [ -n "$tok" ] && [ -n "$exp" ]; then
    # BSD date (macOS) first, then GNU date (Linux); errors -> empty epoch.
    # TZ=UTC so the trailing Z is honored as UTC (BSD `-j -f` treats Z as a
    # literal and would otherwise parse in local time → off by the local offset).
    exp_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$exp" +%s 2>/dev/null)
    if [ -z "$exp_epoch" ]; then
      exp_epoch=$(TZ=UTC date -d "$exp" +%s 2>/dev/null)
    fi
    # Only act on a valid epoch (all-digits). Unparseable -> fail open.
    case "$exp_epoch" in
      ''|*[!0-9]*) : ;;  # missing/unparseable: keep emitting the cookie
      *)
        if [ "$exp_epoch" -le "$(date +%s)" ]; then
          tok=""  # expired: drop the cookie, fall through to guest/{}
        fi
        ;;
    esac
  fi
fi

if [ -z "$tok" ] && [ -n "${LQ_MCP_TOKEN:-}" ]; then
  tok="$LQ_MCP_TOKEN"
fi

if [ -n "$tok" ]; then
  printf '{"Authorization":"Bearer %s"}' "$tok"
else
  printf '{}'
fi
