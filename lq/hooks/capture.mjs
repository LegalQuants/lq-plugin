#!/usr/bin/env node
/**
 * lq capture hook (Stop) — on-use session capture.
 *
 * Fires at the end of every Claude Code turn. It uploads the "triggering turn"
 * ONLY when that turn actually used an lq-mcp tool AND the member has recorded
 * consent — otherwise it exits silently. This is the disclosed, consented
 * enrichment that pairs with the server-side tool-call log: the server sees the
 * query + who; this adds the member's prompt and Claude's reply for turns where
 * they used LQ.
 *
 * Hard invariants:
 *   · No consent flag in the local profile  → do nothing (fail closed).
 *   · No lq-mcp tool call in the finished turn → do nothing.
 *   · Triggering turn only — never the whole transcript; corpus results are
 *     reduced to a char count (not their content).
 *   · ANY error → exit 0. This hook must never disrupt the member's session.
 */

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

// Where /lq:start writes the member's local profile (identity + consent marker).
const PROFILE = path.join(os.homedir(), ".claude", "plugins", "config", "legalquants", "lq", "CLAUDE.md");

// Capture ingest endpoint + its low-value key. The key is deliberately NOT the
// guest read bearer — it only authorizes capture POSTs. Overridable for tests.
const CAPTURE_URL = process.env.LQ_MCP_CAPTURE_URL ?? "https://mcp.legalquants.com/api/mcp/_capture";
const CAPTURE_KEY = process.env.LQ_CAPTURE_INGEST_KEY ?? "lq-capture-v1";

const MAX_TEXT = 20_000; // cap on user_prompt / assistant_reply
const LQ_TOOL = /lq[-_]?mcp/i; // matches mcp__…lq-mcp…__<tool> however it's namespaced
const TAIL_BYTES = 1_048_576; // only the last ~1MB of the transcript is read per turn

function die() {
  process.exit(0); // the only exit — success or handled failure, never disrupt
}

async function readStdin() {
  try {
    const chunks = [];
    for await (const c of process.stdin) chunks.push(c);
    return Buffer.concat(chunks).toString("utf8");
  } catch {
    return "";
  }
}

// Read only the tail of the transcript. The just-completed turn is always at the end,
// so on a long (multi-MB) session we avoid reading + parsing the whole file every turn.
// Drops the first (likely partial) line after a tail read so JSON.parse doesn't choke.
function readTranscriptTail(path) {
  const size = fs.statSync(path).size;
  if (size <= TAIL_BYTES) return fs.readFileSync(path, "utf8");
  const fd = fs.openSync(path, "r");
  try {
    const buf = Buffer.allocUnsafe(TAIL_BYTES);
    fs.readSync(fd, buf, 0, TAIL_BYTES, size - TAIL_BYTES);
    const text = buf.toString("utf8");
    const nl = text.indexOf("\n");
    return nl >= 0 ? text.slice(nl + 1) : text;
  } finally {
    fs.closeSync(fd);
  }
}

// Normalize a message's content into { text, toolUses:[{id,name,input}], toolResults:[{id,chars}] }.
function parseContent(content) {
  const out = { text: "", toolUses: [], toolResults: [] };
  if (typeof content === "string") {
    out.text = content;
    return out;
  }
  if (!Array.isArray(content)) return out;
  for (const block of content) {
    if (!block || typeof block !== "object") continue;
    if (block.type === "text" && typeof block.text === "string") {
      out.text += (out.text ? "\n" : "") + block.text;
    } else if (block.type === "tool_use") {
      out.toolUses.push({ id: block.id, name: block.name ?? "", input: block.input ?? {} });
    } else if (block.type === "tool_result") {
      const c = block.content;
      const chars = typeof c === "string" ? c.length : JSON.stringify(c ?? "").length;
      out.toolResults.push({ id: block.tool_use_id, chars });
    }
  }
  return out;
}

async function main() {
  // 1) Consent gate — no recorded consent ⇒ never capture.
  let profile;
  try {
    profile = fs.readFileSync(PROFILE, "utf8");
  } catch {
    return die();
  }
  if (!/capture_consent:\s*true/i.test(profile)) return die();

  const builderMatch = profile.match(/builder-\d+/i);
  const builder = builderMatch ? builderMatch[0].toLowerCase() : null;

  // 2) Hook input from stdin.
  let hook;
  try {
    hook = JSON.parse(await readStdin());
  } catch {
    return die();
  }
  const transcriptPath = hook?.transcript_path;
  const sessionId = hook?.session_id ?? null;
  if (!transcriptPath) return die();

  // 3) Parse the transcript (JSONL) — tail only.
  let lines;
  try {
    lines = readTranscriptTail(transcriptPath).split("\n").filter(Boolean);
  } catch {
    return die();
  }
  const records = [];
  for (const line of lines) {
    try {
      records.push(JSON.parse(line));
    } catch {
      /* skip malformed line */
    }
  }
  if (records.length === 0) return die();

  // 4) Isolate the just-completed turn: from the last genuine human prompt to end.
  //    A human prompt is a user record whose content carries text and NO tool_result
  //    (tool results are also role:"user" records — those don't start a turn).
  let startIdx = -1;
  for (let i = records.length - 1; i >= 0; i--) {
    const r = records[i];
    const role = r?.message?.role ?? r?.type;
    if (role !== "user") continue;
    const parsed = parseContent(r?.message?.content);
    if (parsed.toolResults.length === 0 && parsed.text.trim()) {
      startIdx = i;
      break;
    }
  }
  if (startIdx === -1) return die();

  const turn = records.slice(startIdx);
  const userPrompt = parseContent(turn[0]?.message?.content).text.slice(0, MAX_TEXT);

  // 5) Collect lq-mcp calls + their result sizes, and the final assistant reply.
  const resultChars = new Map(); // tool_use_id → chars
  const calls = [];
  let assistantReply = "";
  for (const r of turn) {
    const role = r?.message?.role ?? r?.type;
    const parsed = parseContent(r?.message?.content);
    if (role === "assistant") {
      if (parsed.text.trim()) assistantReply = parsed.text; // last non-empty wins → final reply
      for (const tu of parsed.toolUses) {
        if (LQ_TOOL.test(tu.name)) calls.push({ tool: tu.name, args: tu.input, id: tu.id });
      }
    } else if (role === "user") {
      for (const tr of parsed.toolResults) resultChars.set(tr.id, tr.chars);
    }
  }

  // 6) No LQ use in this turn ⇒ nothing to capture.
  if (calls.length === 0) return die();

  const payload = {
    builder,
    session_id: sessionId,
    ts: new Date().toISOString(),
    turn: {
      user_prompt: userPrompt,
      calls: calls.map((c) => ({ tool: c.tool, args: c.args, results_chars: resultChars.get(c.id) ?? 0 })),
      assistant_reply: assistantReply.slice(0, MAX_TEXT),
    },
  };

  // 7) Fire-and-forget upload with a hard timeout — never hang the session.
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 3000);
  fetch(CAPTURE_URL, {
    method: "POST",
    headers: { "content-type": "application/json", "x-lq-capture-key": CAPTURE_KEY },
    body: JSON.stringify(payload),
    signal: controller.signal,
  })
    .catch(() => {})
    .finally(() => {
      clearTimeout(timer);
      die();
    });
}

main().catch(() => die());
