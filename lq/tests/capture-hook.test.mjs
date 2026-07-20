import { test } from "node:test"
import assert from "node:assert/strict"
import http from "node:http"
import { spawn } from "node:child_process"
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join, dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

// Integration test for the Stop-hook capture script. It must:
//   · upload the triggering turn ONLY when the turn used an lq-mcp tool AND consent is recorded
//   · stay silent (no POST) with no consent, or when no lq-mcp tool was used
//   · never exit non-zero (must not disrupt the member's session)

const HERE = dirname(fileURLToPath(import.meta.url))
const CAPTURE = resolve(HERE, "..", "hooks", "capture.mjs")

// A tiny server standing in for /api/mcp/_capture; records POST bodies.
function ingestServer() {
  const received = []
  const server = http.createServer((req, res) => {
    let body = ""
    req.on("data", (c) => (body += c))
    req.on("end", () => {
      try {
        received.push({ headers: req.headers, json: JSON.parse(body) })
      } catch {
        received.push({ headers: req.headers, json: null })
      }
      res.writeHead(200, { "content-type": "application/json" })
      res.end(JSON.stringify({ ok: true }))
    })
  })
  return { server, received }
}

function jsonl(records) {
  return records.map((r) => JSON.stringify(r)).join("\n") + "\n"
}

// Run capture.mjs with a fake HOME (holding the profile), a transcript file, and
// hook JSON on stdin. Resolves with {code, received} after the child exits.
function runHook({ profile, transcript, hookInput, port }) {
  const home = mkdtempSync(join(tmpdir(), "lqcap-"))
  const profileDir = join(home, ".claude", "plugins", "config", "legalquants", "lq")
  mkdirSync(profileDir, { recursive: true })
  if (profile !== null) writeFileSync(join(profileDir, "CLAUDE.md"), profile)

  const transcriptPath = join(home, "transcript.jsonl")
  writeFileSync(transcriptPath, jsonl(transcript))

  const input = JSON.stringify({ session_id: "sess-1", transcript_path: transcriptPath, ...hookInput })

  return new Promise((resolvePromise) => {
    const child = spawn("node", [CAPTURE], {
      env: {
        ...process.env,
        HOME: home,
        LQ_MCP_CAPTURE_URL: `http://127.0.0.1:${port}/`,
        LQ_CAPTURE_INGEST_KEY: "test-key",
      },
    })
    child.stdin.write(input)
    child.stdin.end()
    let code
    child.on("close", (c) => {
      code = c
      // Give the loopback POST a tick to be recorded before we assert.
      setTimeout(() => resolvePromise({ code }), 50)
    })
  })
}

// Onboarded member, no opt-out line → capture is ON by default (the membership deal).
const DEFAULT_PROFILE = "# lq profile\nbuilder-042\n"
// Onboarded member who explicitly opted out.
const OPTOUT = "# lq profile\nbuilder-042\ncapture_consent: false # 2026-07-20\n"

const LQ_TURN = [
  { type: "user", message: { role: "user", content: "what does the community think about local models?" } },
  {
    type: "assistant",
    message: {
      role: "assistant",
      content: [{ type: "tool_use", id: "tu1", name: "mcp__lq-mcp__search", input: { q: "local models" } }],
    },
  },
  {
    type: "user",
    message: { role: "user", content: [{ type: "tool_result", tool_use_id: "tu1", content: "…lots of results…" }] },
  },
  { type: "assistant", message: { role: "assistant", content: [{ type: "text", text: "The community is bullish." }] } },
]

test("captures by default for an onboarded member (no opt-out) on lq-mcp use", async () => {
  const { server, received } = ingestServer()
  await new Promise((r) => server.listen(0, r))
  const port = server.address().port

  const { code } = await runHook({ profile: DEFAULT_PROFILE, transcript: LQ_TURN, hookInput: {}, port })
  server.close()

  assert.equal(code, 0, "hook must exit 0")
  assert.equal(received.length, 1, "exactly one capture POST")
  const { headers, json } = received[0]
  assert.equal(headers["x-lq-capture-key"], "test-key")
  assert.equal(json.builder, "builder-042")
  assert.equal(json.session_id, "sess-1")
  assert.equal(json.turn.user_prompt, "what does the community think about local models?")
  assert.equal(json.turn.calls.length, 1)
  assert.match(json.turn.calls[0].tool, /lq-mcp/)
  assert.equal(json.turn.calls[0].results_chars, "…lots of results…".length)
  assert.equal(json.turn.assistant_reply, "The community is bullish.")
})

test("stays silent when the member has explicitly opted out", async () => {
  const { server, received } = ingestServer()
  await new Promise((r) => server.listen(0, r))
  const port = server.address().port

  const { code } = await runHook({ profile: OPTOUT, transcript: LQ_TURN, hookInput: {}, port })
  server.close()

  assert.equal(code, 0)
  assert.equal(received.length, 0, "capture_consent: false ⇒ no upload")
})

test("stays silent when the turn used no lq-mcp tool", async () => {
  const { server, received } = ingestServer()
  await new Promise((r) => server.listen(0, r))
  const port = server.address().port

  const nonLqTurn = [
    { type: "user", message: { role: "user", content: "run the tests" } },
    {
      type: "assistant",
      message: { role: "assistant", content: [{ type: "tool_use", id: "b1", name: "Bash", input: { command: "npm test" } }] },
    },
    { type: "assistant", message: { role: "assistant", content: [{ type: "text", text: "Done." }] } },
  ]

  const { code } = await runHook({ profile: DEFAULT_PROFILE, transcript: nonLqTurn, hookInput: {}, port })
  server.close()

  assert.equal(code, 0)
  assert.equal(received.length, 0, "no lq-mcp call ⇒ no upload")
})

test("stays silent (exit 0) when no profile exists at all", async () => {
  const { server, received } = ingestServer()
  await new Promise((r) => server.listen(0, r))
  const port = server.address().port

  const { code } = await runHook({ profile: null, transcript: LQ_TURN, hookInput: {}, port })
  server.close()

  assert.equal(code, 0)
  assert.equal(received.length, 0)
})
