<!--
CONFIGURATION LOCATION

User-specific profile lives at a version-independent path that survives plugin updates:

  ~/.claude/plugins/config/legalquants/lq/CLAUDE.md

Convention for all skills, commands, and agents in this plugin:

1. READ user profile from that path (not this file — this is the TEMPLATE).
2. If the profile is missing OR contains [PLACEHOLDER] markers, the skills should
   PERSONALIZE the experience IF profile data is present, but never BLOCK on absence.
   Members can use the MCP without a profile; the profile just enables "I know you"
   personalization (greeting, self-attribution queries, source-weighting bias).
3. The /lq:start cold-start skill WRITES to that path, creating parent directories as needed.
4. On first run after a plugin update, if a populated profile exists at the old cache path
   (~/.claude/plugins/cache/legalquants/lq/<version>/CLAUDE.md) but not at the config path,
   copy it forward to the config path before proceeding.
5. This file (the one you are reading) is the plugin's GUIDANCE doc. It is auto-loaded into
   the model's context when the plugin is active. Never write user data here.

Difference vs legal-builder-hub's gating pattern:
- legal-builder-hub: skills REFUSE to do work without profile (recommendations are profile-driven)
- lq plugin: skills WORK FINE without profile (the MCP is auth-gated by token, not profile);
  profile just enables personalization
-->

# lq plugin

LegalQuants community access for Claude Code. Ships one unified read-only MCP server — `lq-mcp` — that serves BOTH corpora (the primary-source chat archive AND the synthesis vault), plus the `/lq:start` cold-start interview, `/lq:ask` cross-source synthesis, and `/lq:assess`. Members sign in via the connector's **Authenticate (native OAuth sign-in)** — the primary path — which mints an access token the connector supplies automatically. The Firebase **device-code** flow (`/lq:start --signin`) + session-cookie caching is the **legacy fallback**; in that path the connector authenticates via a `headersHelper` that reads the cached cookie on each connection (v0.2.5). Design: `plan/lq-plugin/PRD.md`, `plan/lq-consolidation/PRD.md`, `plan/lq-oauth/PRD.md`.

## What this plugin gives the user

- **`/lq:start`** — cold-start interview (bare `/lq` is a kept alias that runs the same thing). Single entry point for member discovery. Three modes: known-active members get an "I know you" greeting derived from corpus activity (no questions). Known-quiet members get a brief 2-Q interview. Anonymous (guest) members get a full cold interview. Writes profile to `~/.claude/plugins/config/legalquants/lq/CLAUDE.md`. Flags: `--redo`, `--refresh-activity`, `--signin` (legacy device-code fallback sign-in; the primary sign-in is the connector's Authenticate native OAuth prompt), `--signout`.
- **`/lq:assess`** — assessment workflow for invited candidates (moved from `~/.claude/skills/` in v0.2).
- **`/lq:ask "<question>"`** — cross-source synthesis. Orchestrator: fans out to chat + brain explorer subagents in parallel, then merges into one cited answer. Power-user surface; the auto-loaded skill handles routine queries without it. (Replaced the removed `/lq:chat` shim.)
- **`/lq:update`** — profile updater for the member's **classic** `Lawyer` profile (rendered at `legalquants.com/lawyers/{slug}`). Reads what the member tells Claude — a new project, a media mention, a sharper bio/philosophy — optionally enriched by their own community footprint (`whoami` → `members/builder-NNN.md` → author-grep of their chat), diffs against the member's **LIVE** profile via the read-only **`get_my_profile`** tool (so it never re-adds press/projects already published), drafts structured **`FieldChange`s** (`path`/`op`/`before`/`after` + required evidence) that fit the website schema, shows the member the exact set, then submits **ONE pending proposal** via the `submit_profile_proposal` MCP tool. The website stores it as a PENDING proposal the member reviews and publishes at **`/profile/updates`**; only the member's in-browser approval makes a change live. **Propose-only**: the token can at most create a pending proposal — it never writes the live profile directly and never touches the corpus. Flag: `--member <builder-NNN>` (operator, draft-only — no submit).
- **Auto-loaded guidance skill** (`lq-mcp`) — primes the model on each corpus's idioms and on how results span both sources (labelled by source; you don't pick a corpus up front).
- **MCP server** — `lq-mcp` (`https://lq-mcp.vercel.app/api/mcp/mcp`) auto-registers via `.mcp.json`; one member cookie covers it. The tools take `source: chat | brain | all` (default all), so a plain query spans both corpora and results are labelled by source.

