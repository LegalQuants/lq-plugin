# BetaProfile schema — what /lq:update fills

Mirrors the real `legalquant` `types/beta-profile.ts` / `BetaProfileSchema` (`.strict()`),
`BETA_SCHEMA_VERSION = 1`. Render order = the 13 blocks below (each self-guards / may be omitted).
**[VOICE]** = authored, no citation. **[SPINE]** = earned, attach a `cite` (the renderer shows it as
an oxblood `▣ Channel#Lline` pill). A `cite` is a string (`"General#L5421"`, a date, or
`"members/builder-000.md"`) or `{label,url}` — or an array of those.

```jsonc
{
  "identity": {                         // masthead
    "memberNumber": "builder-000",      // required, the pseudo-id
    "profileDate": "June 2026",         // editorial dateline (optional)
    "displayName": "Jane Member",       // the SUBJECT's own name is fine; others stay builder-NNN
    "surnameItalic": true,              // render surname italic in the masthead (optional)
    "deck": "...",                      // [VOICE] standfirst under the name, max 600
    "portrait": { "url":"", "caption":"", "figNumber":"Fig. 1", "location":"London", "year":"2026" } // optional; omit url → initials medallion
  },
  "metaBand": { "based":"London", "role":"Legal Engineer", "practice":"Contract automation",   // [VOICE]
                "substack":{ "label":"Substack", "url":"https://..." }, "status":"Active" },
  "lede": "Opening paragraph(s). Drop-cap. Can be a string or array of paragraphs.", // [VOICE] max ~2000

  "sections": [ { "num":"01", "title":"...", "body":["para","para"], "cite":"General#L1234" } ], // [SPINE] body item max 4000
  "pullquotes": [ { "quote":"...", "cite":"AI Research#L88" } ],                    // [SPINE] quote max 600
  "projects": [ { "num":"01", "name":"Redline Copilot", "subLabel":"Web App",      // [SPINE]
                  "description":"...", "status":"Built|Shipped|Live", "cite":"members/builder-000.md > Ships" } ],
  "expertise": { "ranked":[ { "rank":1, "area":"Contract automation" } ], "caveat":"" },  // [SPINE] area max 160, rank 1-99
  "positions": [ { "marker":"§", "claim":"...", "support":"...", "cite":"Local Models#L502" } ], // [SPINE] claim max 600
  "stance": { "bearishOn":["..."], "bullishOn":["..."] },                          // [VOICE] items max 200
  "voice": [ { "quote":"their actual words from chat", "citation":"General#L5421 · 2026-05-30" } ], // [SPINE] quote max 800

  "texture": ["atmospheric aside", "..."],                                         // [VOICE] items max 600
  "sidebars": { "atAGlance":{ "rows":[{ "label":"Joined","value":"2025" }] },       // [VOICE]
                "emojiRegister":[{ "emoji":"⚖️","meaning":"..." }], "note":"" },
  "coda": { "label":"Deploy", "heading":"...", "narrative":"...",                  // [VOICE]
            "deployCards":[{ "icon":"→","title":"...","description":"..." }] },
  "colophon": { "provenance":"Drafted from this member's LegalQuants community record.",
                "restrictedTag":"Members only" },                                  // optional pill
  "audit": { "schemaVersion":1, "lastSuggestedAt":"2026-06-13" }
}
```

## Seeding intuition (deterministic map, no AI) — from the real `seedBetaFromClassic`

`identity` ← name/title/location/tagline/photo · `metaBand` ← location/role/substack ·
`lede` ← first bio paragraph · `sections` ← remaining bio paragraphs + Philosophy entries ·
`projects` ← Ships (status defaults `Built`). The rich SPINE fields (`pullquotes`, ranked
`expertise`, `positions`, `stance`, `voice` quotes, `texture`, `coda`) are **empty at seed** — they
fill only from cited evidence. That's exactly what `/lq:update` does: mine the chat for those, with a
citation on each.

## FieldChange shape (for --redline)

```jsonc
{ "path":"projects", "op":"set|append|replace", "zone":"spine|voice",
  "before": <current>, "after": <proposed>,
  "evidence": { "quote":"...", "url":"...", "channel":"Projects", "date":"2026-05-30" } }
```
Hard rule (matches the website gate): a **spine** change with no usable evidence (no quote/url) is
DROPPED, never kept. Voice changes are authored and need none.
