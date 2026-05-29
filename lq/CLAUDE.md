<!--
CONFIGURATION LOCATION

User-specific profile lives at a version-independent path that survives plugin updates:

  ~/.claude/plugins/config/legalquants/lq/CLAUDE.md

Convention for all skills, commands, and agents in this plugin:

1. READ user profile from that path (not this file — this is the TEMPLATE).
2. If the profile is missing OR contains [PLACEHOLDER] markers, the skills should
   PERSONALIZE the experience IF profile data is present, but never BLOCK on absence.
   Members can use the MCPs without a profile; the profile just enables "I know you"
   personalization (greeting, self-attribution queries, routing bias).
3. The /lq cold-start skill WRITES to that path, creating parent directories as needed.
4. On first run after a plugin update, if a populated profile exists at the old cache path
   (~/.claude/plugins/cache/legalquants/lq/<version>/CLAUDE.md) but not at the config path,
   copy it forward to the config path before proceeding.
5. This file (the one you are reading) is the plugin's GUIDANCE doc. It is auto-loaded into
   the model's context when the plugin is active. Never write user data here.

Difference vs legal-builder-hub's gating pattern:
- legal-builder-hub: skills REFUSE to do work without profile (recommendations are profile-driven)
- lq plugin: skills WORK FINE without profile (MCPs are auth-gated by token, not profile);
  profile just enables personalization
-->

# lq plugin

LegalQuants community access for Claude Code. v0.2 ships chat MCP + cold-start interview + identity layer + lq-assess workflow. v0.2.5 adds the Firebase device-code sign-in flow (`/lq --signin`) + session-cookie caching + a SessionStart hook. Brain MCP (v0.3) per `plan/lq-plugin/PRD.md`; OAuth/device-code design in `plan/lq-oauth/PRD.md`.

## What this plugin gives the user

- **`/lq`** — cold-start interview (new in v0.2). Single entry point for member discovery. Three modes: known-active members get an "I know you" greeting derived from corpus activity (no questions). Known-quiet members get a brief 2-Q interview. Anonymous (guest) members get a full cold interview. Writes profile to `~/.claude/plugins/config/legalquants/lq/CLAUDE.md`. Flags: `--redo`, `--refresh-activity`, `--signin` (Firebase device-code sign-in), `--signout`.
- **`/lq:assess`** — assessment workflow for invited candidates (moved from `~/.claude/skills/` in v0.2).
- **`/lq:chat`** — deprecated shim that redirects to `/lq`. Stays alive through v0.3, removed in v0.4.
- **Auto-loaded model skill** (`lqchat-mcp`) — primes the model on tool composition and three idioms (recency bias, people-as-filter, anti-LQclaw quoting).
- **MCP server** — `lqchat-mcp` auto-registers via `.mcp.json`. URL: `https://lqchat-mcp.vercel.app/api/mcp`.

## User profile (v0.2)

Each member has a local profile at `~/.claude/plugins/config/legalquants/lq/CLAUDE.md`. Created on first `/lq` run, contains:

- **Identity** — builder-NNN, email, display name (from `/api/whoami` server lookup)
- **Activity** (derived from corpus for active members) — message counts per channel, joined date, top topics, shipped projects
- **Inferred preferences** — recency-vs-synthesis focus, channels of interest

Auto-loaded skills (this `lqchat-mcp`, future `lqbrain-mcp`) READ this profile for personalization. Members can edit any field manually; fields marked `[manual]` are preserved across `/lq --refresh-activity`.

## Auth (v0.2.5)

Two paths, both authenticate the same MCP via `Authorization: Bearer ${LQ_MCP_TOKEN}`:

### Member path — Firebase device-code sign-in

- The member runs `/lq --signin` (or sign-in triggers automatically on first `/lq` when no cached cookie and no shared bearer). The skill:
  1. `POST https://www.legalquants.com/api/device/code` → gets a `user_code` + `verification_uri`.
  2. Tells the member to visit `https://www.legalquants.com/device`, enter the code, and sign in with the Google account on their LegalQuants profile.
  3. Polls `POST https://www.legalquants.com/api/device/token` every ~5s until the website finalizes sign-in.
