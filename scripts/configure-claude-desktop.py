"""Merge the LAD MCP entry into Claude Desktop's per-user configuration."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--events-file", required=True, type=Path)
    parser.add_argument("--uv-command", required=True)
    parser.add_argument("--repository", required=True)
    args = parser.parse_args()

    config = {}
    if args.config.exists():
        try:
            config = json.loads(args.config.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            print(f"Could not read Claude Desktop config: {exc}", file=sys.stderr)
            return 1
    if not isinstance(config, dict):
        print("Claude Desktop config must contain a JSON object.", file=sys.stderr)
        return 1

    servers = config.setdefault("mcpServers", {})
    if not isinstance(servers, dict):
        print('The "mcpServers" field in Claude Desktop config must be an object.', file=sys.stderr)
        return 1

    entry = {
        "command": args.uv_command,
        "args": ["tool", "run", "--from", args.repository, "lad-mcp"],
        "env": {"LAD_EVENTS_FILE": str(args.events_file.resolve())},
    }
    previous = servers.get("lad")
    if previous is not None:
        previous_text = json.dumps(previous)
        if "lad-mcp" not in previous_text:
            print('A different MCP server already uses the name "lad". Rename or remove it, then rerun setup.', file=sys.stderr)
            return 1
        print('Updating the existing "lad" MCP entry.')
    servers["lad"] = entry

    try:
        args.config.parent.mkdir(parents=True, exist_ok=True)
        if args.config.exists():
            shutil.copy2(args.config, args.config.with_suffix(args.config.suffix + ".bak"))
        args.config.write_text(json.dumps(config, indent=2) + os.linesep, encoding="utf-8")
    except OSError as exc:
        print(f"Could not update Claude Desktop config: {exc}", file=sys.stderr)
        return 1

    print(f'Added LAD MCP to {args.config}')
    print('A backup of any previous config is saved alongside it with a .bak suffix.')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
