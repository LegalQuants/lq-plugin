#!/usr/bin/env node
// lq plugin — headersHelper for the lq-mcp HTTP connector.
//
// Purpose: print the Authorization header for the lq-mcp server, resolved FRESH
// on every connection. Claude Code runs the command in `.mcp.json`'s
// `headersHelper` field and expects ONLY a JSON object of header name→value on
// stdout (10-second timeout; ${CLAUDE_PLUGIN_ROOT} expanded to the plugin dir).
//
// Token resolution order:
//   1. The cached Firebase session cookie at ~/.config/lq/token.json
//      (written by `/lq --signin`), if present, non-empty, and not expired.
//      This authenticates as the signed-in member.
//   2. Else the LQ_MCP_TOKEN env var (the shared guest bearer fallback), if set.
//   3. Else no auth at all → print `{}`. The server 401s and the skill's
//      pre-flight routes the user to sign in.
//
// HARD CONTRACT: print ONLY valid JSON to stdout in every path; never log to
// stdout (stderr or silence only); never throw; never print the token anywhere
// but the stdout JSON; exit 0 always.

import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

function tokenPath() {
  // Honor XDG_CONFIG_HOME if set, else ~/.config (matches where /lq --signin caches the cookie).
  const base = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
  return join(base, "lq", "token.json");
}

// Read the cached cookie if the file exists, the cookie is non-empty, and the
// locally-recorded expires_at (if any) is in the future. The cookie is opaque;
// the MCP server re-verifies it server-side regardless.
function readValidCookie(path) {
  if (!existsSync(path)) return null;
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    return null; // malformed file — ignore, fall back to guest bearer
  }
  const cookie = parsed && typeof parsed.access_token === "string" ? parsed.access_token.trim() : "";
  if (!cookie) return null;
  if (parsed.expires_at) {
    const exp = Date.parse(parsed.expires_at);
    if (!Number.isNaN(exp) && exp <= Date.now()) return null; // expired
  }
  return cookie;
}

function resolveToken() {
  const cookie = readValidCookie(tokenPath());
  if (cookie) return cookie; // member cookie wins

  const envToken = typeof process.env.LQ_MCP_TOKEN === "string" ? process.env.LQ_MCP_TOKEN.trim() : "";
  if (envToken) return envToken; // shared guest bearer fallback

  return null;
}

try {
  const token = resolveToken();
  const headers = token ? { Authorization: `Bearer ${token}` } : {};
  process.stdout.write(JSON.stringify(headers));
} catch {
  // Never throw; emit empty headers (no auth) on any failure.
  try {
    process.stdout.write("{}");
  } catch {
    // stdout write itself failed — nothing more we can safely do.
  }
}
process.exit(0);
