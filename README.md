# LegalQuants — Claude Code plugin

AI access to the **LegalQuants community knowledge** from your terminal — both the raw **chat archive**
*and* a curated **synthesis vault**. Ask natural questions across everything, and — if you're a member —
get a personalised experience that knows *your* contributions.

> Members-only. You need a **published LegalQuants profile** (legalquants.com) to sign in.

---

## Install

In Claude Code:

```
/plugin marketplace add LegalQuants/lq-plugin
/plugin install lq@legalquants
```

## Sign in (members)

```
/lq --signin
```

This starts a Google sign-in via a one-time device code:

1. The plugin shows a short code (e.g. `ABCD-EFGH`) and the link **https://www.legalquants.com/device**.
2. Open the link, enter the code, and sign in with the **Google account on your LegalQuants profile**.
3. The plugin caches a 7-day session locally (`~/.config/lq/token.json`, mode 0600) — no password or
   token to copy by hand.

**Restart your Claude Code session** so it picks up the sign-in, then:

```
/lq
```

If your profile is published and linked, you'll get an "I know you" greeting derived from your chat
activity. Then just ask anything about the community.

`/lq --signout` clears your session.

---

## What you get

- **`/lq`** — cold-start interview + personalised orientation. Active members get an "I know you"
  greeting (no questions); quieter/guest members get a short interview. Routes your question to the
  right corpus automatically.
- **`/lq:ask "<question>"`** — cross-corpus synthesis: fans out to *both* MCPs in parallel and merges
  into one cited answer. Use for "what's the community's take on X — and where's it from / what's the
  latest?"
- **`/lq:assess`** — assessment workflow (for invited candidates).
- **Two MCP servers** (auto-register; one sign-in covers both):
  - **`lqchat-mcp`** — primary-source chat (`read`, `grep`, `list`, `scan_thread`, `read_attachment`, `fetch_url`).
  - **`lqbrain-mcp`** — the synthesis vault (~707 wikilinked notes: insights, debates, projects, tools,
    people, MOCs) — `read`, `grep`, `list`, `traverse_graph`, `fetch_url`.
- **Auto-loaded guidance** — primes the model on each corpus's idioms + chat-vs-brain routing.

## What it does NOT do

- No writes — both MCPs are read-only.
- No real-time ingest — chat is a sanitized snapshot; the brain vault is rebuilt periodically by operators.
- Never exposes another member's identity — `/api/whoami` returns only *your* own.

---

## How sign-in works (under the hood)

`Google login → your LegalQuants profile → a private builder ID → a 7-day Firebase session cookie`.
The cookie carries your identity as Firebase custom claims; the MCP verifies it **keylessly** (against
Google's public certs — no service-account key) and returns only your own builder ID + first-name
greeting. Your builder ID is never shown to other members.

Guests (no member sign-in) can still read the corpus via a shared bearer token, without
personalisation.

## Troubleshooting

- **Commands don't appear after install** — restart your Claude Code session (slash commands load at start).
- **Sign-in rejected** — your LegalQuants profile must be **published**. Publish it at legalquants.com, then `/lq --signin` again.
- **MCP 401 after sign-in** — restart the session so the cached cookie loads; or re-run `/lq --signin` if your 7-day session expired.

## Privacy

The corpus is **sanitized** — authors appear as stable `builder-NNN` pseudo-IDs, never real names.
Your cached session cookie is your credential on your machine; the server never reads your local files.

---

*Questions: jamietso@gmail.com · Built by LegalQuants.*
