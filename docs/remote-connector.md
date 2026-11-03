# Connect with a server URL

The local Claude setup scripts use stdio, which is convenient when the client
and LAD run on the same computer. A custom connector that asks for an MCP
server URL needs Streamable HTTP over HTTPS instead.

## Run the HTTP server

On the machine that can read LAD's event file, set the event path and start
the server:

```bash
export LAD_EVENTS_FILE="/path/to/LAD/daemon/logs/dashboard_events.jsonl"
export LAD_MCP_TRANSPORT=streamable-http
export LAD_MCP_HOST=127.0.0.1
export LAD_MCP_PORT=8787
export LAD_MCP_USERS='[{"user_id":"anish","token":"REPLACE_WITH_A_LONG_RANDOM_SECRET_TOKEN_VALUE","event_file":"/path/to/LAD/daemon/logs/dashboard_events.jsonl"}]'
uv run lad-mcp
```

The MCP endpoint is `http://127.0.0.1:8787/mcp`. Keep it bound to loopback.
For a remote connector, publish it through an HTTPS reverse proxy or tunnel
and configure the client to send the user's bearer token. The URL to enter is
the public HTTPS address ending in `/mcp`, for example
`https://mcp.example.com/mcp`.

`LAD_MCP_USERS` is a JSON array of user records. Give every user a unique
`user_id`, a unique random `token` of at least 32 characters, and that user's
LAD event file path. Store this setting as a secret in the server's environment
or secret manager; don't commit it. Each request's bearer token selects exactly
one configured event file. A missing or invalid token receives HTTP 401, and
the server will not start in HTTP mode without a user mapping. Generate a token
with a password manager or a cryptographically secure random generator.

## Add it in the client

In the client's custom connector settings, choose **Add custom connector**,
enter a name such as **LAD Log Investigator**, and paste the HTTPS MCP URL.
Configure bearer token authentication with the matching user's token if the
client offers that option, then enable the connector and ask it to list
anomalies from the last 24 hours. The client must support sending a static
bearer token; this server does not currently provide an OAuth login page.

## Security and availability

HTTP mode now checks bearer tokens and maps each configured user to one event
file. HTTPS is still required to protect tokens in transit. Keep the service
behind TLS, rotate tokens if disclosed, and only provision users who should
read that file. This is token-based file selection, not a full OAuth identity
system or a hosted multi-tenant account manager. If the client cannot send a
bearer token, it cannot use this authenticated HTTP mode yet.

The machine running the server must stay online and keep access to the event
file. The server returns selected log content to the connected AI host; review
that host's data handling settings before connecting real logs.
