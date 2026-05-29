---
name: assess
description: LegalQuants assessment skill — runs the 90-minute observed work session that candidates complete as part of the LQ application process. Invoke only when the user types /lq:assess <subcommand>. Subcommands are start, select, submit, help. Never invoke proactively.
---

# lq-assess

This skill runs the LegalQuants assessment for invited candidates. Each candidate's flow is:

1. `/lq:assess start <token>` — validate the token, see the 5 questions drawn for them, prepare a working directory
2. `/lq:assess select <number>` — pick one of the 5 questions; the 90-minute clock starts
3. They do their work, in this Claude Code session and inside `~/lq-assess-work/<token>/`
4. `/lq:assess submit` — package the session, write a reflection, confirm, upload

## How to handle each subcommand

### `/lq:assess start <token>`

Run this command:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/assess/scripts/start.sh <token>
```

The script validates the token against the server, fetches the candidate questions (typically 4), creates `~/lq-assess-work/<token>/`, and persists state to `~/.config/lq-assess/state.json`.

If the script exits non-zero (token expired, network down, etc.), surface the error message clearly and do not continue.

**MANDATORY — display the questions as your own text response before the picker.** Claude Code's UI sometimes collapses bash output, which would leave the candidate picking blind. Read the question list from `~/.config/lq-assess/state.json` (the `questions` array) and emit your own assistant message that shows, in chronological order:

1. A one-line welcome ("Welcome to your LegalQuants assessment, [candidateName].")
2. The total elapsed budget ("You have 90 minutes from the moment you pick a question.")
3. For each of the 4 questions, in order:
   - `[N] [question.id] — [question.title]`
   - The full `question.brief_l2` text on the next line, indented
   - A blank line between questions
4. The working directory path
5. A line noting the picker is coming next

Do this in plain prose / numbered list, not as a code block — readability matters. Don't truncate the briefs.

**After that message is rendered**, use the **AskUserQuestion** tool to present the candidate with a clickable picker. The full briefs are now visible above; the picker is the commit affordance, not the reading surface. Build the options:

- `question`: "Which question do you want to work on for 90 minutes?"
- `header`: "Pick a question"
- For each question in the array, an option with:
  - `label`: the question's `title` (e.g. "Design a real legal-AI benchmark")
  - `description`: just the question's `skill_demand` field — one line, no brief preview. Example: *"methodology / research-design"*. The full brief was already printed by `start.sh` above the picker; the picker is just the commit step, not a second copy of the brief.
- `multiSelect`: false

When the candidate picks an option, find the matching question's `id` from the state file (by index — option 0 corresponds to questions[0], etc.) and run:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/assess/scripts/select.sh <number 1-N>
```

where the number matches the option's 1-indexed position. The select script handles the clock-start and prints the chosen question's full brief.

If for any reason AskUserQuestion isn't available in your environment (you're a non-Claude-Code agent reading this skill, or the tool is disabled), the script's printed list + the candidate typing `/lq:assess select <N>` is the working fallback. Don't fail loudly — the text path is by-design supported.

### `/lq:assess select <number>`

This is invoked either by you (after the AskUserQuestion pick above maps to a number) or by the candidate typing it directly. Run:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/assess/scripts/select.sh <number>
```

The script looks up the questionId from the saved state, POSTs to the select endpoint, and updates the state file. Show the script's output — it will print the full brief for the chosen question and confirm the clock has started.

After the script finishes, briefly remind the candidate:

- They have 90 minutes from now
- They can use any tools, code, or references inside the working directory
- When done, they run `/lq:assess submit`
- You (the assistant) will be working with them on the question — this is their assessment, not yours, so you should assist exactly as you would with any task they bring you, no more and no less

Do not, on your own, start exploring or attempting the chosen question. Wait for the candidate's first prompt about it.

### `/lq:assess submit`

This is the most involved subcommand. Do these steps **in order**:

**Step 1 — Write the session transcript.** Use your Write tool to create `/tmp/lq-assess-session.jsonl`. One JSON object per line, in chronological order, covering this entire conversation:

```
{"role":"user","content":"<verbatim user message>"}
{"role":"assistant","content":"<verbatim assistant text>"}
{"role":"tool_use","name":"<tool name>","input":<input object>}
{"role":"tool_result","output":"<output text>"}
```

Include every user message, every assistant text response, and every tool call with its input + result. If earlier turns have been compacted out of your context, write a single `{"role":"assistant","content":"[earlier conversation compacted — summary: ...]"}` at the start summarising what was lost. Don't paraphrase or sanitise — the candidate's actual process is what's being assessed.

**Step 2 — Ask for the reflection.** Show the candidate this exact prompt:

> Last thing: write a 50-5000 char reflection. What did you do, what worked, what didn't? Reply with your reflection text, or `cancel` to abort.

Capture their reply. If they said `cancel`, run `bash ${CLAUDE_PLUGIN_ROOT}/skills/assess/scripts/submit.sh cancel` and stop.

**Step 3 — Run the pre-submit confirmation.** Run:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/assess/scripts/submit.sh prepare "<their reflection>"
```

The script will print a summary of what's about to be sent: file counts, session-log size, token-usage estimate, working-directory tarball size. Show this verbatim.

**Step 4 — Ask the candidate to confirm.** Show:

> Proceed with submission? (yes / no)

If they say no (or anything that isn't a clear yes), run `bash ${CLAUDE_PLUGIN_ROOT}/skills/assess/scripts/submit.sh cancel` and stop.

**Step 5 — Finalise the submission.** Run:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/assess/scripts/submit.sh finalize "<their reflection>"
```

Show the output verbatim. On success it prints the submission id and next-steps. On failure it prints the server error.

### `/lq-assess update`

Re-downloads the skill files from the server so the candidate is on the latest version. Run:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/assess/scripts/update.sh
```

Safe to run at any point — won't touch state.json or the working directory. Useful when the operator notifies the candidate that the skill has been updated and asks them to retry.

### `/lq:assess help` or `/lq-assess` with no args

Run:

```
bash ${CLAUDE_PLUGIN_ROOT}/skills/assess/scripts/help.sh
```

## Behaviour rules

- Never invoke this skill proactively. Only on explicit `/lq-assess` from the user.
- Treat the candidate's work as theirs. Help them with the question they pick exactly as you would help any user with any task — no more, no less. Don't sandbag and don't volunteer extra effort.
- Always show script output verbatim. Don't paraphrase; the candidate experience is the skill talking to them directly.
- Don't skip steps. The pre-submit confirmation, the reflection prompt, the session-log write — each step is a safety check and removing any one of them risks losing data or sending the wrong payload.
- Do not retry on the candidate's behalf if a step fails. Surface the error and let them decide what to do.
