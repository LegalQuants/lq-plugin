---
name: lq
description: Alias for the LegalQuants onboarding — runs the same flow as /lq:start. Use only when the user types bare /lq with no subcommand. For cross-source answers use /lq:ask, for the assessment use /lq:assess. Never invoke proactively.
---

# /lq — alias for /lq:start

Bare `/lq` is shorthand for the cold-start onboarding. **Follow `skills/start/SKILL.md`
exactly** — identical behavior and flags (`--signin`, `--signout`, `--redo`,
`--refresh-activity`). This alias exists only so `/lq` (which matches the plugin name)
keeps working now that the onboarding skill is named `start`; it adds no behavior of its own.
