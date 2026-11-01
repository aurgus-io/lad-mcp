#!/usr/bin/env bash

set -euo pipefail

readonly MCP_REPOSITORY="git+https://github.com/aurgus-io/lad-mcp.git"
readonly SETUP_BASE_URL="https://raw.githubusercontent.com/aurgus-io/lad-mcp/main/scripts"
readonly DEFAULT_LAD_DIRECTORY="$HOME/LAD"

system_name="$(uname -s)"
case "$system_name" in
  Darwin)
    printf '\nLAD MCP setup for macOS\n'
    printf '1) Claude Desktop\n2) Claude Code\n'
    read -r -p 'Choose your Claude app [1]: ' client_choice
    client_choice="${client_choice:-1}"
    ;;
  Linux)
    printf '\nLAD MCP setup for Linux (Ubuntu, Debian, Fedora, and compatible systems)\n'
    printf 'This setup uses Claude Code as the local MCP client.\n'
    client_choice=2
    ;;
  *)
    printf 'This installer supports macOS and Linux. For Windows, use setup-windows.ps1.\n' >&2
    exit 1
    ;;
esac

if [[ "$client_choice" != 1 && "$client_choice" != 2 ]]; then
  printf 'Choose 1 for Claude Desktop or 2 for Claude Code.\n' >&2
  exit 1
fi

if [[ "$client_choice" == 2 ]] && ! command -v claude >/dev/null 2>&1; then
  printf 'Claude Code is not installed or is not on PATH. Install it and sign in, then rerun setup:\n' >&2
  printf 'https://docs.anthropic.com/en/docs/claude-code/getting-started\n' >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf 'curl is required. Install it with your package manager, then rerun setup.\n' >&2
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
  printf 'uv was not found after installation. Open a new terminal and rerun setup.\n' >&2
  exit 1
fi

if [[ "$client_choice" == 1 ]]; then
  config_file="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  helper_directory="$(mktemp -d)"
  helper_file="$helper_directory/configure-claude-desktop.py"
  trap 'rm -rf "$helper_directory"' EXIT
  curl -fsSL "$SETUP_BASE_URL/configure-claude-desktop.py" -o "$helper_file"
  "$uv_command" python install 3.12 >/dev/null
  "$uv_command" run --python 3.12 "$helper_file" \
    --config "$config_file" \
    --events-file "$events_file" \
    --uv-command "$uv_command" \
    --repository "$MCP_REPOSITORY"
  printf '\nSetup complete. Fully quit and reopen Claude Desktop.\n'
  printf 'Ask Claude to list recent LAD anomalies to confirm the tools loaded.\n'
else
  if claude mcp get lad >/dev/null 2>&1; then
    printf 'Claude Code already has an MCP server named "lad".\n' >&2
    printf 'To replace it, run: claude mcp remove lad\n' >&2
    printf 'Then rerun this setup.\n' >&2
    exit 1
  fi
  claude mcp add \
    --scope user \
    --transport stdio \
    --env "LAD_EVENTS_FILE=$events_file" \
    lad \
    -- "$uv_command" tool run --from "$MCP_REPOSITORY" lad-mcp
  printf '\nSetup complete. Check the connection with `claude mcp list`.\n'
  printf 'Open Claude Code and run /mcp to confirm the LAD tools loaded.\n'
fi
