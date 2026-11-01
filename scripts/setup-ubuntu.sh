#!/usr/bin/env bash

set -euo pipefail

readonly MCP_REPOSITORY="git+https://github.com/aurgus-io/lad-mcp.git"
readonly DEFAULT_LAD_DIRECTORY="$HOME/LAD"

printf '\nLAD MCP setup for Ubuntu\n'
printf 'This connects a local LAD event file to Claude Code.\n\n'

if ! command -v claude >/dev/null 2>&1; then
  printf 'Claude Code is not installed or is not on PATH.\n' >&2
  printf 'Install it and sign in, then run this setup again: https://docs.anthropic.com/en/docs/claude-code/getting-started\n' >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf 'curl is required. Install it with: sudo apt install curl\n' >&2
  exit 1
fi

read -r -p "Path to your LAD directory [$DEFAULT_LAD_DIRECTORY]: " lad_directory
lad_directory="${lad_directory:-$DEFAULT_LAD_DIRECTORY}"
lad_directory="${lad_directory/#\~/$HOME}"

if [[ ! -d "$lad_directory" ]]; then
  printf 'LAD directory not found: %s\n' "$lad_directory" >&2
  exit 1
fi

lad_directory="$(cd "$lad_directory" && pwd -P)"
events_file="$lad_directory/daemon/logs/dashboard_events.jsonl"

if [[ ! -r "$events_file" ]]; then
  printf 'Cannot read LAD event file: %s\n' "$events_file" >&2
  printf 'Start LAD and confirm it writes daemon/logs/dashboard_events.jsonl, then rerun setup.\n' >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  printf '\nInstalling uv...\n'
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

uv_command="$(command -v uv || true)"
if [[ -z "$uv_command" && -x "$HOME/.local/bin/uv" ]]; then
  uv_command="$HOME/.local/bin/uv"
fi
if [[ -z "$uv_command" && -x "$HOME/.cargo/bin/uv" ]]; then
  uv_command="$HOME/.cargo/bin/uv"
fi
if [[ -z "$uv_command" ]]; then
  printf 'uv installation completed, but the uv executable was not found.\n' >&2
  printf 'Open a new terminal and rerun this setup.\n' >&2
  exit 1
fi

if claude mcp get lad >/dev/null 2>&1; then
  printf '\nClaude Code already has an MCP server named "lad".\n' >&2
  printf 'To replace it, run: claude mcp remove lad\n' >&2
  printf 'Then rerun this setup.\n' >&2
  exit 1
fi

printf '\nRegistering LAD MCP with Claude Code...\n'
claude mcp add \
  --scope user \
  --transport stdio \
  --env "LAD_EVENTS_FILE=$events_file" \
  lad \
  -- "$uv_command" tool run --from "$MCP_REPOSITORY" lad-mcp

printf '\nSetup complete. Check the connection with:\n'
printf '  claude mcp list\n\n'
printf 'Then start Claude Code, run /mcp, and ask it to inspect your LAD events.\n'
