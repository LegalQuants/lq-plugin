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

LegalQuants community access for Claude Code. Ships one unified read-only MCP server — `lq-mcp` — that serves BOTH corpora (the primary-source chat archive AND the synthesis vault), plus the `/lq:start` cold-start interview, `/lq:ask` cross-source synthesis, and `/lq:assess`. Members sign in via the connector's **Authenticate (native OAuth sign-in)** — the only in-plugin sign-in path — which mints an access token plus a 30-day refresh token that Claude Code persists and silently refreshes (exactly like the Vercel/Slack connectors). There is no longer a `headersHelper`; the legacy Firebase device-code flow and the in-plugin guest-bearer path were retired in v0.7.0 (they existed only to feed the helper, which suppressed native-OAuth refresh-token persistence — the cause of daily re-auth). Design: `plan/lq-plugin/PRD.md`, `plan/lq-consolidation/PRD.md`, `plan/lq-oauth/PRD.md`, `plan/lq-oauth-refresh-fix/`.

## What this plugin gives the user

- **`/lq:start`** — cold-start interview (bare `/lq` is a kept alias that runs the same thing). Single entry point for member discovery. Three modes: known-active members get an "I know you" greeting derived from corpus activity (no questions). Known-quiet members get a brief 2-Q interview. Anonymous (guest) members get a full cold interview. Writes profile to `~/.claude/plugins/config/legalquants/lq/CLAUDE.md`. Flags: `--redo`, `--refresh-activity`, `--signin` (re-trigger the connector's native Authenticate — e.g. to switch Google accounts), `--signout`.
- **`/lq:assess`** — assessment workflow for invited candidates (moved from `~/.claude/skills/` in v0.2).
- **`/lq:ask "<question>"`** — cross-source synthesis. Orchestrator: fans out to chat + brain explorer subagents in parallel, then merges into one cited answer. Power-user surface; the auto-loaded skill handles routine queries without it. (Replaced the removed `/lq:chat` shim.)
- **`/lq:update`** — profile updater for the member's **classic** `Lawyer` profile (rendered at `legalquants.com/lawyers/{slug}`). Reads what the member tells Claude — a new project, a media mention, a sharper bio/philosophy — optionally enriched by their own community footprint (`whoami` → `members/builder-NNN.md` → author-grep of their chat), diffs against the member's **LIVE** profile via the read-only **`get_my_profile`** tool (so it never re-adds press/projects already published), drafts structured **`FieldChange`s** (`path`/`op`/`before`/`after` + required evidence) that fit the website schema, shows the member the exact set, then submits **ONE pending proposal** via the `submit_profile_proposal` MCP tool. The website stores it as a PENDING proposal the member reviews and publishes at **`/profile/updates`**; only the member's in-browser approval makes a change live. **Propose-only**: the token can at most create a pending proposal — it never writes the live profile directly and never touches the corpus. Flag: `--member <builder-NNN>` (operator, draft-only — no submit).
- **`/lq:share`** — share a field-learning with the community. Composes a short first-person field note (title + finding + optional tag) from the current session, shows the member the EXACT message that will post to the members-only **#lq-share** WhatsApp channel, waits for ONE explicit confirmation, then queues it via the `submit_learning` MCP tool. LQClaw relays it verbatim within minutes — there are no take-backs, so the confirm before send is the only gate. Members only (the server rejects guest submits).
- **Auto-loaded guidance skill** (`lq-mcp`) — primes the model on each corpus's idioms and on how results span both sources (labelled by source; you don't pick a corpus up front).
- **MCP server** — `lq-mcp` (`https://lq-mcp.vercel.app/api/mcp/mcp`) auto-registers via `.mcp.json`; the member's native-OAuth token covers it. The tools take `source: chat | brain | all` (default all), so a plain query spans both corpora and results are labelled by source.

## User profile (v0.2)

Each member has a local profile at `~/.claude/plugins/config/legalquants/lq/CLAUDE.md`. Created on first `/lq:start` run, contains:

- **Identity** — builder-NNN, email, display name (from `/api/whoami` server lookup)
- **Activity** (derived from corpus for active members) — message counts per channel, joined date, top topics, shipped projects
- **Inferred preferences** — recency-vs-synthesis focus, channels of interest

The auto-loaded `lq-mcp` skill READS this profile for personalization. Members can edit any field manually; fields marked `[manual]` are preserved across `/lq:start --refresh-activity`.

## Auth (v0.7.0)

One path reaches the MCP for members: the connector's **native OAuth access token**. The server also still accepts a shared **guest bearer** server-side, but the plugin no longer injects one (see "Guest / ops escape hatch").

### Member path — native OAuth (the only in-plugin sign-in)

The connector's **Authenticate** signs the member in (Google account on their **published** profile) and mints an access token (1h) + a 30-day rotating refresh token that Claude Code persists and refreshes silently. The MCP verifies the access token keylessly against the AS's JWKS and requires the `lqMember` claim (set only after the published-profile check). `whoami` returns the member's own `builder`/`email`/greeting; a published profile with no `builderId` is authenticated but corpus-derive-only. `/lq:start --signin` re-triggers Authenticate; `--signout` clears the stored credential.

