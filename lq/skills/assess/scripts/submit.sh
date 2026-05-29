#!/usr/bin/env bash
# /lq-assess submit  [prepare <reflection> | finalize <reflection> | cancel]
#
# Three-step submission: tarball + session log go directly to Blob via
# signed upload tokens; the final POST to /submit carries only URLs
# (small JSON, no body-size cap).
#
# Modes:
#   prepare <reflection>   — validate sizes, show pre-submit summary
#   finalize <reflection>  — chain init-upload → PUT tarball → PUT session → POST submit
#   cancel                 — abandon (state left intact)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"

MODE="${1:-prepare}"

if [ "$MODE" = "cancel" ]; then
  dim "Submission cancelled. Your work is still in $(state_get '.workingDir') if you want to come back to it."
  exit 0
fi

# Node is required for the upload helper
require_dep node

TOKEN=$(state_get '.token')
WORK_DIR=$(state_get '.workingDir')
QUESTION_ID=$(state_get '.boundQuestionId')
STARTED_AT=$(state_get '.startedAt')

if [ -z "$QUESTION_ID" ] || [ "$QUESTION_ID" = "null" ]; then
  die "no question selected yet — run /lq-assess select <n> first"
fi

REFLECTION="${2:-}"

# Stage artifacts in a temp dir
STAGE=$(mktemp -d)
trap "rm -rf $STAGE" EXIT

SESSION_LOG="$STAGE/session.jsonl"
TARBALL="$STAGE/work.tar.gz"

# ─── Session log ──────────────────────────────────────────────────────────
if ! collect_session_logs "$WORK_DIR" "$SESSION_LOG" 2>/dev/null || [ ! -s "$SESSION_LOG" ]; then
  if [ -f /tmp/lq-assess-session.jsonl ]; then
    cp /tmp/lq-assess-session.jsonl "$SESSION_LOG"
  fi
fi
if [ ! -s "$SESSION_LOG" ]; then
  red "warning: no session log found. The reviewer will see only your artifact + reflection."
  echo "{}" > "$SESSION_LOG"
fi

SESSION_BYTES=$(wc -c < "$SESSION_LOG" | tr -d ' ')
MESSAGE_COUNT=$(wc -l < "$SESSION_LOG" | tr -d ' ')

