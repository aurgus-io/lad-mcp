# LAD MCP

A read-only Model Context Protocol (MCP) server that gives compatible AI clients
bounded access to events produced by [LAD](https://github.com/CrAnish07/LAD).

The server exposes three tools:

- `search_log_events` searches current event state by text, status, severity,
  anomaly flag, and time window.
- `get_log_event` retrieves the latest analysis for one event ID.
- `list_anomalies` lists events LAD has marked anomalous.

The server itself does not call OpenAI, Anthropic, or another model. It returns
selected event content to the connected MCP host; that host may send the content
to its configured model. Review the AI host's data-handling settings before
connecting production logs.

## Data source

The initial adapter reads LAD's append-only
`daemon/logs/dashboard_events.jsonl` file and collapses updates by event ID.
By default it expects the LAD and `lad-mcp` repositories to be sibling folders.
For another installation, set `LAD_EVENTS_FILE` to the event file's path. Search
is keyword based in this version; it does not query LAD's Qdrant vector store or
embedding model.

## Run locally

Requires Python 3.11 or newer.

```bash
cp .env.example .env
# Edit LAD_EVENTS_FILE in .env if LAD is installed elsewhere.
uv sync
uv run lad-mcp
```

By default the server uses stdio, so a local MCP client launches it as a
subprocess. An MCP client configuration can run
`uv --directory /path/to/lad-mcp run lad-mcp` and set `LAD_EVENTS_FILE` to the
LAD event file. Do not commit local paths or credentials.

For ChatGPT or another HTTP-based MCP client, set
`LAD_MCP_TRANSPORT=streamable-http`. It listens on `127.0.0.1:8787` by default.
A private/on-prem instance needs a secure tunnel or an authenticated HTTPS
service. **Do not expose this prototype directly to a network:** it does not yet
provide authentication or per-user authorization.

## Current limits

- Supports stdio and optional loopback Streamable HTTP. No MCP authentication
  or per-user authorization is implemented.
- Reads the current JSONL event store directly. A stable LAD search API or
  database adapter would be preferable for larger deployments.
- Results are capped at 100, but the adapter reads the full event file to
  collapse state updates.
- All tools are read-only; this server cannot execute commands or change LAD.
