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
| File doesn't exist | → **First run** (mode determined by `/api/whoami` + activity probe — see "First-run mode detection" below) |
| File exists with `[PLACEHOLDER]` markers | → **Resume**: greet, offer to complete missing sections or `--redo` from scratch |
| File exists, no placeholders, no pause comment | → **Returning user** (lightweight greeting only) |
| User passed `--redo` flag | → **First run** (overwrite profile after confirmation) |
| User passed `--refresh-activity` flag | → **Re-derive activity only** (keep identity + manual overrides, re-derive corpus-based fields) |
| User passed `--signin` flag | → **Force device-code sign-in** (ignore any cached cookie; see "Sign-in path" below), then STOP with the fresh-session hand-off — do NOT continue into Mode A/B this session |
| User passed `--signout` flag | → **Sign out** (delete cached session cookie; see "Sign-out path" below), then stop |

**Migration check**: if no profile at the config path BUT a profile.md or CLAUDE.md exists at the plugin cache path (`~/.claude/plugins/cache/legalquants/lq/<version>/profile.md`), copy it forward to the config path before deciding which branch to take.

## First-run mode detection

On first run, identity + activity together determine which onboarding flow runs. Three modes:

| Mode | Detection | Onboarding flow |
|---|---|---|
| **Known active** | `/api/whoami` resolves to a builder (member OAuth path) AND a chat-source grep returns ≥ 10 messages from that pseudo-ID | **Derive everything from corpus**. Display "I know you" greeting. NO interview questions. ~5 tool calls, ~10 sec |
| **Known quiet** | `/api/whoami` resolves to a builder (member OAuth path) BUT a chat-source grep returns < 10 messages | **Brief 2-question interview** (topics of interest + recency-vs-synthesis preference) — supplements the thin corpus signal |
| **Anonymous** | `/api/whoami` returns `anonymous: true` (guest bearer path), OR endpoint unreachable | **Full cold interview** (role + practice area + focus + channels) — we have no corpus signal to derive from |

The threshold (N=10 messages) is configurable; tune via the constant `MIN_MESSAGES_FOR_DERIVATION` if the cold-start needs adjustment.

**Path detection** (two auth paths, both live):
- **Guest path:** a valid shared bearer → `/api/whoami` returns `anonymous: true` → Mode C (the full cold interview).
- **Member path:** member sign-in via the **Firebase device-code flow** (Google sign-in on the website → a Firebase **session cookie**, 7-day expiry, cached at `~/.config/lq/token.json`). Step 3 below reads that cookie first; if missing/expired and the member isn't on the shared guest bearer, it triggers sign-in. After sign-in, `/api/whoami` resolves the member's builder (from the Firebase custom claim) → Mode A/B. A member whose published profile has no `builderId` is authenticated but corpus-derive-only ("member without builder").
- The cached token is a Firebase session-cookie string, NOT a custom JWT. mcp-vercel verifies it server-side via `verifySessionCookie`. The skill never decodes or trusts it locally — identity always comes from `/api/whoami`.
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

### Step 3 — Identity (device-code sign-in + cached cookie)

Identity now flows from a Firebase **session cookie** cached at `~/.config/lq/token.json`. Resolve it in this order — do NOT skip steps:

**3a. Read the cached cookie.**

```bash
cat ~/.config/lq/token.json 2>/dev/null
```

The file (when present) looks like: `{ "access_token": "<firebase-session-cookie>", "expires_at": "<ISO-8601>" }`. Treat the cookie as **valid** if the file exists, `access_token` is non-empty, AND `expires_at` is in the future (compare to now). If anything is missing, malformed, or `expires_at` is in the past → treat as **no valid cookie** and go to 3c.

Never decode or parse the cookie locally — it's an opaque Firebase session-cookie string. Identity always comes from `/api/whoami`, which verifies it server-side.

**3b. Valid cookie → call whoami with it as the bearer.**

```
GET https://lq-mcp.vercel.app/api/whoami
Authorization: Bearer <access_token from token.json>
```