- On the website, finalize verifies the Google ID token, requires the member's Firestore profile to be `status === "published"`, sets Firebase **custom claims** (`lqBuilder` from the profile's `builderId`, `lqGreeting` from the first name), and mints a Firebase **session cookie** (7-day expiry) via `createSessionCookie()`.
- The skill caches that session-cookie string at `~/.config/lq/token.json` (mode 0600) as `{ access_token, expires_at }`.
- A **SessionStart hook** (`hooks/lq-session-start.mjs`) reads that file at the start of each session and, if the cookie is valid, exports it as `LQ_MCP_TOKEN` so the MCP authenticates as the member.
- `mcp-vercel` verifies the cookie KEYLESSLY (as an RS256 JWT against Google's public session-cookie certs — no service-account key) and `/api/whoami` returns `{ builder: lqBuilder, email, display_greeting: lqGreeting, anonymous: false, authenticated_via: "firebase" }`.
- A member whose published profile has no `builderId` (after backfill) is authenticated but `lqBuilder: null` → corpus-derive-only, no self-attribution (still "signed in").
- `/lq --signout` deletes `~/.config/lq/token.json` and reverts to the guest path (or unauthenticated if no shared bearer is set).

### Guest path — shared bearer (unchanged)

- The legacy shared `LQ_MCP_TOKEN` env var still works for guests. `/api/whoami` returns `{ anonymous: true }` for it, so guests get Mode C (anonymous, full cold interview). This is the fallback whenever no member cookie is cached.

Both pass auth on MCP requests. Only the signed-in member path gets the personalized "I know you" greeting.

### Identity chain (resolved once, server-side)

`email -(Firestore profile)-> real_name -(roster.json)-> builder`. The `roster.json` (name→builder) lives ONLY in lqchat (gitignored) and is consumed ONCE by a backfill that writes `builderId` onto Firestore profiles. After backfill, neither the website finalize nor mcp-vercel needs `roster.json` at runtime — identity comes from the profile / custom claim. There is no client-side `token_registry.json`.

## What this plugin does NOT do

- No write operations (read-only MCP)
- No real-time chat ingest
- No operator commands (lq:deploy, lq:digest, lq:weekly, lq:issue-token etc. stay in operator's `~/.claude/skills/`, never bundled here)
- No brain MCP yet — Phase 3 (v0.3)

## Files

```
.claude-plugin/plugin.json     name, version, description, author
.mcp.json                      lqchat-mcp HTTP server registration (Bearer ${LQ_MCP_TOKEN})
hooks/hooks.json               SessionStart hook registration
hooks/lq-session-start.mjs     loads cached member cookie → LQ_MCP_TOKEN for the session
README.md                      member-facing install + usage
skills/lq/SKILL.md             /lq cold-start interview + device-code sign-in (user-invoked)
skills/chat/SKILL.md           DEPRECATED — shim redirecting /lq:chat → /lq (removed in v0.4)
skills/lq-assess/SKILL.md      /lq:assess workflow (moved from personal skills in v0.2)
skills/lqchat-mcp/SKILL.md     model-guidance (auto-invoked when chat MCP tools present)
```

## Privacy boundaries

What stays server-side, never exposed to clients:
- `roster.json` (real_name ↔ builder, full mapping) — operator-local, lqchat-gitignored. Consumed ONCE by the backfill that writes `builderId` onto Firestore profiles; not read at runtime by finalize or mcp-vercel.
- Firebase profiles + the session-cookie signing key (Admin SDK on the website) — never crosses the wire.
- Any other member's identity (the `/api/whoami` endpoint returns ONLY the requester's own identity, decoded from their own session cookie, never anyone else's).

What's returned to the authenticated requester:
- Their own builder-NNN (from the `lqBuilder` custom claim; `null` ⇒ corpus-derive-only)
- Their own email (already known to them)
- A first-name greeting (`lqGreeting` custom claim — no last names crossed wire)

The cached session cookie at `~/.config/lq/token.json` (mode 0600) is THEIR credential on THEIR machine — an opaque Firebase cookie, verified server-side, never decoded by the client. The local profile at `~/.claude/plugins/config/legalquants/lq/CLAUDE.md` is THEIR data on THEIR machine; the server never reads it.
