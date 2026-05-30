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
training knowledge.** Tell the user to run **`/lq:start`** to connect (sign in, or set the guest
`LQ_MCP_TOKEN`), then retry. Keep it to one short message; don't improvise the corpus.

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

- **`source: chat` = verbatim, dated, attributable.** A real message someone sent at a
  point in time. Cite it as a quote with its date and the pseudonymous author.
- **`source: brain` = synthesized opinion**, evergreen and curated — **not** a quote.
  Never present a brain note as something a member literally said; never present a
  single chat message as the community's settled position.
- Keep the two straight in every answer. If you're quoting, it's chat. If you're
  characterizing "the community's take," it's brain (and say so).

## Judgment that makes answers good

- **Recency bias for "current / latest" questions.** Chat is a timeline and people
  change their minds. Sort chat hits by date, weight the recent over the old, and say
  "as of <date>." Don't average across all history when only the latest stretch matters.
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
