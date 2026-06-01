# LegalQuants — Claude Code plugin

AI access to the **LegalQuants community knowledge** from your terminal — both the raw **chat archive**
*and* a curated **synthesis vault**. Ask natural questions across everything, and — if you're a member —
get a personalised experience that knows *your* contributions.

> Members-only. You need a **published LegalQuants profile** (legalquants.com) to sign in.

---

## Install

In Claude Code:

```
/plugin marketplace add https://github.com/LegalQuants/lq-plugin.git
/plugin install lq@legalquants
```

> Use the full **HTTPS URL** above. The `owner/repo` shorthand clones over SSH and fails with `Host key verification failed` unless you've set up a GitHub SSH key — HTTPS needs no auth for this public repo.

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
/lq:start
```

If your profile is published and linked, you'll get an "I know you" greeting derived from your chat
activity. Then just ask anything about the community.

`/lq --signout` clears your session.

---

## What you get

- **`/lq:start`** (bare `/lq` is a kept alias) — cold-start interview + personalised orientation. Active
  members get an "I know you" greeting (no questions); quieter/guest members get a short interview. A plain
  question spans both corpora automatically — results are labelled by source.
- **`/lq:ask "<question>"`** — cross-source synthesis: fans out over *both* sources in parallel and merges
  into one cited answer. Use for "what's the community's take on X — and where's it from / what's the
  latest?"
- **`/lq:assess`** — assessment workflow (for invited candidates).
- **One connector** (`lq-mcp`) over the community chat archive + curated synthesis vault — read-only; one
  sign-in covers it. Tools take `source: chat | brain | all` (default `all`), so you don't pick a corpus up
  front; a plain query spans both and results are labelled by source.
- **Auto-loaded guidance** — one skill priming the model on the corpus's idioms.

## What it does NOT do

- No writes — `lq-mcp` is read-only.
- No real-time ingest — chat is a sanitized snapshot; the brain vault is rebuilt periodically by operators.
- Never exposes another member's identity — `/api/whoami` returns only *your* own.

---

## How sign-in works (under the hood)

`Google login → your LegalQuants profile → a private builder ID → a 7-day Firebase session cookie`.
The cookie carries your identity as Firebase custom claims; the lq-mcp server verifies it **keylessly** (against
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

*Questions: j.tso@legalquants.com · Built by LegalQuants.*
