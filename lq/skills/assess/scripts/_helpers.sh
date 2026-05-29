#!/usr/bin/env bash
# Shared helpers for lq-assess scripts.
# Sourced by start.sh / select.sh / submit.sh / help.sh.

# Server URL (production by default; override via LQ_ASSESS_URL env var for testing)
LQ_ASSESS_URL="${LQ_ASSESS_URL:-https://lq-assess.vercel.app}"

STATE_DIR="$HOME/.config/lq-assess"
STATE_FILE="$STATE_DIR/state.json"
WORK_ROOT="$HOME/lq-assess-work"

mkdir -p "$STATE_DIR" "$WORK_ROOT"

# ─────────────────────────────────────────────────────────────────────────────
# Pretty output
# ─────────────────────────────────────────────────────────────────────────────

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }
red()  { printf '\033[31m%s\033[0m\n' "$1" >&2; }
green(){ printf '\033[32m%s\033[0m\n' "$1"; }

die() {
  red "✗ $1"
  exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Dependency check
# ─────────────────────────────────────────────────────────────────────────────

require_dep() {
  command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1 (required for the assessment skill)"
}

require_dep curl
require_dep jq
require_dep tar
require_dep base64

# ─────────────────────────────────────────────────────────────────────────────
# Runtime detection — for analytics only, not gating
# ─────────────────────────────────────────────────────────────────────────────

# Identifies which agent / CLI is invoking the skill. Returns one of:
# claude-code · codex · openclaw · unknown
detect_runtime() {
  # Env-var probes — set by each runtime when it spawns the shell
  [ -n "$OPENCLAW" ]   && echo "openclaw"    && return
  [ -n "$CODEX" ]      && echo "codex"       && return
  [ -n "$CLAUDECODE" ] && echo "claude-code" && return

  # Parent process tree walk — up to 5 levels (shell + agent + harness)
  local p=$PPID
  local i=0
  while [ $i -lt 5 ] && [ -n "$p" ] && [ "$p" != "1" ] && [ "$p" != "0" ]; do
    local name
    name=$(ps -p "$p" -o comm= 2>/dev/null | tr -d ' /' | tr '[:upper:]' '[:lower:]')
    case "$name" in
      *openclaw*) echo "openclaw"    && return ;;
      *codex*)    echo "codex"       && return ;;
      *claude*)   echo "claude-code" && return ;;
    esac
    p=$(ps -p "$p" -o ppid= 2>/dev/null | tr -d ' ')
    i=$((i + 1))
  done

  echo "unknown"
}

# ─────────────────────────────────────────────────────────────────────────────
# State file (persists between /lq-assess subcommands)
# ─────────────────────────────────────────────────────────────────────────────

state_write() {
  printf '%s' "$1" > "$STATE_FILE"
}

state_read() {
  if [ ! -f "$STATE_FILE" ]; then
    die "no active assessment state — run /lq-assess start <token> first"
  fi
  cat "$STATE_FILE"
}

state_get() {
  state_read | jq -r "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
# API helpers
# ─────────────────────────────────────────────────────────────────────────────

api_get() {
  local path="$1"
  curl -fsS \
    -H "Accept: application/json" \
    "$LQ_ASSESS_URL$path"
}

api_post() {
  local path="$1"
  local body="$2"
  curl -fsS \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data "$body" \
    "$LQ_ASSESS_URL$path"
}

# ─────────────────────────────────────────────────────────────────────────────
# Session-log discovery — try to find Claude Code's JSONL for the assessment
# ─────────────────────────────────────────────────────────────────────────────

# Computes Claude Code's workspace slug from a working-directory path.
# Claude Code stores sessions at ~/.claude/projects/<slug>/<session>.jsonl
# where <slug> is the path with slashes replaced by hyphens, leading slash kept as dash.
workspace_slug_for() {
  printf '%s' "$1" | sed 's|/|-|g'
}

# Concatenate all JSONL files in the workspace dir into a single file at $1.
# Returns 0 if files were found and concatenated, 1 if no files found.
collect_session_logs() {
  local work_dir="$1"
  local out_file="$2"
  local slug
  slug=$(workspace_slug_for "$work_dir")
  local project_dir="$HOME/.claude/projects/$slug"
  if [ ! -d "$project_dir" ]; then
    return 1
  fi
  local found=0
  : > "$out_file"
  for f in "$project_dir"/*.jsonl; do
    [ -f "$f" ] || continue
    cat "$f" >> "$out_file"
    found=1
  done
  return $((1 - found))
}
