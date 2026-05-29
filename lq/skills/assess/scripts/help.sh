#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"

cat <<'EOF'
lq-assess — the LegalQuants assessment skill

Usage:
  /lq-assess start <token>       Validate the token and see your questions
  /lq-assess select <number>     Pick one of the questions. Clock starts.
  /lq-assess submit              Package your session, write a reflection, upload
  /lq-assess update              Refresh the skill from the server (safe to run anytime)
  /lq-assess help                Show this message

The assessment is 90 minutes of focused work on one question. You can use any
tools, code, or references inside the working directory the skill creates for
you (~/lq-assess-work/<token>/). Nothing outside that folder is captured.

Nothing leaves your machine until you explicitly confirm at the pre-submit step.

Questions about the assessment process: email jamietso@gmail.com.
EOF

if [ -f "$STATE_FILE" ]; then
  echo
  echo "Current state:"
  jq -r '
    "  token:          \(.token)",
    "  state:          \(.state)",
    "  boundQuestion:  \(.boundQuestionId // "(not yet selected)")",
    "  workingDir:     \(.workingDir)"
  ' "$STATE_FILE"
fi
