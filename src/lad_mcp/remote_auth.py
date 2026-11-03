"""Bearer authentication and per-user event-file selection for HTTP mode."""

from __future__ import annotations

import contextvars
import hmac
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from lad_mcp.events import events_file


current_events_file: contextvars.ContextVar[Path | None] = contextvars.ContextVar(
    "current_events_file", default=None
)


@dataclass(frozen=True)
class UserCredential:
    user_id: str
    token: str
    event_file: Path


def load_user_credentials() -> list[UserCredential]:
    """Load per-user bearer tokens and event paths from LAD_MCP_USERS JSON."""
    raw = os.getenv("LAD_MCP_USERS", "")
    if not raw:
        raise RuntimeError(
            "LAD_MCP_USERS is required for streamable-http. Configure at least one "
            "user with a unique bearer token and event_file."
        )
    try:
        records: Any = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError("LAD_MCP_USERS must be valid JSON.") from exc
    if not isinstance(records, list) or not records:
        raise RuntimeError("LAD_MCP_USERS must be a non-empty JSON array.")

    users: list[UserCredential] = []
    seen_ids: set[str] = set()
    seen_tokens: set[str] = set()
    for item in records:
        if not isinstance(item, dict):
            raise RuntimeError("Each LAD_MCP_USERS entry must be an object.")
        user_id = item.get("user_id")
        token = item.get("token")
        path = item.get("event_file")
        if not all(isinstance(value, str) and value.strip() for value in (user_id, token, path)):
            raise RuntimeError("Each user needs non-empty user_id, token, and event_file values.")
        assert isinstance(user_id, str) and isinstance(token, str) and isinstance(path, str)
        if user_id in seen_ids or token in seen_tokens:
            raise RuntimeError("LAD_MCP_USERS must have unique user_id and token values.")
        if len(token) < 32:
            raise RuntimeError(f"Bearer token for {user_id!r} must be at least 32 characters.")
        seen_ids.add(user_id)
        seen_tokens.add(token)
        users.append(UserCredential(user_id, token, events_file(path)))
    return users


class BearerAuthMiddleware:
    """Authenticate each HTTP request and scope tools to that user's event file."""

    def __init__(self, app: Any, users: list[UserCredential]):
        self.app = app
        self.users = users

    async def __call__(self, scope: dict[str, Any], receive: Any, send: Any) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        supplied = b""
        for key, value in scope.get("headers", []):
            if key.lower() == b"authorization":
                scheme, _, credential = value.partition(b" ")
                if scheme.lower() == b"bearer":
                    supplied = credential.strip()
                break

        match = None
        for user in self.users:
            if hmac.compare_digest(supplied, user.token.encode("utf-8")):
                match = user
        if match is None:
            body = b'{"error":"Unauthorized"}'
            await send(
                {
                    "type": "http.response.start",
                    "status": 401,
                    "headers": [
                        (b"content-type", b"application/json"),
                        (b"www-authenticate", b"Bearer"),
                    ],
                }
            )
            await send({"type": "http.response.body", "body": body})
            return

        context_token = current_events_file.set(match.event_file)
        try:
            await self.app(scope, receive, send)
        finally:
            current_events_file.reset(context_token)
