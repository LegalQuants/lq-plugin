#!/usr/bin/env node
// lq plugin — SessionStart hook.
//
// Purpose: if the member has a cached Firebase session cookie at
// ~/.config/lq/token.json (written by `/lq --signin`), inject it as the
// LQ_MCP_TOKEN env var for this session so the lqchat-mcp server (which reads
// `Authorization: Bearer ${LQ_MCP_TOKEN}` from .mcp.json at spawn) authenticates
// as the member rather than the shared guest bearer.
//
// Mechanism (confirmed against Claude Code's official plugin hooks, e.g. vercel's
// session-start-profiler.mjs → compat.setSessionEnv): Claude Code exposes the path
// to a per-session env file in $CLAUDE_ENV_FILE. A SessionStart hook appends
// `export KEY="value"` lines to that file; Claude Code sources it into the session
// environment BEFORE spawning MCP servers. Appending `export LQ_MCP_TOKEN="<cookie>"`
// therefore overrides whatever the member set in their shell profile, for this
// session only, with the cached member cookie.
//
// Fail-safe: if no valid cookie, do nothing — the member's existing shared
// LQ_MCP_TOKEN (if any) stays in effect (guest path). Never throws; never blocks.
// Never prints the cookie value.

import { readFileSync, appendFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

function tokenPath() {
  // Honor XDG_CONFIG_HOME if set, else ~/.config (matches what /lq --signin writes).
  const base = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
  return join(base, "lq", "token.json");
}

// A Firebase session cookie is opaque; this hook does NOT decode or trust it.
// It only checks the locally-recorded expires_at so an obviously-expired cookie
// isn't injected. The MCP server re-verifies the cookie server-side regardless.
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

// Escape a value for safe inclusion inside double quotes in a sourced shell file.
function escapeShellEnvValue(value) {
  return String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/`/g, "\\`").replace(/\$/g, "\\$");
}

function main() {
  const envFile = process.env.CLAUDE_ENV_FILE;
  if (!envFile) return; // not running under Claude Code (or unsupported) — nothing to do

  const cookie = readValidCookie(tokenPath());
  if (!cookie) return; // no valid member cookie — leave guest bearer (if any) in place

  try {
    appendFileSync(envFile, `export LQ_MCP_TOKEN="${escapeShellEnvValue(cookie)}"\n`);
    // Surface a one-line, non-sensitive note into model context (stdout becomes
    // additional context for SessionStart hooks). Do NOT print the cookie.
    process.stdout.write("LegalQuants: signed-in member session cookie loaded for the lqchat MCP. Run /lq for your greeting.\n");
  } catch {
    // Best-effort: if we can't write the env file, fall through silently to guest.
  }
}

try {
  main();
} catch {
  // Never let a hook failure break session start.
}
process.exit(0);
