---
name: ask
description: |
  Cross-source synthesis for the LegalQuants community knowledge plugin. Run when the user types
  /lq:ask "<question>". Acts as the lq-orchestrator: fans out over BOTH sources in parallel — the
  primary-source chat (who/when/verbatim/recency) and the synthesis vault (positions, debates, MOCs) —
  then merges into one cited answer. Use for "what does the community think + what's the latest"
  questions that want both the evergreen position AND its primary-source grounding.
  Most everyday questions don't need this — the auto-loaded lq-mcp guidance handles single-source
  queries fine. Reach for /lq:ask when a question genuinely spans both. Never invoke proactively.
---

# /lq:ask — cross-source synthesis (the orchestrator)

The member asked a question that wants **both** the community's synthesized *position* and its
primary-source *grounding*. You are the **orchestrator**: fan out over both sources in parallel, then merge.

## When this is the right tool

- ✅ "What does the community think about X, and where does that come from / what's the latest?"
- ✅ "Synthesize the thinking on Y and back it with who actually said it."
- ✅ Questions where the brain's evergreen take might be **out of date** vs recent chat.
- ❌ Pure attribution/recency ("who said X", "latest on X") → just query `source:chat` directly.
- ❌ Pure synthesis ("the community's position on X") → just query `source:brain` directly.

If the question is clearly one-sided, say so and use a single source instead of fanning out.

## Step 0 — Pre-flight: confirm the corpus is reachable (BEFORE fanning out)

Do NOT spawn the explorers until you've confirmed the `lq-mcp` tools are present **and**
authenticated — fanning out into an unauthenticated connector just fails twice and wastes the run.

1. **Tools present?** Check your available tools for the `lq-mcp` corpus tools (`read`, `grep`,
   `list`, …). If they're absent — or the only LegalQuants tool you see is an
   auth / OAuth / "authenticate" / bootstrap entry — the connector isn't set up → go to **Not connected**.
2. **Authenticated?** If the tools are present, run ONE cheap probe (e.g. `list` at the root, or a
   tiny `grep`). If it returns an auth error (401 / "unauthorized" / "not authenticated" / an OAuth
   prompt) → go to **Not connected**.
3. Only if the probe returns real corpus data → proceed to Step 1.

### Not connected — fail fast, route to /lq:start
Do **not** fan out, and do **not** answer from your own training knowledge. Stop and say, plainly:

> I can't reach the LegalQuants corpus — looks like you're not connected yet. Run **`/lq:start`** to
> sign in (or set your guest `LQ_MCP_TOKEN`), then re-run your `/lq:ask`. I didn't make anything up.

Then end — one short message; don't dump connector internals or OAuth-bootstrap details.

## Step 1 — Fan out (PARALLEL — both in one message)

Spawn **two `general-purpose` subagents at once** (a single message with two Agent/Task calls, so they
run concurrently). Each gets the question verbatim plus a corpus-specific brief.

### HARD RULE — corpus comes ONLY from the lq-mcp tools, NEVER from local disk (applies to BOTH explorers)

The explorers are `general-purpose` subagents with filesystem access, so you MUST bind them tightly:
the **only** way they may reach the corpus is through the `lq-mcp` tools (`read` / `grep` / `list` / etc.).
They must **NEVER** read the chat or vault from the local filesystem — not `packages/lqbrain/content`,
not `sanitized/`, not `raw/`, not any local vault/chat path, not via `Read` / `Grep` / `Glob` / `Bash`
(`cat`, `find`, …). Those files exist only on operator machines and are **absent for every real member**,
so reading them yields a **false, machine-dependent answer** that would silently break for anyone else.
If the `lq-mcp` tools are absent, or any tool returns an auth error (401 / "unauthorized" / "not
authenticated" / an OAuth prompt), the explorer must return exactly **"unavailable"** and stop — it must
**NOT** fall back to disk, to its own training knowledge, or to any other source. (Pre-flight in Step 0
should already have caught this; this rule is the backstop in case a connection drops mid-run.)

**chat-explorer** (uses ONLY the lq-mcp tools with `source:chat` — read / grep / list / scan_thread / read_attachment / fetch_url):
> Research this question in the LegalQuants **primary-source chat**: «QUESTION».
> Use ONLY the `lq-mcp` tools — NEVER read the chat from the local filesystem (no `Read`/`Grep`/`Glob`/`Bash`,
> no `sanitized/` or `raw/` or `packages/` path); those exist only on operator machines and would give a
> false answer. If the `lq-mcp` tools are missing or return an auth error, reply exactly "unavailable" and stop.
> Read `README.md` + `GLOSSARY.md` first. Find who said what, when, and the *most recent* take
> (sort hits by date desc; weight the last few weeks). Return: 3–6 findings, each with a
> `Channel#Lline` citation + date + pseudo-ID/role; flag the single most recent development; note if
> the topic evolved. Exclude the LQclaw bot. Be concise — bullet findings, not prose.

**brain-explorer** (uses ONLY the lq-mcp tools with `source:brain` — read / grep / list / traverse_graph / fetch_url; `traverse_graph` is brain-only):
> Research this question in the LegalQuants **synthesis vault (LQBrain)**: «QUESTION».
> Use ONLY the `lq-mcp` tools — NEVER read the vault from the local filesystem (no `Read`/`Grep`/`Glob`/`Bash`,
> no `packages/lqbrain/content` or any local vault path); those exist only on operator machines and would give
> a false answer. If the `lq-mcp` tools are missing or return an auth error, reply exactly "unavailable" and stop.
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
6. If an explorer returns **"unavailable"** (its `lq-mcp` tools were absent or 401'd mid-run), treat that
   source as missing — say so plainly, don't fill the gap from disk or training knowledge. If BOTH return
   "unavailable", stop and route the member to `/lq:start` exactly as in **Not connected** — don't answer.

## Conventions

- Members are pseudonymous in chat (`builder-NNN` / role descriptors); brain `people/` notes are the
  public directory. Don't cross-contaminate chat attribution with real names.
- Stop when the answer is cited from 2–3 records per side. No confirmation theater.
- This is a power-user surface. If `/lq:ask` was invoked but the question is trivial or one-sided,
  it's fine to answer directly from one source and note that the full fan-out wasn't needed.
