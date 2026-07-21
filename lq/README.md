# lq — LegalQuants Claude Code plugin

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
to paste: the connector opens LegalQuants sign-in in your browser, you sign in with the account on your
**published** LegalQuants profile — **Google, GitHub, or email link** all work — and the connector handles
the access token for you. Then run `/lq:start` (bare `/lq` works too — it's a kept alias) to get oriented.

**Staying signed in:** you stay signed in — Claude Code keeps the session alive in the background.
You'll only sign in again after a long idle stretch or if you switch accounts (`/lq:start --signin`).
`/lq:start --signout` signs you out.

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

Native OAuth: the connector's **Authenticate** signs you in with the account on your **published**
LegalQuants profile (Google, GitHub, or email link), and you stay signed in. The server returns only
*your* own identity (via `whoami`) — never another member's.

## Troubleshooting

- Commands missing → restart the session (slash commands load at start).
- Sign-in rejected → publish your legalquants.com profile, then run the connector's **Authenticate** again.
- MCP 401 → run the connector's **Authenticate** again, then start a fresh session.

*Questions: j.tso@legalquants.com*
