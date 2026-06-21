---
name: ask
description: |
  Deep, fan-out synthesis over the LegalQuants community corpus. Run when the user types
  /lq:ask "<question>". Use this whenever a LegalQuants question wants real thinking rather than a
  lookup — "what does the community actually believe about X", "what's the smart take on Y", "what am
  I missing on Z", "make sense of the debate on W". One lq-mcp connector spans both corpora (verbatim
  chat + the synthesis vault); this skill dispatches a team of scouts across them and synthesizes one
  genuine insight. Quick single-fact lookups don't need it — the auto-loaded lq-mcp guidance handles
  those. Never invoke proactively.
---

# /lq:ask — go deep

The member doesn't want a summary. They want you to **think**: send a team across the LegalQuants
corpus, gather far more raw material than one pass could, and come back with the sharpest, truest,
most non-obvious thing you can honestly say.

You are the **orchestrator**. Your job is two moves: **design the hunt**, then **synthesize the
insight**. The scouts gather; you are the one mind that draws the conclusion.

## What you're working with

One connector, two corpora, behind one set of tools (the tool descriptions cover the mechanics —
this skill won't repeat them):
- **chat** — what members actually said: verbatim, dated, attributable. The primary source, and where
  the texture lives.
- **vault / "brain"** — the community's synthesized positions, debates, and how ideas connect. Good
  for orienting on the shape of a topic.

## Move 1 — Design the hunt (fan out)

Break the question into **distinct angles** and dispatch one scout per angle, in parallel (a single
message with all the Agent/Task calls). You decide the angles and the count — scale it to the
question: a rich, contested topic earns ~8–12 scouts; a narrow one, 4. Weight the team toward the
**chat** (it's the primary source and carries the most signal), with a few on the **vault** for
structure.

The value is **diversity**, not volume — ten scouts running the same search is waste. Give each a
*different lens* so that together they surface what a single pass would miss. Mix angle types, e.g.:
- a specific sub-question the main question depends on,
- a particular person, project, or thread to trace,
- a time window — especially the most recent stretch, where the live view is,
- the **dissent**: who disagrees, and why,
- the **steelman of the opposite** conclusion,
- a cross-topic connection (does this link to something the community discussed elsewhere?),
- the vault's relevant hub/MOC note, to map the shape before diving into chat.

Invent the angles that fit *this* question — the list above is a prompt for your own creativity, not a
checklist. Brief each scout in your own words.

**What every scout must do:**
- Use ONLY the `lq-mcp` tools (with `source:chat` or `source:brain` as fits its angle). Never read the
  corpus from the local filesystem or from training knowledge — those are operator-only / wrong and
  would silently break the answer. If its tools error, return what it has and say so.
- **Return raw material, not a finished answer** — the actual quotes/notes with who-said-it and when,
  and the tension or pattern it noticed. You will do the synthesizing; a scout that hands back a tidy
  conclusion has thrown away the texture you need.
- Hunt for the non-obvious: chase disagreement over consensus, follow the thread that looks alive,
  don't stop at the first good-enough hit.

## Move 2 — Synthesize the insight (you)

Now read everything the scouts surfaced and form **your own conclusion**. This is the step that makes
or breaks the answer, so do the thinking yourself — do **not** staple the scout reports together or
write a section per scout.

A great answer:
- Says something true and non-obvious — a pattern, tension, or shift the member wouldn't have caught
  by skimming the channel. The sharp take that makes them glad they asked.
- Takes a position. Where the evidence points somewhere, say so plainly in your own voice — don't
  retreat into a neutral list of "perspectives."
- Connects dots across people, threads, and time that aren't connected on the surface.
- Triangulates: a claim several members converge on over weeks is real signal; a lone confident
  message is a lead, not a conclusion.

Lead with the insight. Cite the few messages or notes that carry it — skip provenance headers and
date-stamping; they add noise, not trust.

## The few things that keep it honest

- **Corpus, not memory.** Every claim grounded in what the tools returned. If the connector isn't
  present or comes back unauthorized, don't fan out into a dead connector — say so in one line and
  point the member to `/lq:start` (or the connector's Authenticate).
- **Chat is authoritative.** If chat and the vault seem to pull different ways, or you're unsure,
  trust the chat. Don't manufacture a contradiction between them — same community, synced together; a
  note's date is when something was *discussed*, not how fresh it is.
- **One voice isn't the room.** A single message is one member's take, not consensus — say it that
  way. The vault's notes are the synthesized position; don't put their words in a named person's mouth.
