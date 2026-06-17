---
name: update
description: |
  Profile updater for the LegalQuants community plugin. Run when the user types /lq:update.
  Helps a member update their LegalQuants profile (the classic Lawyer data model) from what they
  tell Claude — a new project, a media mention, a sharper bio/philosophy — optionally enriched by
  their own community footprint (read-only, via the lq-mcp connector). Claude drafts STRUCTURED
  field-changes that fit the website schema, shows the member exactly what it will submit, then
  submits ONE pending proposal the member reviews and publishes on legalquants.com. It never
  mutates the profile directly and never publishes — the website review/publish is the only place
  changes go live. Flags: --member <builder-NNN> (operator, draft-only). Falls fast to /lq:start
  when the connector isn't reachable. Never invoke proactively.
---

# /lq:update — update your LegalQuants profile, with Claude

The member wants to update their **classic** LegalQuants profile (the `Lawyer` record rendered at
`legalquants.com/lawyers/{slug}`). You turn what they tell you — a new project, a media appearance,
a tighter bio or philosophy — optionally enriched by what they've shipped and said in the community
— into **structured `FieldChange`s that fit the website schema**. You show them the exact set,
submit it as ONE pending **proposal**, and point them to the website to review and publish.

> You are the only model in this flow. The server does **not** re-interpret your output — what you
> show the member is exactly what they review and publish. So your changes must be correct,
> conformant to the schema, and evidence-backed. Nothing goes live until the member publishes on the
> website.

## When this is the right tool

- ✅ "Add the project I just built / a media mention / update my bio / philosophy."
- ✅ "Update my profile from what I've been doing in the community."
- ✅ `/lq:update --member builder-141` — operator drafting changes for a member (draft-only, no submit).
- ❌ A general question about the community → `/lq:ask`.
- ❌ Editing someone else's live profile, or anything not the caller's own record.

## Step 0 — Pre-flight: confirm the connector is reachable (BEFORE doing anything)

1. **Tools present?** Check for the lq-mcp tools (`whoami`, `read`, `grep`, and the submit tool
   `submit_profile_proposal`). If you see a native **Authenticate** action but no tools yet, the
   connector IS wired — the member just hasn't signed in. Tell them to run **Authenticate (native
   OAuth sign-in)**, then re-run `/lq:update`. Treat it as absent only when no LegalQuants tool exists.
2. **Authenticated?** Run `whoami`. On an auth error (401 / OAuth prompt), prefer the connector's
   Authenticate; else `/lq:start --signin`.
3. Only if `whoami` returns real data → proceed.

### Not connected — fail fast, route to /lq:start
> I can't reach the LegalQuants connector — looks like you're not connected yet. Run the
> **Authenticate** action for lq-mcp (native OAuth), or **`/lq:start`**, then re-run `/lq:update`.

## Step 1 — Resolve the subject (and gate `--member`)

1. `whoami` → `{ builder, email, anonymous }`.
2. **No `--member`** → the subject is the caller's own profile. If `anonymous: true`, the caller
   isn't a signed-in member — route to Authenticate / `/lq:start` and stop.
3. **`--member <builder-NNN>`:** if it equals the caller's own builder, fine. If it targets a
   **different** member, this is **operator-only and DRAFT-ONLY** (you will NOT submit): verify the
   caller is an operator via `~/.claude/plugins/config/legalquants/lq/operators` (one `email` or
   `builder-NNN` per line; `#`/blank ignored). Refuse and stop — reading nothing about the target —
   if the file is missing, the caller is `anonymous`, or the caller isn't listed:
   > `--member` drafts another member's changes and is operator-only (draft preview, no submit). Run
   > `/lq:update` with no flag to update your own profile.

## Step 2 — Gather what to change

The update comes from **what the member tells you**, optionally enriched by their footprint:

1. **Member-supplied (primary).** Take what they give you directly — a project description + demo /
   GitHub / release links, a media mention + URL, a bio/philosophy rewrite. Hosted links only;
   local files (a video/screenshot on disk) are uploaded by the member on the website review screen,
   not here.
2. **Read their current profile** so you diff against it: `read({ref:'members/builder-NNN.md'})`
   (and the live record if available). Every `FieldChange.before` is the current value.
3. **Footprint enrichment (optional, only if they want it).** `grep({author:'builder-NNN',
   limit:400})` (query omitted) lists everything they said; `scan_thread` recovers context; cite the
   `quote` + `channel` + `date` as evidence. **Exclude the LQClaw bot.** Offer enrichment ("want me
   to also pull what you've shipped in the community?") — don't force it.

## Step 3 — Draft the structured changes (and show them)

Compose an array of **`FieldChange`** objects against the **classic** schema. The contract — allowed
fields, element shapes, `op` semantics (`append` = one new array element; `set` = whole-field
replace), and the evidence requirement — is in **`reference/classic-profile-schema.md`** beside this
skill. Follow it exactly.

- **Ground every change.** Each `FieldChange` carries usable `evidence` (a member-supplied URL, a
  quote of what they told you, or a chat `quote`+`channel`+`date`). No evidence → don't emit it (the
  server drops it).
- **Conformant values only.** Right field, right shape, plain text. To ADD a project/media/
  philosophy item use `op:'append'` with one element as `after`; to edit a scalar (bio/tagline/…)
  use `op:'set'`.
- **Show the member the exact set you will submit** — a short, readable summary of each change
  (field, what it adds/changes, the evidence). This is the truthful preview: it is exactly what
  they'll review and publish. Let them edit/cut before you submit.

## Step 4 — Submit the proposal (own profile only)

Once the member approves the set, submit ONE proposal via the lq-mcp tool:

```
submit_profile_proposal({ target: 'classic', changes: [ ...FieldChange ] })
```

(The tool carries the member's authenticated identity and `profile:write` scope server-side; you
never handle a token.) Handle the result:

- **created (`201`)** → tell the member it's drafted and give the review link:
  > Drafted N updates from what you told me. Review and publish them at
  > **legalquants.com/profile/updates** — nothing changes on your public profile until you do.
- **invalid (`422`)** → some changes failed validation (bad field or a third-party-name flag).
  Report which, fix or drop them, and resubmit.
- **not published (`409`)** → the member's profile is still a draft:
  > Your profile is still a draft — finish and publish it in the editor first, then run `/lq:update`.
- **auth (`401/403`)** → re-auth via Authenticate / `/lq:start`.

**`--member` (operator):** do NOT submit. Draft the changes, show them, and stop — say it's a
draft preview for the named member, not a submission.

## Conventions

- **No third-party real names** in any `FieldChange.after` or evidence — the member's own name is
  fine (it's their profile), but never another member/person's real name, an LQClaw-narrated bio, or
  a slug/handle that maps to a real person. The server name-scans and rejects; don't trip it.
- **Exclude the LQClaw bot** as a corpus source (noisiest, worst name-leak source).
- **Propose, never publish.** You submit a pending proposal; the member reviews and publishes on the
  website (the only place a change goes live). Don't claim anything is live.
- **Self-only writes.** Only the caller's own profile is ever submitted. `--member` is draft-only.
- **No founder/org-strategy framing** in member-facing copy. Never invoke proactively — only on `/lq:update`.