## User profile (v0.2)

Each member has a local profile at `~/.claude/plugins/config/legalquants/lq/CLAUDE.md`. Created on first `/lq:start` run, contains:

- **Identity** — builder-NNN, email, display name (from `/api/whoami` server lookup)
- **Activity** (derived from corpus for active members) — message counts per channel, joined date, top topics, shipped projects
- **Inferred preferences** — recency-vs-synthesis focus, channels of interest

The auto-loaded `lq-mcp` skill READS this profile for personalization. Members can edit any field manually; fields marked `[manual]` are preserved across `/lq:start --refresh-activity`.

## Auth (v0.6.0)

There are three ways auth reaches the MCP, in order of precedence: the connector's native OAuth access token (primary), the cached Firebase session cookie from the legacy device-code fallback, and the shared guest bearer. The `headersHelper` covers the latter two; native OAuth is handled by the connector itself.

### Member path — the connector's Authenticate (native OAuth sign-in) — PRIMARY

- The member runs the connector's **Authenticate (native OAuth sign-in)** — there is no code to copy and no token to paste. The connector opens the LegalQuants sign-in in the browser; the member signs in with the Google account on their **published** LegalQuants profile.
- Sign-in mints a short-lived **access token** that the connector supplies automatically on each request (the connector manages refresh) — the member does not handle or cache it.
- The MCP verifies that access token **keylessly** (against Google's public certs — no service-account key) and requires the `lqMember` claim, which sign-in sets only after the published-profile check. `/api/whoami` then returns the member's own `builder`, `email`, and first-name greeting (`anonymous: false`).
- A member whose published profile has no `builderId` (after backfill) is authenticated but `lqBuilder: null` → corpus-derive-only, no self-attribution (still "signed in").

### Member path — Firebase device-code sign-in (legacy fallback)

This is the legacy device-code fallback, retained and working for environments where the connector's native Authenticate is unavailable. It relies on the `headersHelper`:

`.mcp.json` declares a **`headersHelper`** — `/bin/sh ${CLAUDE_PLUGIN_ROOT}/hooks/lq-auth-header.sh` (pure POSIX sh, invoked via `/bin/sh` so it needs no `node`/PATH — Claude Code spawns the helper with **no `PATH`**, so an unqualified `node` would be "command not found") — that Claude Code runs on **each connection** and whose stdout JSON becomes the request headers. The helper resolves the bearer fresh per connection: cached member cookie first, then the shared guest bearer `$LQ_MCP_TOKEN`, else no auth.

- The member runs `/lq:start --signin` (the legacy device-code fallback; or it triggers automatically on first `/lq:start` when no cached cookie and no shared bearer). The skill:
  1. `POST https://www.legalquants.com/api/device/code` → gets a `user_code` + `verification_uri`.
  2. Tells the member to visit `https://www.legalquants.com/device`, enter the code, and sign in with the Google account on their LegalQuants profile.
  3. Polls `POST https://www.legalquants.com/api/device/token` every ~5s until the website finalizes sign-in.
- On the website, finalize verifies the Google ID token, requires the member's Firestore profile to be `status === "published"`, sets Firebase **custom claims** (`lqBuilder` from the profile's `builderId`, `lqGreeting` from the first name), and mints a Firebase **session cookie** (7-day expiry) via `createSessionCookie()`.
- The skill caches that session-cookie string at `~/.config/lq/token.json` (mode 0600) as `{ access_token, expires_at }`.
- The connector's **`headersHelper`** (`hooks/lq-auth-header.sh`) reads that file on each connection and, if the cookie is valid (present, non-empty, not expired), supplies `Authorization: Bearer <cookie>` so the MCP authenticates as the member. Because the header is resolved fresh per connection, a freshly cached cookie is picked up the next time the connector connects — on a fresh session start (and `/resume`), NOT mid-session and NOT on `/clear`.
- The `lq-mcp` server verifies the cookie KEYLESSLY (as an RS256 JWT against Google's public session-cookie certs — no service-account key) and `/api/whoami` returns `{ builder: lqBuilder, email, display_greeting: lqGreeting, anonymous: false, authenticated_via: "firebase" }`.
- `/lq:start --signout` deletes `~/.config/lq/token.json` and reverts to the guest path (or unauthenticated if no shared bearer is set).

### Guest path — shared bearer (unchanged)

- The legacy shared `LQ_MCP_TOKEN` env var still works for guests. `/api/whoami` returns `{ anonymous: true }` for it, so guests get Mode C (anonymous, full cold interview). This is the fallback whenever no member cookie is cached. A guest who wants to upgrade to a personalized member session should `/lq:start --signout` (or unset `LQ_MCP_TOKEN`) first, then use the connector's Authenticate (native OAuth sign-in).

All three pass auth on MCP requests. Only the signed-in member paths get the personalized "I know you" greeting.

### Identity chain (resolved once, server-side)

`email -(Firestore profile)-> real_name -(roster.json)-> builder`. The `roster.json` (name→builder) lives ONLY in lqchat (gitignored) and is consumed ONCE by a backfill that writes `builderId` onto Firestore profiles. After backfill, neither the website finalize nor the lq-mcp server needs `roster.json` at runtime — identity comes from the profile / custom claim. There is no client-side `token_registry.json`.

## What this plugin does NOT do

- No write operations to the corpus (the MCP is read-only). `/lq:update` is the one **propose-only** exception: via `submit_profile_proposal` it can create a PENDING classic-profile proposal the member must review and publish on legalquants.com — it never mutates the corpus and never writes the live profile directly (the website review/publish is the only place a change goes live).
- No real-time ingest — the chat is a sanitized snapshot; the brain vault is rebuilt periodically by operators (`/lq:lqbrain-draft`), not live
- No operator commands (lq:deploy, lq:digest, lq:weekly, lq:issue-token etc. stay in operator's `~/.claude/skills/`, never bundled here)

## Files

```
.claude-plugin/plugin.json     name, version, description, author
.mcp.json                      lq-mcp HTTP server registration (headersHelper → /bin/sh hooks/lq-auth-header.sh)
hooks/lq-auth-header.sh        headersHelper (POSIX sh, no node/PATH dep): reads cached cookie (~/.config/lq/token.json) → supplies the Authorization header per connection (guest fallback: $LQ_MCP_TOKEN)
README.md                      member-facing install + usage
skills/start/SKILL.md          /lq:start cold-start interview + device-code sign-in (user-invoked)
skills/lq/SKILL.md             bare /lq alias → runs skills/start/SKILL.md
skills/ask/SKILL.md            /lq:ask cross-source synthesis orchestrator (chat + brain fan-out)
skills/assess/SKILL.md         /lq:assess workflow (invited candidates)
skills/update/SKILL.md         /lq:update classic-profile updater — drafts FieldChanges + submits ONE pending proposal via submit_profile_proposal (--member = operator draft-only)
skills/update/reference/classic-profile-schema.md   the classic Lawyer FieldChange contract the skill drafts to (allowlist, op semantics, evidence)
skills/update/reference/beta-profile-schema.md      LEGACY — unused by SKILL.md; artifact of the prior local-HTML draft flow (retained, not shipped-active)
skills/update/template{,-redline}.html              LEGACY — unused by SKILL.md; the old local-HTML renderer (retained, not shipped-active)
skills/lq-mcp/SKILL.md         model-guidance (auto-invoked when lq-mcp tools present)
```

## Privacy boundaries

What stays server-side, never exposed to clients:
- `roster.json` (real_name ↔ builder, full mapping) — operator-local, lqchat-gitignored. Consumed ONCE by the backfill that writes `builderId` onto Firestore profiles; not read at runtime by finalize or the lq-mcp server.
- Firebase profiles + the session-cookie signing key (Admin SDK on the website) — never crosses the wire.
- Any other member's identity (the `/api/whoami` endpoint returns ONLY the requester's own identity, decoded from their own session cookie, never anyone else's).

What's returned to the authenticated requester:
- Their own builder-NNN (from the `lqBuilder` custom claim; `null` ⇒ corpus-derive-only)
- Their own email (already known to them)
- A first-name greeting (`lqGreeting` custom claim — no last names crossed wire)

The cached session cookie at `~/.config/lq/token.json` (mode 0600) is THEIR credential on THEIR machine — an opaque Firebase cookie, verified server-side, never decoded by the client. The local profile at `~/.claude/plugins/config/legalquants/lq/CLAUDE.md` is THEIR data on THEIR machine; the server never reads it.
