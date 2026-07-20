---
name: lq-mcp
description: Use when lq-mcp tools are available — judgment for navigating the LegalQuants community corpus (primary-source chat + synthesis vault) through one connector. Read the corpus's own README / index at runtime for volatile facts; the tool descriptions carry all the mechanics.
---

# lq-mcp — navigating the LegalQuants corpus

You have read-only tools over the LegalQuants community knowledge through a single
connector. This guide carries **only the judgment** the tool descriptions don't —
the tools' own `description`/schema (which the model receives every session) are the
source of truth for what each tool does and what parameters it takes. **Don't look
here for tool mechanics; look here for how to use them well.**

## If the corpus isn't reachable

If the `lq-mcp` tools aren't in your toolset, or a call returns an auth error (401 /
"unauthorized" / an OAuth prompt), the connector isn't set up — **don't answer from your own
training knowledge.** Tell the user to run **`/lq:start`** to connect (sign in via the connector's
Authenticate), then retry. Keep it to one short message; don't improvise the corpus.

## How the shared brain works (say this once)

Before the **first** lq-mcp tool call of a session, read the member's profile at
`~/.claude/plugins/config/legalquants/lq/CLAUDE.md` and check for a `capture_consent:`
line.

- **If it's already there** (either value): proceed straight to the query — do NOT
  mention this again.
- **If it's absent** (first time): show exactly this, then continue with their query:

  > _The LQ brain is built from how members use it. Your sessions with the LQ tools
  > feed back into it so it keeps getting sharper for everyone — that's part of being
  > a member. (Say "turn off LQ capture" any time to opt out.)_

  Then append one line to that profile file: `capture_consent: true # YYYY-MM-DD`
  (or `capture_consent: false # YYYY-MM-DD` if they ask to opt out). Answer their
  question in the same turn — this is informational, not a request to wait on. One-off;
  never repeated on later sessions.

This is a membership deal, not a permission request — capture is on by default for
members; only an explicit opt-out turns it off. If the member later says to stop or
pause capture, set `capture_consent: false` in the profile. If the profile doesn't
exist yet (guest / not onboarded), skip the notice — nothing is captured until a
member is onboarded and has seen this.

## One connector, two corpora

`lq-mcp` serves **both** the community's primary-source **chat** archive **and** the
synthesized knowledge **vault** ("brain"), behind one set of tools. You select which
corpus a query spans via the tools' `source` parameter (the tool descriptions define
its values and default).

- **You do not pick a corpus up front.** A plain query spans both; results come back
  labelled by source. Only narrow `source` when the question is intrinsically
  one-sided (e.g. "quote me the message" → chat; "map how these ideas connect" → brain).
- On a fresh session, read each corpus's own entry point for the volatile specifics
  (layout, counts, channels, note types, conventions) rather than assuming — those
  facts live in the corpus, not in this guide, so this guide never goes stale.

## Provenance discipline (the load-bearing habit)

**Default: one synthesized answer, one voice.** Merge what you find across both sources
into a single answer. When chat and brain agree (the common case), say it once — no
source labels, no "according to the vault / in chat" scaffolding. The chat/brain
distinction lives in your *reasoning*, not on the surface.

Surface the chat-vs-vault distinction only to avoid **misattribution**: a `source: chat`
hit is *one member at one time* — phrase it "one member argued…", never "the community
thinks…". A `source: brain` note IS the synthesized position — never present it as something
a named person literally said.

**Don't compare the two sources against each other or hunt for divergence/staleness.** Both
corpora are synced together, so neither is structurally newer, and a note's `date:` is the
*source-discussion* date, not a freshness signal — contradiction-hunting just manufactures
disagreement that isn't there. Apply a simple recency bias when the question is
time-sensitive. **If the two ever seem to pull different ways, or you're unsure, trust the
primary-source chat.**

**Never** open or close with a manufactured provenance header asserting specific corpus
dates ("freshest note YYYY-MM-DD; chat through YYYY-MM-DD"), and never mention local files,
disk, or connector plumbing in an answer — those rot or leak.

## Judgment that makes answers good

- **Recency bias for "current / latest" questions.** Chat is a timeline and people
  change their minds. Weight the recent over the old; don't average across all history
  when only the latest stretch matters.
- **Never quote the LQclaw bot as a community position.** Bot messages are excluded by
  default; only surface them when the asker is specifically asking what the bot itself
  answered. A bot reply is never "what the community thinks."
- **Respect debates.** When the vault frames a topic as an open tension (a debate),
  present the sides — don't flatten it into a false consensus.
- **Navigate the vault by its hubs.** For a broad or "give me the landscape" question,
  find the relevant MOC (the curated hub note) and start there before scattered
  searches — a MOC maps a theme to its sub-notes. A note that many others link *to* is
  load-bearing or contested; prefer citing it.
- **People as a filter.** To go from a real first name or a project to a chat author,
  resolve via the vault's people/profile notes first (the public directory), then use
  that pseudonymous ID against the chat — never attach a guessed real name to a chat quote.
- **Stop when you can cite 2–3 records.** Name the specific messages/notes that support
  your answer and stop; don't run more searches for confirmation theater.

## Don't

- Don't re-derive corpus facts (counts, channel lists, eras) from memory — read the
  corpus README/index at runtime.
- Don't cross-contaminate identities: chat authors are pseudonymous (`builder-NNN`);
  the vault's people notes are the public directory. Don't attach a real name to a chat quote.
