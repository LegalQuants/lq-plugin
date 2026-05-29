#!/usr/bin/env bash
# /lq-assess start <token>
#
# Validates the token against the server, fetches 5 questions, creates the
# working directory, persists state.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"

TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  die "usage: /lq-assess start <token>"
fi

if ! [[ "$TOKEN" =~ ^ASMT-[a-f0-9]{8}$ ]]; then
  die "invalid token format (expected ASMT-<8 hex chars>): $TOKEN"
fi

bold "Validating token against $LQ_ASSESS_URL …"
RESPONSE=$(api_get "/api/assessment/$TOKEN") || die "server rejected the token. Check the token and your network."

OK=$(printf '%s' "$RESPONSE" | jq -r '.ok')
if [ "$OK" != "true" ]; then
  ERR=$(printf '%s' "$RESPONSE" | jq -r '.error')
  DETAIL=$(printf '%s' "$RESPONSE" | jq -r '.detail // ""')
  die "token rejected: $ERR ${DETAIL:+($DETAIL)}"
fi

STATE_FROM_SERVER=$(printf '%s' "$RESPONSE" | jq -r '.token.state')
NAME=$(printf '%s' "$RESPONSE" | jq -r '.token.candidateName')
BOUND=$(printf '%s' "$RESPONSE" | jq -r '.token.boundQuestionId // ""')

WORK_DIR="$WORK_ROOT/$TOKEN"
mkdir -p "$WORK_DIR"

# Detect which CLI / agent is running this — captured for analytics only
RUNTIME=$(detect_runtime)

# Persist state for select.sh / submit.sh
STATE=$(printf '%s' "$RESPONSE" | jq --arg t "$TOKEN" --arg wd "$WORK_DIR" --arg rt "$RUNTIME" '{
  token: $t,
  state: .token.state,
  candidateName: .token.candidateName,
  boundQuestionId: (.token.boundQuestionId // null),
  startedAt: (.token.startedAt // null),
  expiresAt: .token.expiresAt,
  workingDir: $wd,
  runtime: $rt,
  questions: .questions,
  timeBudgetMinutes: .timeBudgetMinutes
}')
state_write "$STATE"

echo
bold "Welcome to your LegalQuants assessment, $NAME."
echo

if [ -n "$BOUND" ] && [ "$BOUND" != "null" ]; then
  # Candidate has already selected — show the bound question + clock status
  MIN_LEFT=$(printf '%s' "$RESPONSE" | jq -r '.token.minutesRemaining // 0')
  bold "Question already chosen: $BOUND"
  printf '%s' "$RESPONSE" | jq -r '.questions[0] | "\n\(.title)\n\n\(.brief_l2)\n"'
  echo
  green "Clock running — $MIN_LEFT minutes remaining."
  dim "When you're done, run /lq-assess submit."
  exit 0
fi

# Fresh start — show the questions
QUESTION_COUNT=$(printf '%s' "$RESPONSE" | jq -r '.questions | length')
bold "$QUESTION_COUNT questions drawn for this token. Pick one — the clock starts when you do."
echo

printf '%s' "$RESPONSE" | jq -r '.questions | to_entries[] | "[\(.key + 1)] \(.value.id) — \(.value.title)\n    \(.value.brief_l2)\n"'

echo
dim "Working directory: $WORK_DIR"
dim "Anything you put here will be captured at submission. Anything outside it stays on your machine."
dim "Runtime detected: $RUNTIME"
echo
bold "Pick a question:"
for i in $(seq 1 "$QUESTION_COUNT"); do
  echo "  /lq-assess select $i"
done
echo
dim "(Choosing starts the 90-minute clock. You can take 1-3 minutes to read first.)"
