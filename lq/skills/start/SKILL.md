---
name: start
description: |
  Cold-start interview AND returning-user greeting for the LegalQuants community knowledge plugin.
  Run when the user types /lq:start (bare /lq also works). First run: welcome + identity verification + practice profile + a sample
  query, writes profile to ~/.claude/plugins/config/legalquants/lq/CLAUDE.md. Subsequent runs:
  brief greeting + what's new + "just ask your question". Pure onboarding + personalization — never
  invoke proactively.
---

# /lq — community knowledge cold-start

This skill is the single discovery surface for the `lq` plugin. Members type `/lq` once for first-run onboarding (identity + practice profile + a sample query). Future invocations are lightweight: greeting + what's new. After onboarding, members ask natural-language questions; the single auto-loaded `lq-mcp` guidance skill handles tool use across both corpora (no routing decision) — personalized by the profile this skill writes.

## Cold-start check (run FIRST, before any user-facing output)

Read the user profile at `~/.claude/plugins/config/legalquants/lq/CLAUDE.md` (note: literal `~` expansion required).

**Branch on profile state:**

| Profile state | Path |
|---|---|
| File doesn't exist | → **First run** (mode determined by the `whoami` MCP tool + activity probe — see "First-run mode detection" below) |
| File exists with `[PLACEHOLDER]` markers | → **Resume**: greet, offer to complete missing sections or `--redo` from scratch |
| File exists, no placeholders, no pause comment | → **Returning user** (lightweight greeting only) |
| User passed `--redo` flag | → **First run** (overwrite profile after confirmation) |
| User passed `--refresh-activity` flag | → **Re-derive activity only** (keep identity + manual overrides, re-derive corpus-based fields) |
| User passed `--signin` flag | → **Re-authenticate**: tell the member to run the connector's **Authenticate** (native OAuth); then STOP with the fresh-session hand-off — do NOT continue into Mode A/B this session |
| User passed `--signout` flag | → **Sign out** (remove the lq-mcp credential via Claude Code's connector UI; see "Sign-out path" below), then stop |

**Migration check**: if no profile at the config path BUT a profile.md or CLAUDE.md exists at the plugin cache path (`~/.claude/plugins/cache/legalquants/lq/<version>/profile.md`), copy it forward to the config path before deciding which branch to take.

## First-run mode detection

On first run, identity + activity together determine which onboarding flow runs. Three modes:

| Mode | Detection | Onboarding flow |
|---|---|---|
| **Known active** | the `whoami` MCP tool resolves to a builder (authenticated member path — native OAuth) AND `grep(author: "builder-NNN", source: "chat", limit: 400)` returns ≥ 10 posts | **Derive everything from corpus**. Display "I know you" greeting. NO interview questions. ~5 tool calls, ~10 sec |
| **Known quiet** | the `whoami` MCP tool resolves to a builder (authenticated member path — native OAuth) BUT `grep(author: "builder-NNN", source: "chat", limit: 400)` returns < 10 posts | **Brief 2-question interview** (topics of interest + recency-vs-synthesis preference) — supplements the thin corpus signal |
| **Anonymous** | the `whoami` MCP tool returns `anonymous: true` (a manually-configured guest connector), OR a transient `whoami` error (5xx / unreachable — NOT a 401) | **Full cold interview** (role + practice area + focus + channels) — we have no corpus signal to derive from. (A 401 / no-credential is NOT this row → Sign-in path, see Step 3.) |

The threshold (N=10 messages) is configurable; tune via the constant `MIN_MESSAGES_FOR_DERIVATION` if the cold-start needs adjustment.

> **Count a member's posts with the `author` filter, never a body grep.** `grep(author: "builder-NNN", source: "chat", limit: 400)` matches the parsed message author. Grepping the prefix `\\] builder-NNN: ` as text returns **0** — the author lives in the line prefix, not the message body — which would mis-file every active member as "Known quiet" and suppress the "I know you" greeting. Always pass `limit: 400` (the cap), never the default `limit: 50` — the skill counts the returned results, so a default-capped call would undercount any member with 50+ posts (e.g. report 50 for a 60-post member).

**Path detection:**
- **Guest path:** a manually-configured guest connector → the `whoami` MCP tool returns `anonymous: true` → Mode C (the full cold interview). (Guests use a manually-configured connector; the plugin ships member sign-in only.)
- **Member path (native OAuth — the only in-plugin sign-in):** the member signs in via the connector's **Authenticate**; Claude Code holds the token and attaches it to every request — nothing is cached by the plugin. Step 3 resolves identity by calling the **`whoami` MCP tool** through the connector. A member whose published profile has no `builderId` is authenticated but corpus-derive-only ("member without builder").
- Identity always comes from the `whoami` MCP tool — never decode or trust any token locally.
- See [plan/lq-oauth/PRD.md](../../../../plan/lq-oauth/PRD.md) for the full OAuth design.

---

## First-run path (full interview + writes profile)

Execute steps 1-7 in order, **in a single response** (don't pause between welcome and patterns). Steps 6-7 (sample query + demo) are the SAME interactive flow that returning users skip.

### Step 1 — Welcome + capability stats

Emit as your own assistant text (not code, not bash). Substitute current corpus stats from a recent healthcheck if in context; otherwise use these defaults:

```
Welcome to the LegalQuants community knowledge plugin.

You're connected to:
  • lq-mcp — one connector spanning the community chat archive (verbatim, dated, attributable primary source) AND the curated synthesis vault (evergreen positions). Results come back labelled by source.
  • Assessment workflow — /lq:assess for invited candidates

This is a one-time setup. Future /lq runs are lightweight.
```

### Step 2 — How asking works (one connector, results labelled by source)

Emit one short paragraph as your own text:

> **One thing to know before you ask:** there's one `lq-mcp` connector, and it spans both corpora. The **chat archive** is the primary source (verbatim messages, dated, attributable). The **synthesis vault** is the synthesis layer (curated atomic notes, evergreen positions). A plain question spans both — you don't pick a corpus first. Results come back labelled by source, so you can see whether something is a dated message or a settled position. Just ask your question.

### Step 3 — Identity (via the whoami MCP tool)

Resolve identity by calling the **`whoami` MCP tool** (the lq-mcp connector tool). Branch on the result:

- `{ builder: "builder-NNN", email, display_greeting, anonymous: false }` → record `builder_id`, `email`, `display_name`; emit a one-line "You're <greeting> (builder-NNN · email)." and proceed to Mode A/B detection.
- `{ builder: null, email, display_greeting, anonymous: false }` → **member without builder** (published profile, no `builderId` linked). Emit: *"You're signed in as <greeting> (<email>), but your profile isn't linked to a community builder yet, so I'll derive context from the corpus rather than self-attribute. Ask the operator to link your builder for full personalization."* Record `builder_id: anonymous`, `email`, `display_name`; proceed (corpus-derive-only).
- `{ anonymous: true }` → you're on a manually-configured guest connector. Run **Mode C (anonymous)** and add ONE line at the top: *"You're on a guest connector (read-only, no personalization). To get the 'I know you' greeting, use the connector's **Authenticate** (native OAuth) and sign in with the Google account on your published LegalQuants profile."*
- **`whoami` tool absent / 401 / "unauthorized"** (connector not connected, or no valid credential): you're not signed in → go to the **Sign-in path** below, then STOP with the "start a fresh session and re-run `/lq:start`" hand-off — do NOT continue into corpus-derived Mode A/B this session.
- **`whoami` transient error** (5xx / network / unreachable, NOT an auth failure): identity is momentarily unresolvable but you may be signed in. Degrade gracefully → run **Mode C (anonymous)**, record `builder_id: anonymous`, and tell the member they can re-run `/lq:start` later to pick up their identity. Don't block setup and don't force a re-sign-in.

**If the displayed identity looks wrong** (user notices mismatch): they should re-run `/lq --signin` to re-authenticate with the correct Google account, or contact the operator if their Firestore profile is mis-mapped.

**Opt-out** (member doesn't want to be identified by the model in queries): the default is "identified" once signed in. Members who prefer anonymity can run `/lq --signout` (clears the stored credential) or edit their profile.md and set `builder_id` to `anonymous`. Documented in the profile file's footer.

---

#### Sign-in path — native OAuth (the only path)

Triggered by `/lq --signin`, or inline from Step 3 when `whoami` shows no identity. **Never run a free-text query here — identity only.**

Tell the member to run the connector's **Authenticate** action (Claude Code surfaces it for `lq-mcp`): browser → Google sign-in (the account on their **published** LegalQuants profile) → consent. The connector persists the credential automatically and keeps the member signed in; the plugin writes nothing to disk.

Then: **start a fresh Claude Code session and re-run `/lq:start`.** The connector attaches the OAuth token on the new session, and Step 3 resolves identity via the `whoami` MCP tool. (A mid-session Authenticate does not re-key the already-connected MCP — hence the fresh-session hand-off.)

If the member's profile isn't published, Authenticate fails the membership gate: tell them to publish at legalquants.com first, then Authenticate again.

### Step 4 — Build the profile (branches by mode)

Based on the mode detected in cold-start check:

---

#### Mode A: Known active (derive from corpus, no interview)

Run these tool calls **in parallel** (single response with multiple tool calls):

1. **Live published profile (authoritative)** — call **`get_my_profile`** → `{ ok, profileKey, profile }`. On `ok`, `profile` is the member's masked live `Lawyer` record (what's actually on `legalquants.com/lawyers/{slug}`): the scalars `bio`, `tagline`, `title`, `location`, `linkedin`, `substack`, `github`, `appsUrl`, plus the **current** `projects`, `media`, and `philosophy` arrays. This is the source of truth for the member's self-described identity and shipped work — prefer it over the corpus snapshot. On `ok:false`: `profile_not_published` / `not_authenticated` → fall back to the member file (`read("members/builder-NNN.md")`) for role/bio/ships and note the profile isn't published; if `profile` is absent, degrade to the member file too.
2. **Activity per channel** — `grep(author: "builder-NNN", source: "chat", limit: 400)` substituting the actual pseudo-ID (omit `query` — the `author` filter alone returns every post by that member, matched on the parsed author field). Count hits per channel from the results; sort desc. NEVER grep the author *prefix* `\\] builder-NNN: ` — the tool searches message bodies, not the author field, so a prefix search always returns 0. (`get_my_profile` carries no channel activity — this is still the only source for per-channel counts and "last seen".)
3. **Top topics** — sample the member's messages (use the grep output from #2, take a representative slice of ~30 messages). For each, extract content keywords. Cluster manually into top 3-5 topics.
4. **Shipped projects** — take from the live profile's `projects` array (name + one-line description). Only fall back to the member file's `## Ships` section if `get_my_profile` returned `ok:false`.
5. **Vault cross-references (enrichment, secondary)** — `grep("builder-NNN", source: "brain")` for projects others reference. The vault's curated people page (`read("people/<member-slug>.md", source: "brain")`) is now optional enrichment only — the live profile from #1 is the primary identity source, not this.

**Infer the focus orientation** (recency vs synthesis): scan the member's last ~20 messages. Are they majority-questions ("anyone tried...?", "what does X mean?") or majority-statements ("I built", "here's what I think")? Questions → recency-focused. Statements → synthesis-focused. Mixed → both.

**Compose the "I know you" greeting**. Example template:

```
Welcome back, <display_greeting> (<builder>)!

👤 **Your profile** — <title><, location> · <tagline>
   <one-line from bio>
   (from your live legalquants.com profile — omit this block if get_my_profile returned ok:false)

📊 **Activity** — <total> messages across <N> channels · joined <month year>
   • Most active: <ch1> (<n1>), <ch2> (<n2>), <ch3> (<n3>)
   • Last seen: <relative date>

🛠 **Shipped** (<count> projects)
   • <project 1 name> — <one-line description>
   • <project 2 name> — <one-line description>
   • <project 3 name> — <one-line description>

🎯 **Topics you engage with**
   • <topic 1> (<n mentions>)
   • <topic 2> (<n mentions>)
   • <topic 3> (<n mentions>)

You read as **<focus orientation>-focused** based on your discussion patterns.
I'll weight results toward recent chat vs settled vault accordingly — but you can always ask explicitly.

Just ask anything. Results come back labelled by source — chat (raw) and vault (synthesis).
```

Write everything to the profile file (Step 5). NO interview questions in this mode.

---

#### Mode B: Known quiet (brief 2-question interview to supplement thin signal)

First call **`get_my_profile`** (the member is authenticated, just corpus-quiet) — if `ok`, you have their live `legalquants.com` profile (`title`, `tagline`, `bio`, `projects`, `media`, `philosophy`) even though the chat signal is thin. Surface it in the "what we DO know" block and skip any interview question the profile already answers.

Show what we DO know first:

```
Welcome, <display_greeting> (<builder>)!

I see you in the registry but you've only posted <N> messages so far — not 
enough for me to derive your preferences from the corpus. Two quick questions 
to personalize, then you're set up.
```

Then ask via **AskUserQuestion**:

**Question 1 — Topics you care about (multiSelect):**
- **header**: "Topics"
- **multiSelect**: true
- **options**: "Local models / open-source AI", "Big-LLM tooling (Claude/Cursor/Cline)", "Agent harnesses", "Document automation", "Privacy/data security", "Legal-AI marketplaces", "All of the above"

**Question 2 — When you ask questions, you usually want:**
- **header**: "Focus"
- **multiSelect**: false
- **options**: "What's happening lately (recency)", "Settled positions (synthesis)", "Both equally"

Then proceed to Step 5 (write profile) with the answers + any thin corpus signal we have.

---

#### Mode C: Anonymous (full cold interview)

Emit:

```
Welcome to LegalQuants community knowledge.

You're on a guest connector — full read access to the community chat archive,
but it isn't linked to a specific community member, so I can't personalize.

→ To link your member identity: use the connector's **Authenticate** (native OAuth) 
  and sign in with the Google account on your published LegalQuants profile. You'll 
  get the "I know you" greeting on your next /lq run (activity, projects, topics — all 
  derived from your contributions). Your profile must be published first.

For now, a quick interview to personalize the experience anonymously.
```

Then ask via **AskUserQuestion** — four questions, asked in sequence:

**Question 1 — Role:**
- **header**: "Role"
- **options**: "In-house lawyer", "Private practice", "Non-lawyer (legal-adjacent)", "Other"

**Question 2 — Primary practice area (skip for Non-lawyer):**
- **header**: "Area"
- **options**: "Corporate/M&A", "Litigation/Dispute", "IP/Tech transactions", "Privacy/Data", "Mixed/Generalist"

**Question 3 — Typical question shape:**
- **header**: "Focus"
- **options**: "Recent discussions / what's happening now", "Settled positions / community wisdom", "Both equally"

**Question 4 — Channels of interest (multiSelect):**
- **header**: "Channels"
- **multiSelect**: true
- **options**: "General", "Local models", "Claude Code _ CLI tools", "LQClaw", "Industry News", "Claws and Hermes", "LQ AI", "All of them"

Then proceed to Step 5 with the answers.

### Step 5 — Write the profile

Call `Write` to `~/.claude/plugins/config/legalquants/lq/CLAUDE.md` (create parent dirs). Template adapts to mode — some fields derived from corpus (Mode A), some answered (Modes B/C). Always include the `derivation_source` and `last_derived_at` for transparency:

```markdown
# LQ Plugin Practice Profile

*Written by /lq cold-start on <YYYY-MM-DD>.*
*Mode: <active | quiet | anonymous>.*
*To redo: `/lq --redo`. To re-derive activity only: `/lq --refresh-activity`. To edit any field manually: open this file directly — manual edits are preserved on refresh.*

---

## Identity

**Builder ID:** <builder-NNN | anonymous>
**Display name:** <First-name | (anonymous)>
**Email:** <kevin.keller@example.com | (anonymous)>

*Source: the `whoami` MCP tool (resolves identity from the connector's OAuth token, server-side).*
*Used by: auto-loaded skills for self-attribution queries, exclude-self filters, personalized greetings.*

---

## Activity (derived from corpus — Mode A only)

*Last derived: <ISO timestamp>. To refresh: `/lq --refresh-activity`.*

**Total messages:** <N>
**Joined:** <month year> (first message timestamp)
**Most-active channels:** <ch1> (<n1>), <ch2> (<n2>), <ch3> (<n3>)
**Last active:** <ISO date>

**Top topics (sampled from last 30 messages):**
- <topic 1> (<n mentions>)
- <topic 2> (<n mentions>)
- <topic 3> (<n mentions>)

**Shipped projects (<count>):**
- <project 1> — <one-line>
- <project 2> — <one-line>

*Source: grep on the chat source + read on member file + the vault's people/projects.*
*Used by: greeting personalization, default channel filter, topic relevance weighting.*

---

## Practice (answered — Mode B/C; not present for Mode A unless manually added)

**Role:** <In-house lawyer | Private practice | Non-lawyer | Other>
**Practice area:** <Corporate/M&A | Litigation | IP/Tech | Privacy | Mixed | n/a>

*Source: cold-start interview (Mode B/C). Mode A members get role descriptor 
inferred from their member-file bio instead.*

---

## Query preferences

**Default focus:** <recency | synthesis | both>
**Channels of interest:** <comma-separated channel names, or "all">

*Source: inferred from message-shape ratio (Mode A) OR answered (Mode B/C).*
*Used by: source weighting — bias toward chat (recency) for recency-focused users,
toward the vault (synthesis) for synthesis-focused. Channel filter narrows default grep scope.*

---

## Notification preferences

(Not used in v0.2. Reserved for v0.4+ when /lq:digest-style notifications land.)

---

## Manual overrides

*If anything above is wrong, edit it directly. Field-level manual overrides 
are preserved across `/lq --refresh-activity` runs. Use `/lq --redo` to start 
from scratch (your existing answers backed up to `<this-file>.bak`).*

**Override marker:** any field followed by ` [manual]` is treated as user-set 
and NOT overwritten by activity refresh. Example:
```
**Default focus:** synthesis [manual]
```

---

*This file is your data on your machine. The LQ server never reads it.
Your identity comes from the `whoami` MCP tool, which the lq-mcp server resolves
from the connector's native-OAuth token (held by Claude Code, never by the plugin).
To unlink, run `/lq --signout`. Edit, delete, or rewrite this file any time.*
```

After writing, confirm: *"Profile written to `~/.claude/plugins/config/legalquants/lq/CLAUDE.md`. The auto-loaded skills will personalize queries based on this. To re-derive activity (e.g., after you've posted more), run `/lq --refresh-activity`. To redo from scratch, `/lq --redo`."*

### Step 6 — Sample query (one demo, then end)

Use **AskUserQuestion** with five options. Same as the original draft — pick one and run a SHORT demo (≤ 3 tool calls, ≤ 200-word summary).

- **question**: "Want to see a quick example query before you start asking?"
- **header**: "Demo"
- **multiSelect**: false
- **options** (exactly five):
  - **label**: "Synthesis demo — what does the community think about [topic]?"
    **description**: "Vault MOC-first (source:brain); chat-grep fallback otherwise"
  - **label**: "Attribution demo — what did [member] say or build?"
    **description**: "Chat grep + vault profile"
  - **label**: "Recency demo — what's happening in [channel] now?"
    **description**: "Chat read of latest ~200 lines"
  - **label**: "Compare-positions demo — X vs Y debate"
    **description**: "Vault debate notes + chat verbatim"
  - **label**: "Skip — let me just ask my own"
    **description**: "End setup. Ask any question naturally — auto-loaded skills handle source labelling"

### Step 7 — Branch demos (compressed from original)

For each picked demo, run the corresponding short flow from the original draft (synthesis: vault MOC or chat grep | attribution: members grep + role | recency: read tail of channel | compare: vault debates or twin greps).

For "Skip" pick: respond *"Great — ask away. Results come back labelled by source — chat (raw) and vault (synthesis). Profile written; future /lq runs will be lightweight."*

After demo OR skip: end. Don't loop.

---

## Returning-user path (lightweight — no interview)

When profile exists at `~/.claude/plugins/config/legalquants/lq/CLAUDE.md` with no placeholders:

### Step 1 — Brief greeting

Read the profile (use `Read`), extract `display_name`, `builder_id`, `total_messages`, `last_derived_at`. Emit:

```
Welcome back, <display_name>!  (builder-<NNN>)
```

If profile is older than 30 days OR if the user's message count has likely grown significantly since last derivation, append:

```
Your activity profile was last derived <X days ago>. To refresh: /lq --refresh-activity
```

### Step 2 — What's new (corpus delta since their last visit)

If `last_derived_at` is in profile, compute delta:
- Quick `grep(author: "builder-NNN", source: "chat", limit: 400)` to get current message count (the `author` filter counts the member's own posts; do NOT grep the `\\] builder-NNN: ` prefix — it returns 0)
- Compare to profile's `total_messages` field
- If new messages: *"Since you last ran /lq: you've posted +<X> messages (mostly in <channel>)."*
- If corpus stats are in your context from a recent healthcheck: also surface corpus-wide changes ("LQ AI channel grew by ~270 since you last visited")

Skip this step if no signal available.

### Step 3 — Invite + flag hints

Emit one line:

> *Ask your question naturally — results come back labelled by source, chat (raw) and vault (synthesis). To refresh your activity profile: `/lq --refresh-activity`. To redo from scratch: `/lq --redo`. To sign in / switch accounts: `/lq --signin` (uses the connector's **Authenticate** — native OAuth). To sign out: `/lq --signout`. To edit directly: open `~/.claude/plugins/config/legalquants/lq/CLAUDE.md`.*

Then stop. No picker, no demo, no further prompts.

---

## Refresh-activity path (`/lq --refresh-activity`)

For Mode-A profiles where the user wants to re-derive activity-based fields after posting more messages over time.

### Step 1 — Confirm and back up

Emit:

> *Re-deriving your activity profile. Manual overrides (fields marked `[manual]`) will be preserved. Existing profile backed up to `<path>.bak`.*

Copy current profile to `.bak` via Bash.

### Step 2 — Re-run derivation

Same tool calls as first-run Mode A (parallel):
1. Activity per channel — `grep(author: "builder-NNN", source: "chat", limit: 400)` (author filter, not a prefix grep)
2. Member profile
3. Top topics
4. Shipped projects
5. Vault people/projects (source:brain)

### Step 3 — Merge and write

Compare new derived values to current profile fields. For each field:
- If field has `[manual]` marker → preserve as-is, skip refresh
- If field is auto-derived and value changed → update with new value
- If new field added (e.g., a new project shipped) → append

Write merged profile.

### Step 4 — Confirm

Emit summary of changes:

> *Activity refreshed. Changes:*
> - *+<X> new messages (now <total>)*
> - *+<Y> new projects* (if any)
> - *New top topic: <topic>* (if shift)
> - *<N> manual overrides preserved*

Then stop.

---

## Resume path (if profile has `[PLACEHOLDER]` markers)

Emit:

```
Looks like setup was interrupted. I see these sections are incomplete:
  - <list each section with [PLACEHOLDER] markers>

Options:
  A. Resume — fill in just the missing sections
  B. Restart — overwrite from scratch (your existing answers are preserved 
     in a backup at ~/.claude/plugins/config/legalquants/lq/CLAUDE.md.bak)
```

Use **AskUserQuestion** to pick A or B. Resume = ask only the missing questions; Restart = run full first-run flow (and copy current file to `.bak` first).

---

## Sign-in path (`/lq --signin`)

Re-trigger the connector's **Authenticate** (native OAuth) — to sign in the first time, switch Google accounts, or recover from a 401. Steps: (1) tell the member to run Authenticate; (2) on success, **start a fresh session and re-run `/lq:start`** so identity resolves via `whoami`. **Do not derive activity this session** — the connector only authenticates as the member on the next session. No token files, no device codes.

## Sign-out path (`/lq --signout`)

Tell the member to remove the `lq-mcp` credential via Claude Code's connector UI (or re-run Authenticate to switch accounts), then start a fresh session. The plugin writes no token files; if an old `~/.config/lq/token.json` is present from a prior version, clear it idempotently:

```bash
rm -f ~/.config/lq/token.json
```

---

## Hard rules

- **Cold-start check ALWAYS runs first.** Never skip to first-run if profile is populated. Never skip to returning-user if profile is missing.
- **Never execute a free-text query under this skill.** `/lq <something>` → ignore the `<something>` and run the standard flow. The ONLY recognized post-`/lq` tokens are the flags `--redo`, `--refresh-activity`, `--signin`, `--signout`. Anything else (including during a sign-in poll) → ignore and run the standard flow.
- **Never echo the OAuth token.** Don't print the connector's access/refresh token into chat. It's verified server-side only; never decode or trust it locally — identity comes from the `whoami` MCP tool.
- **Never invoke `/lq` proactively.** Only on explicit user command.
- **Identity failures degrade gracefully.** On a *transient* `whoami` error (5xx / unreachable — not a 401), write profile with `builder_id: anonymous` and tell the member to re-run `/lq:start` later to pick up identity; don't block setup. A 401 / no-credential is NOT a transient failure → route to the Sign-in path instead.
- **Write the profile atomically.** Write to `<path>.tmp` first, then `mv` to final path. Prevents corruption on Ctrl-C during write.
- **Always preserve the `~` in the documented config path** when surfacing to user. Don't expand to absolute paths in user-facing messages — keep it portable.
- **Writes are limited to one path.** Profile data goes ONLY to `~/.claude/plugins/config/legalquants/lq/CLAUDE.md` (and `.bak` / `.tmp` variants). The plugin writes no auth/token files. Never `Bash`-modify anything in `raw/`, `sanitized/`, or the deployed corpus.
- **Cross-source rule inherited**: never quote LQclaw bot as a community position.
- **Server NEVER receives the profile.md.** It only receives the connector's OAuth token. Identity (`builder`, `email`, `display_greeting`) is resolved server-side from that token and surfaced via the `whoami` MCP tool. The mapping `local profile fields → query behavior` lives client-side. They're never combined.

---

## Why this skill exists

The `lq` plugin provides one unified lq-mcp connector (chat + synthesis vault) plus an assessment workflow. Without a single discovery surface AND a written profile, members face:

1. **Choice paralysis** — "do I run /lq:chat or /lq:brain?" Members don't think in MCP terms.
2. **Repeat onboarding** — without persistence, the model re-introduces capabilities every session.
3. **Anonymous personalization** — auto-loaded skills can't tailor queries to a specific member without identity link.
4. **Architecture leakage** — internal connector distinction shouldn't be in member UX.

`/lq` solves all four:

- **One command** (no MCP-picking)
- **Idempotent** (full interview once; lightweight greeting after)
- **Identity-linked** (via the `whoami` MCP tool — opt-in, server holds the legend, only own identity exposed)
- **Personalization payload** (profile.md is what auto-loaded skills read to bias source weighting and citation style)

---

## Replaces and supersedes

In plugin v0.2+:

- `chat/SKILL.md` (was `/lq:chat` — deprecated to shim in v0.2, removed in v0.4)
- `brain/SKILL.md` (was planned for v0.3 — never shipped; folded here)

The auto-loaded `lq-mcp/` guidance skill stays — different audience (model), different shape (dense reference).

---

## Server-side dependencies

This skill resolves identity through one connector tool. See [plan/lq-oauth/PRD.md](../../../../plan/lq-oauth/PRD.md) for the full contracts:

- **`whoami` MCP tool** (the lq-mcp connector tool) — the server verifies the connector's native-OAuth access token keylessly (against the AS's published JWKS) and returns `{ builder, email, display_greeting, anonymous }`. `builder: null` ⇒ corpus-derive-only. No `token_registry.json` / `roster.json` at runtime — identity is carried in the token's claims (`lqBuilder`, `lqGreeting`, set from the profile's `builderId` during backfill).

## How auth reaches the MCP

The `lq-mcp` connector authenticates via native OAuth managed by Claude Code; the plugin ships no auth hook and writes no token files.

Claude Code persists the credential and keeps the member signed in. A new sign-in (Authenticate) does not re-key the already-connected MCP — that's why `/lq --signin` hands off to a **fresh session** rather than running corpus tools, and why `/clear` is not enough (it doesn't reconnect the connector; only a fresh session does).
