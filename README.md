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

Sign-in is **native OAuth** through the `lq-mcp` connector — no code to type, no token to paste.

1. Run `/mcp`, select **lq-mcp**, and choose **Authenticate**.
2. Your browser opens the LegalQuants sign-in. Use whichever account your **published** profile
   uses — **Google, GitHub, or email link** — then click **Authorize**.
3. Back in Claude Code, run:

```
/lq:start
```

If your profile is published and linked, you'll get an "I know you" greeting derived from your chat
activity. Then just ask anything about the community.

You stay signed in — Claude Code refreshes the session silently in the background. `/lq:start --signin`
re-triggers sign-in (e.g. to switch accounts); `/lq:start --signout` signs you out.

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

`LegalQuants sign-in (Google / GitHub / email) → your published profile → a private builder ID → a
short-lived access token + rotating refresh token`. Claude Code stores the tokens securely (system
keychain) and refreshes them silently; the lq-mcp server verifies the access token **keylessly**
(against the site's public keys — no service-account key) and returns only your own builder ID +
first-name greeting. Your builder ID is never shown to other members.

## Troubleshooting

- **Commands don't appear after install** — restart your Claude Code session (slash commands load at start).
- **Sign-in rejected** — your LegalQuants profile must be **published**. Publish it at legalquants.com, then run the connector's **Authenticate** again (`/mcp` → lq-mcp).
- **MCP 401** — run the connector's **Authenticate** again (`/mcp` → lq-mcp), then start a fresh session.
- **Your terminal shows a short code to type at legalquants.com/device** — you're on an old plugin version. Run `/plugin update lq@legalquants`, restart the session, then Authenticate as above.

## Privacy

The corpus is **sanitized** — authors appear as stable `builder-NNN` pseudo-IDs, never real names.
Your sign-in tokens are your credential on your machine (system keychain); the server never reads your local files.

---

*Questions: j.tso@legalquants.com · Built by LegalQuants.*
