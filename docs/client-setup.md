# Connect an AI client

LAD MCP supplies event data to an AI client. The client uses the model selected
in the user's Claude or ChatGPT account to analyze that data. No provider API
key is needed by LAD MCP.

## macOS, Windows, and Linux setup

Install and sign in to a compatible Claude client, then run LAD until it has
created `daemon/logs/dashboard_events.jsonl`. The setup script asks for the LAD
directory, installs `uv` if needed, and configures the MCP connection. It
doesn’t require cloning this repository or entering an OpenAI/Anthropic API key.

### macOS

Use Claude Desktop or Claude Code. The script asks which client to configure:

```bash
curl -fsSL https://raw.githubusercontent.com/aurgus-io/lad-mcp/main/scripts/setup-unix.sh -o /tmp/setup-lad-mcp.sh
bash /tmp/setup-lad-mcp.sh
```

For Claude Desktop, it merges the LAD entry into the per-user config and keeps
a `.bak` copy of the previous file. Fully quit and reopen Claude Desktop after
setup. For Claude Code, check `claude mcp list`, then use `/mcp` in a session.

### Windows 10 or newer

In PowerShell, choose Claude Desktop or Claude Code when prompted:

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/aurgus-io/lad-mcp/main/scripts/setup-windows.ps1 -OutFile "$env:TEMP\setup-lad-mcp.ps1"
Unblock-File "$env:TEMP\setup-lad-mcp.ps1"
& "$env:TEMP\setup-lad-mcp.ps1"
```

Claude Code on Windows requires its supported environment (WSL or Git for
Windows). If LAD runs inside WSL, run the setup from that same WSL environment
or make the event file accessible to the Windows client.

### Linux

Use Claude Code. The Bash installer is distro-agnostic and supports Ubuntu,
Debian, Fedora, and compatible distributions:

```bash
curl -fsSL https://raw.githubusercontent.com/aurgus-io/lad-mcp/main/scripts/setup-unix.sh -o /tmp/setup-lad-mcp.sh
bash /tmp/setup-lad-mcp.sh
```

Anthropic's currently documented Claude Code Linux requirements list Ubuntu
20.04+ and Debian 10+. Fedora is not listed as an officially supported distro,
though the installer itself doesn’t use distro-specific package commands.
Claude Desktop does not currently offer an official Linux app, so use Claude
Code there.

## Verify and troubleshoot

For Claude Code, run `claude mcp list`; inside Claude Code, run `/mcp`. For
Claude Desktop, fully quit and reopen the app. Ask the model to list anomalies
from the last 24 hours. If it reports no data, ask it to search all retained
events with `since_minutes=0`, then confirm LAD is writing to the path you gave
the setup script.

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