# ─── Working directory tarball ────────────────────────────────────────────
FILE_COUNT=$(find "$WORK_DIR" -type f \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/objects/*' \
  -not -path '*/.next/*' \
  2>/dev/null | wc -l | tr -d ' ')

tar -czf "$TARBALL" \
  --exclude='node_modules' \
  --exclude='.git/objects' \
  --exclude='.next' \
  -C "$WORK_DIR" . 2>/dev/null

TARBALL_BYTES=$(wc -c < "$TARBALL" | tr -d ' ')

# ─── Elapsed minutes ──────────────────────────────────────────────────────
ELAPSED_MIN=$(python3 -c "
from datetime import datetime, timezone
started = datetime.fromisoformat('$STARTED_AT'.replace('Z', '+00:00'))
now = datetime.now(timezone.utc)
print(int((now - started).total_seconds() // 60))
" 2>/dev/null || echo "0")

REFL_LEN=${#REFLECTION}

# Caps: 50 MB per file. Files larger than this need to be sampled before retry.
MAX_TARBALL_BYTES=$((50 * 1024 * 1024))
MAX_SESSION_BYTES=$((50 * 1024 * 1024))

# ─── prepare mode ─────────────────────────────────────────────────────────
if [ "$MODE" = "prepare" ]; then
  echo
  bold "Pre-submit summary:"
  echo
  echo "  Token:        $TOKEN"
  echo "  Question:     $QUESTION_ID"
  echo "  Started:      $STARTED_AT"
  echo "  Elapsed:      ${ELAPSED_MIN} min"
  echo "  Working dir:  $WORK_DIR"
  echo "  Files:        $FILE_COUNT"
  echo "  Tarball:      $(printf '%.2f' "$(echo "$TARBALL_BYTES / 1048576" | bc -l 2>/dev/null || echo 0)") MB"
  echo "  Session log:  $SESSION_BYTES bytes, $MESSAGE_COUNT messages"
  echo "  Reflection:   $REFL_LEN chars"
  echo

  if [ "$REFL_LEN" -lt 50 ]; then
    red "✗ reflection too short ($REFL_LEN chars, minimum 50)"
    exit 1
  fi
  if [ "$REFL_LEN" -gt 5000 ]; then
    red "✗ reflection too long ($REFL_LEN chars, maximum 5000)"
    exit 1
  fi

  if [ "$TARBALL_BYTES" -gt "$MAX_TARBALL_BYTES" ]; then
    TARBALL_MB=$(printf '%.2f' "$(echo "$TARBALL_BYTES / 1048576" | bc -l 2>/dev/null || echo 0)")
    red "✗ working directory tarball too large (${TARBALL_MB} MB > 50 MB cap)"
    echo
    echo "  Largest files in your working dir:"
    du -ha "$WORK_DIR" 2>/dev/null \
      | grep -vE "(node_modules|\.git/objects|\.next)" \
      | sort -hr \
      | head -8 \
      | awk '{print "    " $1 "\t" $2}'
    echo
    echo "  Sample or remove the large ones, then re-run /lq-assess submit."
    exit 1
  fi

  if [ "$SESSION_BYTES" -gt "$MAX_SESSION_BYTES" ]; then
    red "✗ session log too large ($SESSION_BYTES bytes > 50 MB cap)"
    echo "  This shouldn't normally happen for a 90-min session. Contact Jamie."
    exit 1
  fi

  dim "Nothing has been sent yet. The skill will ask you to confirm before uploading."
  exit 0
fi

# ─── finalize mode ────────────────────────────────────────────────────────
if [ "$MODE" = "finalize" ]; then
  if [ "$REFL_LEN" -lt 50 ] || [ "$REFL_LEN" -gt 5000 ]; then
    die "reflection invalid length ($REFL_LEN) — run /lq-assess submit again"
  fi
  if [ "$TARBALL_BYTES" -gt "$MAX_TARBALL_BYTES" ]; then
    die "tarball over cap — run prepare again for guidance"
  fi

  bold "Uploading to $LQ_ASSESS_URL …"

  # Step 1 — upload the tarball directly to Blob (no JSON body size limit)
  echo "  → tarball ($(printf '%.2f' "$(echo "$TARBALL_BYTES / 1048576" | bc -l)") MB)"
  TARBALL_BLOB_URL=$(node "$SCRIPT_DIR/blob-upload.mjs" \
    --file "$TARBALL" \
    --pathname "assess/$TOKEN/working-dir.tar.gz" \
    --upload-url "$LQ_ASSESS_URL/api/assessment/$TOKEN/init-upload") \
    || die "tarball upload failed"

  # Step 2 — upload the session log the same way
  echo "  → session log ($SESSION_BYTES bytes)"
  SESSION_BLOB_URL=$(node "$SCRIPT_DIR/blob-upload.mjs" \
    --file "$SESSION_LOG" \
    --pathname "assess/$TOKEN/session-log.jsonl" \
    --upload-url "$LQ_ASSESS_URL/api/assessment/$TOKEN/init-upload") \
    || die "session-log upload failed"

  # Step 3 — POST the submission record with the blob URLs
  echo "  → recording submission"
  RUNTIME=$(state_get '.runtime // "unknown"')

  PAYLOAD=$(jq -n \
    --arg tarball "$TARBALL_BLOB_URL" \
    --arg sessionLog "$SESSION_BLOB_URL" \
    --arg reflection "$REFLECTION" \
    --arg runtime "$RUNTIME" \
    --argjson fileCount "$FILE_COUNT" \
    --argjson tarballBytes "$TARBALL_BYTES" \
    --argjson messageCount "$MESSAGE_COUNT" \
    '{
      tarballBlobUrl: $tarball,
      sessionLogBlobUrl: $sessionLog,
      reflection: $reflection,
      runtime: $runtime,
      fileCount: $fileCount,
      tarballBytes: $tarballBytes,
      messageCount: $messageCount,
      tokenUsage: { inputTokens: 0, outputTokens: 0, cachedReadTokens: 0 }
    }')

  RESPONSE=$(curl -fsS \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data "$PAYLOAD" \
    "$LQ_ASSESS_URL/api/assessment/$TOKEN/submit") || die "submit POST failed"

  OK=$(printf '%s' "$RESPONSE" | jq -r '.ok')
  if [ "$OK" != "true" ]; then
    ERR=$(printf '%s' "$RESPONSE" | jq -r '.error')
    DETAIL=$(printf '%s' "$RESPONSE" | jq -r '.detail // ""')
    die "server rejected submission: $ERR ${DETAIL:+($DETAIL)}"
  fi

  SUB_ID=$(printf '%s' "$RESPONSE" | jq -r '.submissionId')
  SUBMITTED_AT=$(printf '%s' "$RESPONSE" | jq -r '.submittedAt')

  echo
  green "✓ Submitted as $SUB_ID at $SUBMITTED_AT."
  echo
  echo "Three things happen next:"
  echo "  · Jamie reviews within 72 hours"
  echo "  · If accepted, you'll get an email with your builder-XXX handle + WhatsApp invite"
  echo "  · If we need follow-up, we'll reach out with specific questions"
  echo
  dim "Thank you for the work."

  rm -f "$STATE_FILE"
  exit 0
fi

die "unknown mode: $MODE (expected prepare / finalize / cancel)"