### Why the headersHelper is gone (v0.7.0)

Earlier versions declared a `headersHelper` to inject the legacy device-code cookie / guest bearer per connection. That declaration made Claude Code source auth from the helper and **not persist** the native-OAuth refresh token — so members re-authenticated daily. Removing it makes lq-mcp a pure native-OAuth connector (like Vercel/Slack) whose refresh token persists. The device-code flow and the in-plugin guest path went with it. See `plan/lq-oauth-refresh-fix/`.

### Guest / ops escape hatch (not shipped in the plugin)

The lq-mcp **server** still accepts the shared guest bearer (`isGuestToken`). For an anonymous/ops read-only session, configure the connector manually OUTSIDE the plugin, e.g.:

```bash
claude mcp add --transport http lq-mcp-guest https://lq-mcp.vercel.app/api/mcp/mcp \
  --header "Authorization: Bearer $LQ_MCP_TOKEN"
```

This is intentionally not in the plugin: shipping a `headersHelper`/static header is what broke native-OAuth refresh persistence for everyone.

### Identity chain (resolved once, server-side)

`email -(Firestore profile)-> real_name -(roster.json)-> builder`. The `roster.json` (name→builder) lives ONLY in lqchat (gitignored) and is consumed ONCE by a backfill that writes `builderId` onto Firestore profiles. After backfill, neither the website finalize nor the lq-mcp server needs `roster.json` at runtime — identity comes from the profile / custom claim. There is no client-side `token_registry.json`.

## What this plugin does NOT do

- No write operations to the corpus (the MCP is read-only). `/lq:update` is the one **propose-only** exception: via `submit_profile_proposal` it can create a PENDING classic-profile proposal the member must review and publish on legalquants.com — it never mutates the corpus and never writes the live profile directly (the website review/publish is the only place a change goes live).
- No real-time ingest — the chat is a sanitized snapshot; the brain vault is rebuilt periodically by operators (`/lq:lqbrain-draft`), not live
- No operator commands (lq:deploy, lq:digest, lq:weekly, lq:issue-token etc. stay in operator's `~/.claude/skills/`, never bundled here)

## Files

```
.claude-plugin/plugin.json     name, version, description, author
.mcp.json                      lq-mcp HTTP server registration (pure native OAuth — no headersHelper)
README.md                      member-facing install + usage
skills/start/SKILL.md          /lq:start cold-start interview + native OAuth sign-in (user-invoked)
skills/lq/SKILL.md             bare /lq alias → runs skills/start/SKILL.md
skills/ask/SKILL.md            /lq:ask cross-source synthesis orchestrator (chat + brain fan-out)
skills/assess/SKILL.md         /lq:assess workflow (invited candidates)
skills/update/SKILL.md         /lq:update classic-profile updater — drafts FieldChanges + submits ONE pending proposal via submit_profile_proposal (--member = operator draft-only)
skills/share/SKILL.md          /lq:share — compose a learning, confirm the exact post, queue via submit_learning (LQClaw relays to #lq-share)
skills/update/reference/classic-profile-schema.md   the classic Lawyer FieldChange contract the skill drafts to (allowlist, op semantics, evidence)
skills/update/reference/beta-profile-schema.md      LEGACY — unused by SKILL.md; artifact of the prior local-HTML draft flow (retained, not shipped-active)
skills/update/template{,-redline}.html              LEGACY — unused by SKILL.md; the old local-HTML renderer (retained, not shipped-active)
skills/lq-mcp/SKILL.md         model-guidance (auto-invoked when lq-mcp tools present)
```

## Privacy boundaries

What stays server-side, never exposed to clients:
- `roster.json` (real_name ↔ builder, full mapping) — operator-local, lqchat-gitignored. Consumed ONCE by the backfill that writes `builderId` onto Firestore profiles; not read at runtime by finalize or the lq-mcp server.
- Firebase profiles + the OAuth signing key (Admin SDK / AS on the website) — never crosses the wire.
- Any other member's identity (the `whoami` tool / `/api/whoami` endpoint returns ONLY the requester's own identity, decoded from their own native-OAuth access token, never anyone else's).

What's returned to the authenticated requester:
- Their own builder-NNN (from the `lqBuilder` custom claim; `null` ⇒ corpus-derive-only)
- Their own email (already known to them)
- A first-name greeting (`lqGreeting` custom claim — no last names crossed wire)

The native-OAuth access + refresh tokens are THEIR credential on THEIR machine — Claude Code stores them in the macOS Keychain (`Claude Code-credentials` → `mcpOAuth`), verified server-side, never decoded by the plugin (the plugin writes no token files). The local profile at `~/.claude/plugins/config/legalquants/lq/CLAUDE.md` is THEIR data on THEIR machine; the server never reads it.
