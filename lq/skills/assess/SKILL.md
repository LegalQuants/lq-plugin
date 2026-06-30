---
name: assess
description: LegalQuants assessment launcher — bootstraps and runs the 90-minute observed work session candidates complete for the LQ application. Invoke only when the user types /lq:assess <subcommand> (start, select, submit, help). Never invoke proactively.
---

# lq:assess (launcher)

This is a **thin launcher**. The real LegalQuants assessment skill — all question
handling, the picker, the submission/collection logic — is deliberately **not bundled
here**. It installs on demand from the LegalQuants server into
`~/.claude/skills/lq-assess/` and runs from there. This keeps the assessment's
collection scripts and method out of this public plugin repo; the single source of
truth lives server-side.

## On every `/lq:assess <subcommand>`

1. **Ensure the skill is installed.** If `~/.claude/skills/lq-assess/SKILL.md` does not
   exist, install it from the candidate's tokenized invite link. When the user ran
   `/lq:assess start <token>`, install with that token:

   ```
   curl -fsSL "https://assess.legalquants.com/install?token=<token>" | sh
   ```

   The download is gated, so a valid token is required. If no token is available yet —
   e.g. a bare `/lq:assess` or `/lq:assess help` before installing — tell them to run
   `/lq:assess start <token>` with the token from their invitation email. If the install
   fails (no network, or a missing dependency such as `jq` / `node`), surface the error
   verbatim and stop — do not improvise the flow.

2. **Delegate to the installed skill.** Read `~/.claude/skills/lq-assess/SKILL.md` and
   follow its instructions exactly for the requested subcommand, treating
   `/lq:assess <subcommand>` as equivalent to `/lq-assess <subcommand>`. Its scripts
   live in `~/.claude/skills/lq-assess/scripts/`. Always show script output verbatim.

Subcommands: `start <token>`, `select <number>`, `submit`, `help`
(plus `update` to re-download the latest installed copy from the server).

## Behaviour rules

- Never invoke proactively — only on an explicit `/lq:assess` from the user.
- Do **not** reimplement the assessment flow here. The installed skill is the single
  source of truth for behaviour; if it's missing, install it (step 1) rather than
  guessing at the steps.
- The draw size, question briefs, and submission mechanics are all owned by the
  installed skill + the server — this launcher intentionally knows none of them.
