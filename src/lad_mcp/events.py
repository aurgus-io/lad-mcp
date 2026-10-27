"""Read the append-only event state written by LAD's current pipeline."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EVENTS_FILE = REPO_ROOT.parent / "LAD" / "daemon" / "logs" / "dashboard_events.jsonl"


def events_file() -> Path:
    """Resolve the configured LAD event file, using the sibling repo in development."""
    configured = os.getenv("LAD_EVENTS_FILE")
    path = Path(configured).expanduser() if configured else DEFAULT_EVENTS_FILE
    if not path.is_absolute():
        path = REPO_ROOT / path
    return path.resolve()


def read_current_events() -> list[dict[str, Any]]:
    """Collapse append-only updates so each event has its latest known state."""
    path = events_file()
    if not path.is_file():
        raise FileNotFoundError(
            f"LAD event file not found at {path}. Set LAD_EVENTS_FILE to the active "
            "daemon/logs/dashboard_events.jsonl file."
        )

    latest: dict[str, dict[str, Any]] = {}
    with path.open("r", encoding="utf-8") as source:
        for line in source:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(record, dict):
                continue
            event_id = record.get("id")
            if not isinstance(event_id, str) or not event_id:
                continue
            latest.setdefault(event_id, {}).update(record)

    return list(latest.values())


def public_event(event: dict[str, Any]) -> dict[str, Any]:
    """Return investigation fields while omitting absolute host paths."""
    fields = (
        "id", "timestamp", "message", "status", "severity", "anomaly_detected",
        "error_type", "suggested_fix", "commands", "explanation", "confidence",
        "group_id", "group_count", "analysis_source", "model", "rule_reason",
    )
    result = {key: event[key] for key in fields if key in event}
    source_file = event.get("file")
    if isinstance(source_file, str) and source_file:
        result["source"] = Path(source_file).name
    return result
