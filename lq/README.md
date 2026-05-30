# lq — LegalQuants Claude Code plugin (v0.5.4)

One-install access to the LegalQuants community chat archive via MCP, with an "I know you"
cold-start and member sign-in.

## Install

```
/plugin marketplace add https://github.com/LegalQuants/lq-plugin.git
/plugin install lq@legalquants
```

> Use the full **HTTPS URL** above. The `owner/repo` shorthand clones over SSH and fails with `Host key verification failed` unless you've set up a GitHub SSH key — HTTPS needs no auth for this public repo.

## Member sign-in (Firebase device-code — no token to copy)

```
/lq:start --signin
```

Shows a one-time code + **legalquants.com/device**; open it, enter the code, sign in with the Google
account on your **published** LegalQuants profile. A 7-day session is cached at `~/.config/lq/token.json`.
**Restart your session**, then run `/lq:start` (bare `/lq` works too — it's a kept alias).

Guests (no sign-in) read the corpus via a shared bearer token, without personalisation.
`/lq:start --signout` clears your session.

## Included

- **`/lq:start`** — cold-start interview + personalised orientation ("I know you" for active members). Bare `/lq` is a kept alias that runs the same thing.
- **`/lq:ask`** — cross-source synthesis across both corpora.
- **`/lq:assess`** — assessment workflow for invited candidates.
- **`lq-mcp`** — one read-only connector over the community chat archive + synthesis vault (auto-registers via `.mcp.json`).
- Auto-loaded model guidance (recency bias, people-as-filter, anti-LQclaw-quoting).

## Not included

- No writes (read-only) · no real-time ingest · no operator commands.

## Auth (how it works)

`Google login → published profile → builder ID → 7-day Firebase session cookie`. The lq-mcp server verifies
the cookie **keylessly** (Google public certs, no service-account key) and requires the `lqMember`
claim that sign-in sets only after the published-profile check. `/api/whoami` returns only *your* own
builder ID + first-name greeting — never another member's identity.

## Troubleshooting

- Commands missing → restart the session (slash commands load at start).
- Sign-in rejected → publish your legalquants.com profile, then `/lq:start --signin` again.
- MCP 401 after sign-in → restart the session (loads the cached cookie), or re-sign-in if the 7-day session expired.

*Questions: jamietso@gmail.com*
