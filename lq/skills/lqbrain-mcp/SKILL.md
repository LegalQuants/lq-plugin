---
name: lqbrain-mcp
description: Use when lqbrain-mcp tools are available. The vault is LQBrain — the LegalQuants community's curated knowledge graph (wikilinked notes: insights, debates, projects, tools, people, events, MOCs, questions) synthesized from the chat. Read index.md + ask.md first. Brain answers SYNTHESIS/POSITION questions; lqchat-mcp answers ATTRIBUTION/RECENCY questions. Use traverse_graph to follow connections; MOCs are the densest hubs.
---

# lqbrain-mcp — knowledge-graph navigation

You have these tools over **LQBrain**: the community's *synthesized* second brain — evergreen notes connected by a `[[wikilink]]` graph. It is the **secondary-source** counterpart to `lqchat-mcp` (the primary-source chat).

**On a fresh session, read `index.md` first** (the catalog of all notes by category — the source of truth for what exists, so this guide doesn't go stale), then `ask.md` (how to query the vault).

## chat-MCP vs brain-MCP — route by question shape

| Question shape | Use |
|---|---|
| "What's the community's **position/take** on X?" "How do these ideas connect?" "Synthesize the thinking on Y" | **brain** (this) |
| "**Who said** X?" "**When** was X discussed?" "What's the **latest/current** word on X?" "quote me the message" | **chat** (`lqchat-mcp`) |

Brain is evergreen + opinion-stable; chat is verbatim + dated + attributable. For "what does the community think about local models," start in brain; for "who first proposed X and when," start in chat.

## The 5 tools

| Tool | Use for |
|---|---|
| `read(path_or_slug, line_range?)` | Read a note in full. Accepts a basename slug (`The Orchestration Layer`) or a path (`MOCs/...md`). A `[[X]]` wikilink resolves to `read("X")`. |
| `grep(query, scope?, path_glob?, ...)` | Search note contents → `<path>#L<line>`. `scope` = a note type (insights/debates/projects/tools/people/events/MOCs/questions). |
| `list(path?, glob?, frontmatter_filter?)` | Directory listing, OR Dataview-lite metadata query: `list({frontmatter_filter:{type:"insight", tags:["local-models"], status:"evergreen"}})`. |
| `traverse_graph(slug, depth?, direction?)` | Walk the wikilink graph → `{nodes, edges}`. `direction`: outgoing / incoming (backlinks) / both. depth 1–4. |
| `fetch_url(url, path?)` | Fetch a linked resource (GitHub API-routed). |

## Note types

`insights` (atomic claims) · `debates` (open tensions, multiple positions) · `projects` (member builds) · `tools` (software/products discussed) · `people` (member profiles) · `events` · `MOCs` (Maps of Content — curated hub notes) · `questions` (open questions).

## Three idioms that make answers good

### 1. Start at a MOC, then traverse
MOCs are the densest hubs — they curate a theme with linked sub-notes. For a broad topic: `grep` or `list` to find the relevant MOC, `read` it, then `traverse_graph(moc, depth=1, direction="outgoing")` to enumerate the connected notes. This beats scattered greps for "give me the landscape of X."

### 2. Use backlinks to find significance
`traverse_graph(slug, direction="incoming")` returns what links TO a note — a proxy for how central/contested an idea is. A note with many backlinks is load-bearing; cite it.

### 3. Synthesis, with debate awareness
When a topic has a `debates/` note, the community does **not** have one position — present the tension, not a false consensus. Don't flatten a debate into a single "the community thinks."

## Question-shape cascade

| Asker question | First tool call |
|---|---|
| "What's the thinking on [topic]?" | `grep("topic")` → find the MOC/insight → `read` → `traverse_graph` |
| "Map out everything on [theme]" | find the MOC, `read` it, then `traverse_graph(moc, depth=1)` |
| "Is [X] contested?" | `grep("X", scope:"debates")` |
| "What insights are tagged [tag]?" | `list({frontmatter_filter:{type:"insight", tags:["tag"]}})` |
| "How does [note] connect to the rest?" | `traverse_graph("note", depth=2, direction="both")` |
| "What links to [idea]?" (is it central?) | `traverse_graph("idea", direction="incoming")` |

## Conventions

- Cite notes by slug or `<path>#L<line>`. Prefer the human-readable slug ("see [[The Orchestration Layer]]").
- Brain notes are **synthesized opinion**, not verbatim quotes. For a direct quote or attribution, cross over to `lqchat-mcp`.
- People notes are real-name (the published member directory); the chat remains pseudonymized. Don't cross-contaminate — a brain `people/` note is the public profile, not chat attribution.
- Stop when you can cite 2–3 notes. Don't over-traverse.
