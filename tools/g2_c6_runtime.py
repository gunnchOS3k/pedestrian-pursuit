#!/usr/bin/env python3
"""Pure-Python mirrors of G2-C6 device-role / accessibility / telemetry contracts."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "device_ux" / "profiles" / "device_roles.json"
ROLE_IDS = ("student_14_5", "handheld_hybrid", "ds_xl_coder", "edge_io_rings")
ALLOWED_INPUTS = {"keyboard", "touch", "gamepad", "ring_confirm"}
ALLOWED_GPS = {"SIMULATED", "none"}
ALLOWED_TELEMETRY = ("race_start", "checkpoint", "item_use", "finish", "restart")
SAFE_ID = re.compile(r"^[a-z0-9_]+$")


def load_catalog() -> dict[str, Any]:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def resolve_role(catalog: dict[str, Any], role_id: str) -> dict[str, Any]:
    roles = catalog.get("roles") or {}
    if role_id not in roles:
        raise KeyError(role_id)
    role = dict(roles[role_id])
    map_id = str(role.get("map_profile", ""))
    maps = catalog.get("map_profiles") or {}
    return {
        "role_id": role_id,
        "role": role,
        "map_profile": dict(maps.get(map_id, {})),
        "input_default": str(role.get("input_default", "")),
        "gps_mode": str(role.get("gps_mode", "")),
        "hud_layout": str(role.get("hud_layout", "")),
    }


def marker_color(kind: str, colorblind_safe: bool) -> tuple[float, float, float]:
    """Return RGB tuples mirroring AccessibilitySettings.get_marker_color."""
    if not colorblind_safe:
        defaults = {
            "player": (0.2, 0.85, 1.0),
            "checkpoint": (1.0, 0.85, 0.2),
            "finish": (0.3, 1.0, 0.45),
            "hazard": (1.0, 0.35, 0.25),
            "ai": (1.0, 0.55, 0.35),
        }
        return defaults.get(kind, (1.0, 1.0, 1.0))
    safe = {
        "player": (0.0, 0.45, 0.7),
        "checkpoint": (0.9, 0.6, 0.0),
        "finish": (0.0, 0.62, 0.45),
        "hazard": (0.8, 0.4, 0.0),
        "ai": (0.35, 0.7, 0.9),
    }
    return safe.get(kind, (1.0, 1.0, 1.0))


def ui_scale(role_scale: float, larger_ui: bool) -> float:
    return float(role_scale) * (1.25 if larger_ui else 1.0)


class TelemetryJournal:
    """In-memory stand-in for TelemetryBus JSONL append semantics."""

    def __init__(self) -> None:
        self.events: list[dict[str, Any]] = []

    def record(self, event_name: str, payload: dict[str, Any] | None = None) -> None:
        if event_name not in ALLOWED_TELEMETRY:
            raise ValueError(f"unknown event {event_name}")
        self.events.append({"event": event_name, "payload": payload or {}})

    def to_jsonl(self) -> str:
        return "\n".join(json.dumps(e, sort_keys=True) for e in self.events) + ("\n" if self.events else "")
