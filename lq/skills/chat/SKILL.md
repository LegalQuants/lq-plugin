---
name: chat
description: |
  DEPRECATED in v0.2. /lq:chat now redirects to /lq (the cold-start interview).
  This shim exists to avoid breaking v0.1 users who still type /lq:chat from muscle memory.
  Removed in v0.4. Run when the user types /lq:chat.
---

# /lq:chat — DEPRECATED, redirects to /lq

This skill is a deprecation shim. In v0.2, the `/lq` cold-start interview replaced both `/lq:chat` (chat onboarding) and the planned `/lq:brain` (brain onboarding). Members no longer pick MCPs — they pick by intent.

## How to handle `/lq:chat`

Emit this one-line message:

```
/lq:chat is deprecated in plugin v0.2. The single entry point is now /lq —
it auto-routes between chat (raw) and brain (synthesis, coming v0.3) based on
your question's shape. Running /lq for you now…
```

Then invoke the `lq` skill (the cold-start interview) as if the user had typed `/lq`. Follow that skill's flow completely.

## Removal timeline

This shim stays in plugin versions:
- **v0.2** (current) — surfaces deprecation message + auto-redirects to `/lq`
- **v0.3** — same; deprecation message becomes more prominent
- **v0.4** — REMOVED. Members who type `/lq:chat` get "command not found"

## Why deprecated

In v0.1, `/lq:chat` was the chat MCP's onboarding command. The pattern leaked internal MCP architecture into member UX — members shouldn't have to know whether to invoke chat MCP or brain MCP; they should just ask their question and let the model route.

The v0.2 `/lq` cold-start collapses this: single entry point, intent-shaped (not MCP-shaped), and for known active members it skips the interview entirely with an "I know you" greeting derived from their corpus activity.
