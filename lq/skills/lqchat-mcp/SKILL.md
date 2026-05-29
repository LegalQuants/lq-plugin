---
name: lqchat-mcp
description: Use when lqchat-mcp tools are available. The corpus is a sanitized knowledge base of a lawyer-builder community. Navigate it by reading README + GLOSSARY first, then grep / read / list. Three idioms matter most: recency bias for "current take" questions, people-as-filter via stable Member-XX-NN pseudo-IDs, and never quoting LQclaw bot as a community position.
---

# lqchat-mcp — knowledge corpus navigation

You have 6 tools over a sanitized corpus of the LegalQuants community (chat history, member profiles with their shipped projects, attachments).

**Always read `README.md` first** on any new session — it explains the layout and conventions.
**Always read `GLOSSARY.md`** when asker uses a project name or jargon term you don't recognize.

## The 6 tools

| Tool | Use for |
|---|---|
| `read(path, line_range?)` | Read any file. README, GLOSSARY, member profiles, chat (with line_range). |
| `grep(query, scope?, path_glob?, ...)` | Search content. scope = "chat" \| "members" \| "all" (default). |
| `list(path?, glob?)` | Directory listing with size + frontmatter title summary. |
| `scan_thread(channel, anchor_line)` | After a chat grep hit — get the conversation around it (adaptive temporal expansion). |
| `read_attachment(reference)` | Read PDFs/DOCX/images by ID. |
| `fetch_url(url, path?)` | External URLs (GitHub API-routed). |

## Layout

```
README.md            — orientation, conventions, where to start
GLOSSARY.md          — project → owner, jargon, channel focus, name resolution
channels/<Name>.txt  — 14 raw sanitized chat files
members/<pid>.md     — 152 member files (rtdb bio + ships embedded)
attachments/<id>.md  — 73 extracted PDF/DOCX/MD text files
```

## Three idioms that make answers good

### 1. Recency bias

Chat is timeline data. People change their minds. For "what's the current take" / "latest position" / "where does the community stand" questions:

- Get hits across all time via `grep`, then **sort by date desc** before reading
- Weight the most recent 5–10 hits heavier than older ones
- Don't average across 6 months when only the last week matters
- Explicitly say "as of [latest hit date]" — positions evolve

The corpus has a hard discontinuity: `General` jumps from Nov 2025 (group creation) to Mar 14 2026 in older content. If a topic spans both eras, treat them as distinct contexts, not a continuous arc.

### 2. People-as-filter

Members are stable `Member-XX-NN` pseudo-IDs. Use this for two patterns:

**Find everything one person said about a topic:**
```
grep("\\] Member-XX-NN: .*<topic>", scope: "chat", regex: true)
```
Then `scan_thread` on the most interesting hit for context.

**Map a real first name to a pseudo-ID:**
```
grep("Awais", path_glob: "members/*.md")
```
Member bios consent-include first names. The chat itself is fully anonymized.

**Pivot from project to person:**
Project ownership lives in member files under `## Ships`. To find who built project X, `grep("X", scope: "members")` first.

### 3. Never quote LQclaw as community position

LQclaw is the in-channel bot. Its messages are excluded by default (`include_bots: false`).

- **Never** present LQclaw's words as "the community thinks" or "members said"
- LQclaw is the comparison target for the answer-quality benchmark — circular-retrieval kills the benchmark's integrity
- Only set `include_bots: true` when the asker is specifically asking about the bot's prior behavior ("what did LQclaw answer when X was asked?")

If you find yourself attributing a position to LQclaw, stop. That's a bot answer, not a community position.

## Question-shape cascade

| Asker question | First tool call |
|---|---|
| "What has Member-X shipped?" | `read("members/Member-XX-NN.md")` |
| "Has anyone built X?" | `grep("X", scope: "members")` |
| "Tell me about [project]" | `read("GLOSSARY.md")` to find owner, then `read("members/<owner>.md")` and jump to `### [project]` |
| "Who's the [region/role] person?" | `grep("region/role keyword", scope: "members")` |
| "What did Member-X say about Y?" | `grep("\\] Member-XX-NN: .*Y", scope: "chat", regex: true)` then `scan_thread` on a hit |
| "What's the latest on [topic]?" | `grep("topic", scope: "chat")`, sort hits by date desc, take top 5–10, scan_thread each |
| "Where does the community stand on X?" | Same as "latest on X" — recency wins over averaging |
| Asker uses a real first name like "Awais" | `grep("Awais", path_glob: "members/*.md")` — bios consent-include first names |

## Conventions

- Members are always `Member-XX-NN` (pseudo-IDs). Never invent or guess real names.
- Use role descriptors when no pseudo-ID is in context ("a UAE avocat", "a UK litigation partner").
- Citations:
  - Chat: `<Channel>#L<line>` — e.g. `General#L5421`
  - Member files: `members/<pseudo-id>.md` — e.g. `members/Member-AK-01.md`
  - Project (embedded in member file): `members/<pseudo-id>.md > Ships > <Project Name>`
- Default excludes bots. Set `include_bots: true` only when asker is specifically asking about the LQclaw bot's history.

## Stop when you can cite

If you can name 2–3 specific records that support your answer, that's enough. Don't run more searches for confirmation theater.
