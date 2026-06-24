---
name: share
description: |
  Share a learning with the LegalQuants community. Run when the user types /lq:share
  (optionally with a one-liner: /lq:share "<what you figured out>"). Composes a short, first-person
  field note from the session — a title + the finding in the member's own words + an optional tag —
  shows the member the EXACT text that will post to the members-only #lq-share WhatsApp channel,
  waits for ONE explicit confirmation, then queues it via the submit_learning tool. LQClaw relays it
  verbatim within minutes; there are no take-backs, so the confirm is the gate. LQ-members only
  (guests are rejected). Falls fast to /lq:start when the connector isn't reachable. Never invoke
  proactively.
---

# /lq:share — share what you just figured out, with your people

Learnings are born while you build and die in the WhatsApp scroll. `/lq:share` captures one where it
happens and routes it into the members-only **#lq-share** channel — a first-person field note ("I used
X for Y because…"), not a universal verdict. It lives where the tribe already is, and flows into the
community corpus on the normal weekly ingest.

## When this is the right tool
- ✅ "I just figured out / I tried X and it worked — share it."  ·  `/lq:share "<one-liner>"`
- ❌ A question about the community → `/lq:ask`.
- ❌ Editing the vault or correcting a past answer → out of scope (v1).

## Step 0 — Pre-flight: connector reachable + LQ membership (BEFORE composing)
1. **Tools present?** Check for the lq-mcp tools (`whoami` and `submit_learning`). If you see a native
   **Authenticate** action but no tools yet, the connector IS wired — the member just hasn't signed in:
   tell them to run **Authenticate (native OAuth)**, then re-run `/lq:share`. Treat it as absent only
   when no LegalQuants tool exists.
2. **Signed-in member?** Run `whoami`. On an auth error (401 / OAuth prompt) → run Authenticate. If it
   returns anonymous (not a signed-in member) → `/lq:share` is members-only; route to `/lq:start` and
   STOP (the server rejects guest submits anyway).
3. Only if `whoami` returns a real identity → proceed.

### Not connected — fail fast, route to /lq:start
> I can't reach the LegalQuants connector — looks like you're not connected yet. Run the
> **Authenticate** action for lq-mcp (native OAuth), or **`/lq:start`**, then re-run `/lq:share`.

## Step 1 — Compose the learning
From this build session (and any `/lq:share` one-liner argument), draft:
- **title** — short.
- **text** — the finding in the member's OWN words, 1–4 sentences, first person.
- **tag** — optional (a tool or topic).
Keep it plain text. No client names, no privileged detail. (Optional, only if the member asks: fold in
their own footprint via `grep`/`scan_thread` — and always exclude the LQClaw bot.)

## Step 2 — Pick the byline, show the EXACT post, then STOP (do not submit yet)
Ask how they want to be credited (default = named):
- **Named** → `💡 <FirstName> shared — <title>`
- **Anonymous** → `💡 An LQ member shared — <title>` (their name is never shown; the system still
  knows it's them, so it stays members-only — they just don't appear by name to the group)

Render the literal message that will post to #lq-share, using the chosen byline:

    💡 <FirstName | "An LQ member"> shared — <title>
    <text>  [#tag if provided]

Privacy nudge: "This posts to the whole LQ group — no client names or privileged detail."
Then ask explicitly and WAIT: *"Post this to #lq-share as <byline>? It goes to the whole group within
minutes and there's no take-back, so I won't send anything until you say go."* Do NOT call
`submit_learning` until the member clearly approves. Iterate in chat as many rounds as they like
(wording, tag, named-vs-anonymous) — every round is free, the group sees nothing until the single yes.

## Step 3 — Queue it (after the explicit yes)
Call ONE tool (pass `anonymous: true` only if they chose the anonymous byline):

    submit_learning({ title, text, tag?, anonymous? })

The tool carries the member's identity (builder + first name) from the verified sign-in server-side —
you never pass a name/id and never handle a token. With `anonymous: true` the server drops the name
(posts as "An LQ member") but still records the pseudonymous builder id. Handle the result:
- **ok / queued** → flowing prose: "Queued — LQClaw will post it to #lq-share in a few minutes."
- **auth / not-a-member** (401/403) → re-auth via Authenticate, or `/lq:start`.
- **other failure** → a brief generic error; suggest retry. Never echo any credential.

## Conventions
- No client names, privileged detail, or third-party real names — the member's own name is the byline (fine), unless they choose anonymous.
- Exclude the LQClaw bot as a corpus/footprint source.
- One learning per run; LQClaw relays it verbatim under the member's chosen byline (their name, or "An
  LQ member" if anonymous). The confirm before send is the only gate before it's live in WhatsApp —
  there are no take-backs.
- No founder/org-strategy framing in member-facing copy. Never invoke proactively — only on `/lq:share`.
