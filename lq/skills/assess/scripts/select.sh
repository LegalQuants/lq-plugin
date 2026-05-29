#!/usr/bin/env bash
# /lq-assess select <number>
#
# Maps the candidate's 1-5 choice to a questionId, POSTs to /select, updates state.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"

NUM="${1:-}"
if [ -z "$NUM" ]; then
  die "usage: /lq-assess select <number 1-5>"
fi
if ! [[ "$NUM" =~ ^[1-5]$ ]]; then
  die "invalid choice: $NUM (must be 1-5)"
fi

TOKEN=$(state_get '.token')
WORK_DIR=$(state_get '.workingDir')

# Map number → questionId via the stored question list
IDX=$((NUM - 1))
QUESTION_ID=$(state_read | jq -r ".questions[$IDX].id // empty")
if [ -z "$QUESTION_ID" ]; then
  die "no question at position $NUM — run /lq-assess start <token> again"
fi

bold "Binding question $NUM ($QUESTION_ID) …"
RESPONSE=$(api_post "/api/assessment/$TOKEN/select" "$(jq -n --arg q "$QUESTION_ID" '{questionId: $q}')") \
  || die "select failed — server unreachable or rejected the request"

OK=$(printf '%s' "$RESPONSE" | jq -r '.ok')
if [ "$OK" != "true" ]; then
  ERR=$(printf '%s' "$RESPONSE" | jq -r '.error')
  DETAIL=$(printf '%s' "$RESPONSE" | jq -r '.detail // ""')
  die "select rejected: $ERR ${DETAIL:+($DETAIL)}"
fi

# Update state with bound info
STARTED_AT=$(printf '%s' "$RESPONSE" | jq -r '.token.startedAt')
state_write "$(state_read | jq --arg q "$QUESTION_ID" --arg s "$STARTED_AT" '
  .boundQuestionId = $q | .startedAt = $s | .state = "active"
')"

echo
green "✓ Clock started at $STARTED_AT — you have 90 minutes."
echo

bold "Your question: $QUESTION_ID"
printf '%s' "$RESPONSE" | jq -r '.question | "\n\(.title)\n\n\(.brief_l2)\n"'

echo
dim "Working directory: $WORK_DIR"
dim "Use any tools, code, or references inside that folder. Nothing outside it will be captured."
echo
bold "When you're done, run:"
echo "  /lq-assess submit"
