---
name: ask
description: |
  Cross-MCP synthesis for the LegalQuants community knowledge plugin. Run when the user types
  /lq:ask "<question>". Acts as the lq-orchestrator: fans out to BOTH MCPs in parallel — lqchat-mcp
  (primary-source chat: who/when/verbatim/recency) and lqbrain-mcp (synthesis vault: positions,
  debates, MOCs) — then merges into one cited answer. Use for "what does the community think + what's
  the latest" questions that want both the evergreen position AND its primary-source grounding.
  Most everyday questions don't need this — the auto-loaded lqchat-mcp / lqbrain-mcp guidance routes
  a single MCP fine. Reach for /lq:ask when a question genuinely spans both. Never invoke proactively.
---

# /lq:ask — cross-MCP synthesis (the orchestrator)

The member asked a question that wants **both** the community's synthesized *position* and its
primary-source *grounding*. You are the **orchestrator**: fan out to both MCPs in parallel, then merge.

## When this is the right tool

- ✅ "What does the community think about X, and where does that come from / what's the latest?"
- ✅ "Synthesize the thinking on Y and back it with who actually said it."
- ✅ Questions where the brain's evergreen take might be **out of date** vs recent chat.
- ❌ Pure attribution/recency ("who said X", "latest on X") → just use `lqchat-mcp` directly.
- ❌ Pure synthesis ("the community's position on X") → just use `lqbrain-mcp` directly.

If the question is clearly one-sided, say so and use the single MCP instead of fanning out.

## Step 1 — Fan out (PARALLEL — both in one message)

Spawn **two `general-purpose` subagents at once** (a single message with two Agent/Task calls, so they
run concurrently). Each gets the question verbatim plus a corpus-specific brief:

**chat-explorer** (uses the `mcp__lqchat__*` tools — read / grep / list / scan_thread / read_attachment / fetch_url):
> Research this question in the LegalQuants **primary-source chat**: «QUESTION».
> Read `README.md` + `GLOSSARY.md` first. Find who said what, when, and the *most recent* take
> (sort hits by date desc; weight the last few weeks). Return: 3–6 findings, each with a
> `Channel#Lline` citation + date + pseudo-ID/role; flag the single most recent development; note if
> the topic evolved. Exclude the LQclaw bot. Be concise — bullet findings, not prose.

**brain-explorer** (uses the `mcp__lqbrain__*` tools — read / grep / list / traverse_graph / fetch_url):
> Research this question in the LegalQuants **synthesis vault (LQBrain)**: «QUESTION».
> Read `index.md` + `ask.md` first. Find the relevant MOC(s), insights, and any `debates/` note;
> use `traverse_graph` to map how the idea connects. Return: the community's synthesized position
> (or the tension if it's a debate), 3–6 supporting notes by slug, and whether it's framed as
> settled or contested. Note the notes' `date`/`created` so staleness can be judged. Be concise.

## Step 2 — Merge (you, the orchestrator)

Synthesize **one** answer from the two returns:

1. **Lead with the brain's synthesized position** — the community's evergreen take (or the debate's
   sides, if contested — don't flatten a debate into false consensus).
2. **Ground it with chat's primary source** — who advanced it, when, and the most recent movement.
3. **Reconcile divergence — this matters:** the brain vault is *synthesized and can lag the live chat*.
   If chat shows a **more recent** development than the brain note's `date`, **prefer the chat signal
   and flag that brain is behind** ("the vault's take is from [date]; more recently in chat, …").
   If they agree, say so — that's a strong, well-grounded answer.
4. **Cite both** — brain note slugs (`[[The Orchestration Layer]]`) *and* chat provenance
   (`General#L5421`). Distinguish them: synthesis vs verbatim.
5. If one explorer found nothing, say so plainly and lean on the other — don't fabricate balance.

## Conventions

- Members are pseudonymous in chat (`builder-NNN` / role descriptors); brain `people/` notes are the
  public directory. Don't cross-contaminate chat attribution with real names.
- Stop when the answer is cited from 2–3 records per side. No confirmation theater.
- This is a power-user surface. If `/lq:ask` was invoked but the question is trivial or one-sided,
  it's fine to answer directly from one MCP and note that the full fan-out wasn't needed.
