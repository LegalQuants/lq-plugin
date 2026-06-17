# lq — LegalQuants Claude Code plugin (v0.6.0)

One-install access to the LegalQuants community chat archive via MCP, with an "I know you"
cold-start and member sign-in.

## Install

```
/plugin marketplace add https://github.com/LegalQuants/lq-plugin.git
/plugin install lq@legalquants
```

> Use the full **HTTPS URL** above. The `owner/repo` shorthand clones over SSH and fails with `Host key verification failed` unless you've set up a GitHub SSH key — HTTPS needs no auth for this public repo.

## Member sign-in (native OAuth — no code, no token)

Use the connector's **Authenticate (native OAuth sign-in)** prompt. There's nothing to copy and no token
to paste: the connector opens LegalQuants sign-in in your browser, you sign in with the Google account on
your **published** LegalQuants profile, and the connector handles the access token for you. Then run
`/lq:start` (bare `/lq` works too — it's a kept alias) to get oriented.

Guests (no sign-in) read the corpus via a shared bearer token, without personalisation. To upgrade a guest
session, `/lq:start --signout` (or unset `LQ_MCP_TOKEN`) first, then use the connector's **Authenticate**.

### Legacy fallback (device-code)

For environments where the native Authenticate prompt isn't available:

```
/lq:start --signin
```

Shows a one-time code + **legalquants.com/device**; open it, enter the code, sign in with the Google
account on your **published** LegalQuants profile. A 7-day session is cached at `~/.config/lq/token.json`.
**Restart your session**, then run `/lq:start` (bare `/lq` works too — it's a kept alias).
`/lq:start --signout` clears your cached session.

## Included

- **`/lq:start`** — cold-start interview + personalised orientation ("I know you" for active members). Bare `/lq` is a kept alias that runs the same thing.
- **`/lq:ask`** — cross-source synthesis across both corpora.
- **`/lq:assess`** — assessment workflow for invited candidates.
- **`/lq:update`** — drafts your **Living Profile** from your own community footprint (everything you shipped + said) and renders it to a local page. Modes: from-scratch (default), `--redline` (a cited delta), `--member <builder-NNN>` (operator). Read-only + draft-only — nothing publishes.
- **`lq-mcp`** — one read-only connector over the community chat archive + synthesis vault (auto-registers via `.mcp.json`).
- Auto-loaded model guidance (recency bias, people-as-filter, anti-LQclaw-quoting).

## Not included

- No writes to the corpus (read-only) · no real-time ingest · no operator commands. (`/lq:update` writes only a profile draft to a local file on your machine — like `/lq:start`'s profile — never to the corpus.)

## Auth (how it works)

**Primary (native OAuth):** the connector's **Authenticate** runs `Google login → published profile →
access token`. The connector supplies that access token automatically on each request and handles refresh;
there's no cookie or token for you to manage. The lq-mcp server verifies the token **keylessly** (Google
public certs, no service-account key) and requires the `lqMember` claim that sign-in sets only after the
published-profile check. `/api/whoami` returns only *your* own builder ID + first-name greeting — never
another member's identity.

**Legacy fallback (device-code):** `/lq:start --signin` mints a **7-day Firebase session cookie** cached at
`~/.config/lq/token.json`, which the connector reads on each connection and verifies the same keyless way.

## Troubleshooting

- Commands missing → restart the session (slash commands load at start).
- Sign-in rejected → publish your legalquants.com profile, then run the connector's **Authenticate** again
  (or `/lq:start --signin` if you're on the legacy fallback).
- MCP 401 → run the connector's **Authenticate** again. (On the legacy device-code fallback, restart the
  session to load the cached cookie, or re-sign-in if the 7-day session expired.)

*Questions: j.tso@legalquants.com*
