# LAD MCP

A read-only Model Context Protocol (MCP) server that gives compatible AI clients
bounded access to events produced by [LAD](https://github.com/CrAnish07/LAD).
Connect it to Claude or ChatGPT and ask that client's selected model to
investigate the events. LAD MCP does not call a model or require users to give it
an OpenAI or Anthropic API key: the connected AI client handles analysis using
the user's account and model.

The server exposes three tools:

- `search_log_events` searches current event state by text, status, severity,
  anomaly flag, and time window.
- `get_log_event` retrieves the latest analysis for one event ID.
- `list_anomalies` lists events LAD has marked anomalous.

The server returns selected event content to the connected MCP host; that host
may send it to its configured model. Review the AI host's data-handling settings
before connecting production logs.

## Data source

The initial adapter reads LAD's append-only
`daemon/logs/dashboard_events.jsonl` file and collapses updates by event ID.
By default it expects the LAD and `lad-mcp` repositories to be sibling folders.
For another installation, set `LAD_EVENTS_FILE` to the event file's path. Search
is keyword based in this version; it does not query LAD's Qdrant vector store or
embedding model.

## Install and run locally

Requires Python 3.11 or newer.

```bash
cp .env.example .env
# Edit LAD_EVENTS_FILE in .env if LAD is installed elsewhere.
uv sync
uv run lad-mcp
```

By default the server uses stdio, so a local MCP client launches it as a
subprocess. See [client setup](docs/client-setup.md) for Claude Desktop setup
and ChatGPT connection requirements. Do not commit local paths or credentials.

### Ubuntu with Claude Code

For an Ubuntu machine running LAD, install and sign in to
[Claude Code](https://docs.anthropic.com/en/docs/claude-code/getting-started),
then run the setup script below. It asks for the LAD directory, checks that the
event file exists, installs `uv` if needed, and registers LAD MCP with Claude
Code.

```bash
curl -fsSL https://raw.githubusercontent.com/aurgus-io/lad-mcp/main/scripts/setup-ubuntu.sh -o /tmp/setup-lad-mcp.sh
bash /tmp/setup-lad-mcp.sh
```

After setup, verify the connection with `claude mcp list`. Open Claude Code and
run `/mcp` to confirm the LAD tools are available. See
[client setup](docs/client-setup.md) for troubleshooting and other clients.

For ChatGPT or another remote MCP client, the server needs to be reachable over
HTTPS or through a supported secure tunnel. This prototype's HTTP transport has
no authentication or per-user authorization. **Do not expose it to a network
or connect production logs until authenticated access and data isolation are
implemented.**

## Current limits

- Supports stdio and optional loopback Streamable HTTP. No MCP authentication
  or per-user authorization is implemented; remote multi-user hosting is not
  ready.
- Reads the current JSONL event store directly. A stable LAD search API or
  database adapter would be preferable for larger deployments.
- Results are capped at 100, but the adapter reads the full event file to
  collapse state updates.
- All tools are read-only; this server cannot execute commands or change LAD.