| Server response | What to do |
|---|---|
| `{ builder: "builder-042", email: "kevin.keller@example.com", display_greeting: "Kevin", authenticated_via: "firebase" }` | Emit: *"You're **Kevin** (builder-042 · kevin.keller@example.com). Writing this to your local profile."* — record all three fields; proceed to Mode A/B detection |
| `{ builder: null, email: "...", display_greeting: "...", anonymous: false }` | **Member without builder** — published profile but no `builderId` after backfill. Emit: *"You're signed in as **<greeting>** (<email>), but your profile isn't linked to a community builder yet, so I'll derive context from the corpus rather than self-attribute. Ask the operator to link your builder for full personalization."* — record `builder_id: anonymous`, `email`, `display_name`; proceed (corpus-derive-only, no self-attribution) |
| HTTP 401 | Cached cookie is expired or revoked server-side (`verifySessionCookie` threw). Delete the stale file (`rm -f ~/.config/lq/token.json`) and fall through to 3c (trigger sign-in) |
| HTTP 5xx / unreachable | Emit: *"Identity service unreachable — I'll continue anonymously for now. You can re-run `/lq --redo` later to retry."* Record `builder_id: anonymous`, `pending_identity_check: true`; proceed to Mode C |

**3c. No valid cookie → branch on guest bearer.**

Check whether a shared guest bearer is set: `echo "$LQ_MCP_TOKEN"`.

- **Guest bearer is set** (non-empty AND it is NOT the same value as a previously-cached cookie): the member is on the shared LQ_MCP_TOKEN. Run **Mode C (anonymous)** as before. Add ONE line at the top of the Mode C message:
  > *You're using the shared guest token. To link your member identity (and get the "I know you" greeting), run `/lq --signin` and sign in with your LegalQuants Google account.*
- **No guest bearer AND no cached cookie**: trigger the **Sign-in path** below inline (don't ask first — there's no other way in). The sign-in caches the cookie and confirms identity via the direct whoami call (S5), then stops with the "start a fresh session" hand-off — it does NOT continue into corpus-derived Mode A/B this session (the MCP only authenticates as the member on the next session). The full "I know you" greeting lands on the next session's returning-user path.

**If the displayed identity looks wrong** (user notices mismatch): they should re-run `/lq --signin` to re-authenticate with the correct Google account, or contact the operator if their Firestore profile is mis-mapped.

