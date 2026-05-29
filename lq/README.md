# lq — LegalQuants Claude Code plugin (v0.2.5)

One-install access to the LegalQuants community chat archive via MCP, with an "I know you"
cold-start and member sign-in.

## Install

```
/plugin marketplace add jamietso/lq-plugin
/plugin install lq@legalquants
```

## Member sign-in (Firebase device-code — no token to copy)

```
/lq --signin
```

Shows a one-time code + **legalquants.com/device**; open it, enter the code, sign in with the Google
account on your **published** LegalQuants profile. A 7-day session is cached at `~/.config/lq/token.json`.
**Restart your session**, then run `/lq`.

Guests (no sign-in) read the corpus via a shared bearer token, without personalisation.
`/lq --signout` clears your session.

## Included

- **`/lq`** — cold-start interview + personalised orientation ("I know you" for active members).
- **`/lq:assess`** — assessment workflow for invited candidates.
- **`lqchat-mcp`** — read-only MCP over the sanitized corpus (auto-registers via `.mcp.json`).
- Auto-loaded model guidance (recency bias, people-as-filter, anti-LQclaw-quoting).

## Not included

- No writes (read-only) · no real-time ingest · no operator commands · brain MCP is a later phase.

## Auth (how it works)

`Google login → published profile → builder ID → 7-day Firebase session cookie`. mcp-vercel verifies
the cookie **keylessly** (Google public certs, no service-account key) and requires the `lqMember`
claim that sign-in sets only after the published-profile check. `/api/whoami` returns only *your* own
builder ID + first-name greeting — never another member's identity.

## Troubleshooting

- Commands missing → restart the session (slash commands load at start).
- Sign-in rejected → publish your legalquants.com profile, then `/lq --signin` again.
- MCP 401 after sign-in → restart the session (loads the cached cookie), or re-sign-in if the 7-day session expired.

*Questions: jamietso@gmail.com*
