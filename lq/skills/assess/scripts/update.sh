#!/usr/bin/env bash
# /lq-assess update
#
# Re-runs the install one-liner so the local skill files get refreshed
# with whatever's currently on the server. Idempotent — safe to run
# anytime ("am I on the latest?" check).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"

bold "Updating lq-assess from $LQ_ASSESS_URL …"
echo

# Single source of truth — same endpoint a fresh install hits.
curl -fsSL "$LQ_ASSESS_URL/install" | sh

echo
green "✓ Update complete."
dim "If you have an active assessment, your state and working directory are untouched."
