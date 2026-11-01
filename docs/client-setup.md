# Connect an AI client

LAD MCP supplies event data to an AI client. The client uses the model selected
in the user's Claude or ChatGPT account to analyze that data. No provider API
key is needed by LAD MCP.

## Claude Desktop on the same machine as LAD

1. Install Python 3.11+ and [`uv`](https://docs.astral.sh/uv/).
2. Clone this repository and install its dependencies:

   ```bash
   cd /path/to/lad-mcp
   uv sync
   ```

3. Open Claude Desktop's MCP configuration file:

   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`

4. Add the server entry below, replacing both example paths with absolute paths
   on your machine. Merge it into an existing `mcpServers` object if you have
   other MCP servers configured.

   ```json
   {
     "mcpServers": {
       "lad": {
         "command": "uv",
         "args": ["--directory", "/absolute/path/to/lad-mcp", "run", "lad-mcp"],
         "env": {
           "LAD_EVENTS_FILE": "/absolute/path/to/LAD/daemon/logs/dashboard_events.jsonl"
         }
       }
     }
   }
   ```

5. Restart Claude Desktop. Ask it to list recent anomalies or investigate an
   event. It can use `search_log_events`, `get_log_event`, and `list_anomalies`.

The `uv` executable must be available to Claude Desktop. If it is not on the
application's PATH, use the absolute path to `uv` as `command`.

## ChatGPT

ChatGPT connects to a remote MCP endpoint, not a server running only on your
computer. Custom MCP server availability and setup depend on the ChatGPT plan
and workspace settings. A connection needs an HTTPS endpoint or a supported
secure tunnel.

LAD MCP can run Streamable HTTP by setting `LAD_MCP_TRANSPORT=streamable-http`,
but its current HTTP server has no authentication or per-user authorization.
It binds to loopback by default. Do not expose it publicly or connect it to
production logs until authenticated access and per-user data isolation are
implemented. Once the server is deployed safely, add its endpoint in ChatGPT's
custom MCP server settings and select the tools to enable.

## Data handling

Tool results include log messages and LAD analysis fields. Treat logs as
sensitive data, review the connected AI service's data settings, and avoid
sharing secrets in log content. Log messages are untrusted input; the server
instructs AI clients to treat them as evidence rather than instructions.