**Opt-out** (member doesn't want to be identified by the model in queries): the default is "identified" once signed in. Members who prefer anonymity can run `/lq --signout` (reverts to guest) or edit their profile.md and set `builder_id` to `anonymous`. Documented in the profile file's footer.

---

#### Sign-in path (device-code flow)

Triggered by `/lq --signin`, OR inline from 3c when there's no cookie and no guest bearer. **Never run a free-text query here** — this is identity only.

**S1. Request a device code.**

```
POST https://www.legalquants.com/api/device/code
Content-Type: application/json

{ "client_id": "lq-claude-code-plugin" }
```

Response (200):
```json
{ "device_code": "<opaque>", "user_code": "A1B2-3CDE",
  "verification_uri": "https://www.legalquants.com/device",
  "expires_in": 600, "interval": 5 }
```
On `400 invalid_client` or `429` (rate-limited): emit the error and stop — tell the member to retry in a minute.

**S2. Show the member the code + URL.** Use `verification_uri` and `user_code` from the response verbatim (don't hardcode — the server is source of truth for the URL):

```
To sign in to LegalQuants:

  1. Visit https://www.legalquants.com/device
  2. Enter code: A1B2-3CDE
  3. Sign in with your Google account

Waiting... (this page is open for 10 min)
```

**S3. Poll for the token.** Every `interval` seconds (default 5), POST:

```
POST https://www.legalquants.com/api/device/token
Content-Type: application/json

{ "device_code": "<opaque>", "client_id": "lq-claude-code-plugin" }
```

Use `Bash` with a `sleep <interval>` between polls (a small shell loop is fine; cap total wait at `expires_in` ≈ 10 min). Handle responses:

| Response | What to do |
|---|---|
| `400 { "error": "authorization_pending" }` | Member hasn't finished sign-in yet. Keep polling (wait `interval`s, retry) |
| `400 { "error": "slow_down" }` | Polling too fast. Increase `interval` by +5s, then keep polling |
| `400 { "error": "expired_token" }` | The 10-min window elapsed. Emit: *"Sign-in timed out. Run `/lq --signin` to try again."* Stop |
| `403 { "error": "access_denied" }` | Profile not published / not on the allowlist. Emit: *"Sign-in was rejected: your LegalQuants profile must be **published** before you can link it. Publish it at legalquants.com, then run `/lq --signin` again."* Stop |
| `429 { "error": "Too many requests..." }` | Rate-limited (often a shared office/VPN IP). Back off — add +5s to `interval` — then **keep polling** (treat exactly like `slow_down`). Do NOT stop |
| `500 { "error": "server_error" }` | Transient server error. **Keep polling** (wait `interval`s) until the `expires_in` budget elapses |
| `400 { "error": "invalid_request" }` | Malformed poll body (a bug in this client, not a member-facing error). Stop and report the bug — don't loop |
| any other / unrecognized response | **Keep polling** until `expires_in` elapses, then emit the timeout message and stop. NEVER treat an unrecognized response as success or cache anything from it |
| `200 { "access_token": "<cookie>", "token_type": "Bearer", "expires_in": 604800 }` | Success → S4 |

**S4. Cache the session cookie (mode 0600).** Compute `expires_at` = now + `expires_in` seconds (ISO-8601). Prefer the `Write` tool for the JSON file (it isn't subject to shell quoting, so a cookie with special characters is safe), then `chmod` via Bash:

```bash
mkdir -p ~/.config/lq
```
Then `Write` to `~/.config/lq/token.json`:
```json
{ "access_token": "<cookie>", "expires_at": "<ISO-8601>" }
```
Then lock it down:
```bash
chmod 600 ~/.config/lq/token.json
```

(Do NOT echo the cookie into chat. Don't print the file contents back.)

**S5. Confirm identity with ONE direct whoami call — then hand off to a fresh session.** The cached cookie is now on disk; that's all the sign-in session needs to do. The `lq-mcp` connector picks the cookie up **automatically on the next session** (the connector's `headersHelper`, `hooks/lq-auth-header.sh`, re-reads `~/.config/lq/token.json` and supplies the `Authorization` header on each connection). It does NOT re-read mid-session, so do not run any corpus / MCP tool call here, and do not attempt activity derivation (that needs the authenticated MCP, which only comes up on a fresh session).

To greet the member by name right now, make **ONE** direct HTTPS call — a plain `fetch`/`curl`, NOT the MCP:

```
GET https://lq-mcp.vercel.app/api/whoami
Authorization: Bearer <access_token just cached>
```

Use the returned `display_greeting` + `builder` to fill the success block. Then emit **one** crisp success block (no "[PENDING]" apology, nothing pending on the member's side):

```
✅ Signed in as <display_greeting> (<builder> · <email>).

One quick thing to finish the link: **start a fresh Claude Code session** — quit and reopen,
or open a new terminal. On that next session the LegalQuants connector reads your cached
sign-in automatically and connects as you. That's it — one-time, nothing pending on your end.

Next session I'll greet you by name and pull your activity (channels, projects, topics).
```

**S6. Stop here for `--signin`.** Don't re-run the Step-3 identity branch, don't derive activity, don't loop into a demo — the authenticated activity greeting belongs to the *next* session's returning-user path. (When sign-in was triggered inline from 3c during a first run, you may still record the identity you just resolved from the whoami call into the profile via Step 5, but do NOT make any corpus tool call this session — defer the "I know you" derivation to the next session.)

### Step 4 — Build the profile (branches by mode)

Based on the mode detected in cold-start check:

---

#### Mode A: Known active (derive from corpus, no interview)

Run these tool calls **in parallel** (single response with multiple tool calls):

1. **Activity per channel** — `grep("\\] builder-NNN: ", source: "chat", regex: true)` substituting the actual pseudo-ID. Count hits per channel. Sort desc.
2. **Member profile** — `read("members/builder-NNN.md")` — get the role descriptor, joined date, bio.
3. **Top topics** — sample the member's messages (use the grep output from #1, take a representative slice of ~30 messages). For each, extract content keywords. Cluster manually into top 3-5 topics.
4. **Shipped projects** — already in member file (`## Ships` section). Extract project names + one-line descriptions.
5. **Vault people/projects** — read the vault's curated profile for this member (`read("people/<member-slug>.md", source: "brain")`) + `grep("builder-NNN", source: "brain")` for cross-referenced projects.

**Infer the focus orientation** (recency vs synthesis): scan the member's last ~20 messages. Are they majority-questions ("anyone tried...?", "what does X mean?") or majority-statements ("I built", "here's what I think")? Questions → recency-focused. Statements → synthesis-focused. Mixed → both.

**Compose the "I know you" greeting**. Example template:

```
Welcome back, <display_greeting> (<builder>)!

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

Your shared guest token authenticates against the MCP — so you have full read 
access to the full community chat archive. But it isn't linked to a 
specific community member, so I can't personalize.

→ To link your member identity: run `/lq --signin` and sign in with the Google 
  account on your LegalQuants profile. You'll get the "I know you" greeting on 
  your next /lq run (activity, projects, topics — all derived from your 
  contributions). Your profile must be published first.

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

*Source: /api/whoami (resolves the Firebase session-cookie custom claims).*
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
Your identity is linked via a Firebase session cookie (cached separately at
~/.config/lq/token.json) whose custom claims carry your builder-NNN. To unlink,
run `/lq --signout`. Edit, delete, or rewrite this file any time.*
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
- Quick `grep("\\] builder-NNN: ", source: "chat", regex: true)` to get current message count
- Compare to profile's `total_messages` field
- If new messages: *"Since you last ran /lq: you've posted +<X> messages (mostly in <channel>)."*
- If corpus stats are in your context from a recent healthcheck: also surface corpus-wide changes ("LQ AI channel grew by ~270 since you last visited")

Skip this step if no signal available.

### Step 3 — Invite + flag hints

Emit one line:

> *Ask your question naturally — results come back labelled by source, chat (raw) and vault (synthesis). To refresh your activity profile: `/lq --refresh-activity`. To redo from scratch: `/lq --redo`. To sign in / switch accounts: `/lq --signin`. To sign out: `/lq --signout`. To edit directly: open `~/.claude/plugins/config/legalquants/lq/CLAUDE.md`.*

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
1. Activity per channel
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

Force re-authentication via the device-code flow — used when the cached cookie expired, the member wants to switch Google accounts, or they're upgrading from the shared guest bearer.

1. If a cookie is already cached, ignore it (this is a *forced* re-auth) — but DON'T delete it until the new sign-in succeeds (so a cancelled sign-in leaves the old identity intact).
2. Run the **Sign-in path (device-code flow)** under Step 3 (S1–S6). On success it overwrites `~/.config/lq/token.json`, confirms identity via the ONE direct whoami call (S5), and emits the "start a fresh session" hand-off.
3. **Stop after the success block — do NOT derive activity this session.** The `lq-mcp` connector only authenticates as the new member on the *next* session (the `headersHelper` re-reads the cookie at each connection, not mid-session). So don't re-run corpus-derived Mode A/B here and don't run any MCP tool call. The "I know you" greeting + activity refresh land automatically on the next session's returning-user path; mention they can run `--refresh-activity` then if they want fresh stats.
4. On `access_denied` / `expired_token`: surface the message from the S3 table and stop. Leave any existing cookie untouched.

## Sign-out path (`/lq --signout`)

Delete the cached session cookie and revert to guest (or unauthenticated).

1. Delete the cached cookie:
   ```bash
   rm -f ~/.config/lq/token.json
   ```
2. Check for a guest bearer: `echo "$LQ_MCP_TOKEN"`.
   - **Guest bearer still set** → emit: *"Signed out. **Start a fresh Claude Code session** to drop the member identity — on the next session the connector reads the (now-absent) cookie and falls back to the shared guest token (anonymous read access). Run `/lq --signin` any time to re-link your member identity."*
   - **No guest bearer** → emit: *"Signed out. **Start a fresh session** to drop the member identity — after that, MCP calls won't authenticate until you sign in again. Run `/lq --signin` to sign back in."*
3. The change takes effect when the connector next reconnects on a fresh session: its `headersHelper` re-reads `~/.config/lq/token.json`, finds it gone, and falls back to the guest bearer (or no auth). There's nothing to do mid-session.
4. Do NOT touch the practice profile at `~/.claude/plugins/config/legalquants/lq/CLAUDE.md` — sign-out only clears the credential, not the personalization. Then stop.

---

## Hard rules

- **Cold-start check ALWAYS runs first.** Never skip to first-run if profile is populated. Never skip to returning-user if profile is missing.
- **Never execute a free-text query under this skill.** `/lq <something>` → ignore the `<something>` and run the standard flow. The ONLY recognized post-`/lq` tokens are the flags `--redo`, `--refresh-activity`, `--signin`, `--signout`. Anything else (including during a sign-in poll) → ignore and run the standard flow.
- **Never echo the session cookie.** Don't print `~/.config/lq/token.json` contents, the `access_token`, or the raw `$LQ_MCP_TOKEN` value into chat. Cache it mode 0600. The cookie is verified server-side only; never decode/trust it locally.
- **Never invoke `/lq` proactively.** Only on explicit user command.
- **API failures degrade gracefully.** If `/api/whoami` is unreachable, write profile with `builder_id: anonymous, pending_identity_check: true`. Don't block setup.
- **Write the profile atomically.** Write to `<path>.tmp` first, then `mv` to final path. Prevents corruption on Ctrl-C during write.
- **Always preserve the `~` in the documented config path** when surfacing to user. Don't expand to absolute paths in user-facing messages — keep it portable.
- **Writes are limited to two paths.** Profile data goes ONLY to `~/.claude/plugins/config/legalquants/lq/CLAUDE.md` (and `.bak` / `.tmp` variants). The session cookie goes ONLY to `~/.config/lq/token.json` (and `.tmp`). Never `Bash`-modifies anything in `raw/`, `sanitized/`, or the deployed corpus.
- **Cross-source rule inherited**: never quote LQclaw bot as a community position.
- **Server NEVER receives the profile.md.** It only receives the session cookie (or shared bearer). Identity (`builder`, `email`, `display_greeting`) is carried in the cookie's Firebase **custom claims**, resolved server-side and surfaced via `/api/whoami`. The mapping `local profile fields → query behavior` lives client-side. They're never combined.

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
- **Identity-linked** (via `/api/whoami` — opt-in, server holds the legend, only own identity exposed)
- **Personalization payload** (profile.md is what auto-loaded skills read to bias source weighting and citation style)

---

## Replaces and supersedes

In plugin v0.2+:

- `chat/SKILL.md` (was `/lq:chat` — deprecated to shim in v0.2, removed in v0.4)
- `brain/SKILL.md` (was planned for v0.3 — never shipped; folded here)

The auto-loaded `lq-mcp/` guidance skill stays — different audience (model), different shape (dense reference).

---

## Server-side dependencies

This skill calls these endpoints. See [plan/lq-oauth/PRD.md](../../../../plan/lq-oauth/PRD.md) for the full contracts:

- `GET https://lq-mcp.vercel.app/api/whoami` (mcp-vercel) — verifies the cached session cookie via `verifySessionCookie` and returns `{ builder, email, display_greeting, anonymous, authenticated_via }`.
- `POST https://www.legalquants.com/api/device/code` (website) — issues `{ device_code, user_code, verification_uri, expires_in, interval }`.
- `POST https://www.legalquants.com/api/device/token` (website) — CLI polls; returns the Firebase session cookie once the member completes sign-in at `/device`.
- Device-code issuance + Google sign-in + `setCustomUserClaims` + `createSessionCookie` happen on the website (`legalquant`), which already has the Firebase Admin SDK and member profiles. No `token_registry.json` / `roster.json` at runtime — identity is carried in the cookie's custom claims (`lqBuilder`, `lqGreeting`, set from the profile's `builderId` during backfill).

## Token injection (how the cached cookie reaches the MCP)

`.mcp.json` registers the `lq-mcp` connector with a **`headersHelper`** — `/bin/sh ${CLAUDE_PLUGIN_ROOT}/hooks/lq-auth-header.sh` (pure POSIX sh, invoked via `/bin/sh` — NOT `node`, because Claude Code spawns the helper with no `PATH` and an unqualified `node` would be "command not found" → empty output → no auth → OAuth-404). Claude Code runs that helper **on each connection** and uses its stdout JSON as the request headers. The helper resolves the bearer fresh every time:

- It reads the cached session cookie at `~/.config/lq/token.json`; if present, non-empty, and not expired, it emits `{"Authorization":"Bearer <cookie>"}` — so the connector authenticates as the signed-in member.
- Else it falls back to the shared guest bearer `$LQ_MCP_TOKEN` (if set); else it emits `{}` (no auth) and the server 401s.

Because the header is resolved **per connection** (not interpolated once at spawn, and not via any session-start env injection), the cookie a sign-in just cached is picked up the next time the connector connects — which happens on a **fresh session start** (and `/resume`). A sign-in performed mid-session does NOT re-trigger the helper on the already-connected MCP; that's why `/lq --signin` confirms identity with a direct whoami call and then hands off to a fresh session rather than running corpus tools.

**HARD RULE:** never reference a SessionStart hook, `hooks/lq-session-start.mjs`, `$CLAUDE_ENV_FILE`, or "the MCP reads `$LQ_MCP_TOKEN` at spawn" — that mechanism is **deleted**. Auth is now the `headersHelper` (`/bin/sh hooks/lq-auth-header.sh`, pure POSIX sh — never invoke it via `node`; CC's helper spawn has no PATH) reading the cached cookie on each connection. And never tell a member to `/clear` to pick up a new sign-in — `/clear` does NOT reconnect the connector; only a **fresh session** does.
