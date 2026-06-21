# Classic profile — schema & FieldChange contract

What `/lq:update` emits when updating a member's **classic** LegalQuants profile (the `Lawyer`
data model rendered at `legalquants.com/lawyers/{slug}`). Claude produces **structured
`FieldChange`s** that already fit this schema; the website validates them deterministically (shape,
field allowlist, third-party-name scan) and stores a pending proposal the member reviews and
publishes. There is no server-side LLM — the changes you emit here are exactly what the member
reviews, so they must be correct and conformant.

## Editable fields (the ONLY allowed `path` roots)

A `FieldChange` whose `path` root is not in this list is refused by the server.

**Scalar (string) fields** — `op:'set'`, `after` = the new string:
- `name` · `bio` · `tagline` · `title` · `location`
- `linkedin` · `substack` · `github` · `appsUrl` (full **https** URLs; `appsUrl` = the member's
  apps / portfolio / store link)

**Array fields** — see ops below; element shapes:
- `projects` — `{ id, title, description, platform, accessType?, demoUrl?, github?, releasePostUrl?, youtubeId?, vimeoId?, videoUrl?, screenshot? }`
  - `platform` ∈ `Web App | Chrome Extension | Word Add-In | API | Desktop App | Mobile App | Library | Other` (or a custom string)
  - `accessType` ∈ `Open Source | Open Access`
  - `id` — a stable kebab/slug id you generate from the title (e.g. `global-ai-regulation-tracker`)
- `media` — `{ outlet, title, url, description? }`
- `philosophy` — `{ name, body }`  (`name` = the principle/quote, `body` = the explanation)

**Don't emit these:** `slug`, `batch`, `status`, `visible`, rank/cohort/system fields — the server
rejects them. Two more the server *allows* but the skill should **not** draft:
- `profilePhoto` — photos and local files are uploaded by the member on the website review screen, not here.
- `highlights` — invisible `{label,value}` search tags that don't render on the profile (they only feed
  directory search). Out of scope for `/lq:update`; the member curates those in the website editor.

## The `FieldChange` object

```jsonc
{
  "path": "projects",                 // a root field from the list above
  "op": "set" | "append" | "replace",
  "before": <current value | null>,   // what's there now (for the member's diff view)
  "after": <new value>,               // see op semantics
  "evidence": { "quote"?, "url"?, "imageUrl"?, "channel"?, "date"? }  // REQUIRED — see below
}
```

### `op` semantics (exact — server applies it this way)
- **`append`** (arrays only): `after` is **ONE new element** (a single project/media/philosophy
  object). The server reads the current array and pushes it. Use this to ADD an item.
- **`set`**: `after` **replaces the whole field**. For a scalar (bio, tagline…) `after` is the new
  string. For an array, `after` is the **entire new array** (only when genuinely rewriting the list).
- **`replace`**: same as `set` (whole-field replace); prefer `set` for clarity.

> To add a project, do NOT send the whole `projects` array — send one `append` with the new project
> as `after`. To fix a typo in the bio, send one `set` on `bio`.

### Evidence (REQUIRED on every change)
Every `FieldChange` must carry usable evidence — at least one of `quote`, `url`, or `imageUrl`. A
change with none is dropped server-side and never reaches the member. Any `url` / `imageUrl` in
evidence must be **https** (the server rejects non-https with a 422).
- **Member-supplied** ("here's my new project"): evidence is the member's own material — the
  `demoUrl`/`github`/release `url`, or a `quote` of what they told you.
- **Community footprint**: evidence is the chat `quote` + `channel` + `date` it came from.
- Never invent evidence. If you can't ground a change, don't emit it.

## Hard rules
- **No third-party real names** anywhere in `after` or `evidence` — not the member's own profile.
  The server name-scans and will reject; don't put another member/person's real name in.
- **Plain text only** (no HTML/markdown markup in field values).
- **Cite, don't pad.** Emit a change only when the evidence supports it.
- **Exclude the LQClaw bot** as a source when reading the corpus.

## Examples

Add a project the member just described (with links):
```jsonc
{ "path": "projects", "op": "append",
  "before": null,
  "after": { "id": "contract-redline-bot", "title": "Contract Redline Bot",
    "description": "Chrome extension that flags risky clauses inline during review.",
    "platform": "Chrome Extension", "accessType": "Open Access",
    "demoUrl": "https://chrome.google.com/webstore/detail/...",
    "github": "https://github.com/u/redline-bot" },
  "evidence": { "url": "https://github.com/u/redline-bot",
    "quote": "Just shipped a redline bot — repo + store link." } }
```

Tighten the bio:
```jsonc
{ "path": "bio", "op": "set",
  "before": "Lawyer interested in tech.",
  "after": "Tech lawyer who ships: built a clause-risk Chrome extension used across two firms.",
  "evidence": { "quote": "built a clause-risk extension now used at two firms", "channel": "general", "date": "2026-06-12" } }
```

Add a media appearance:
```jsonc
{ "path": "media", "op": "append", "before": null,
  "after": { "outlet": "Lawyers Weekly", "title": "30 Under 30: Legal Tech", "url": "https://...",
    "description": "Recognised for legal-engineering work." },
  "evidence": { "url": "https://..." } }
```
