from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from g2_c6_runtime import (  # noqa: E402
    ALLOWED_GPS,
    ALLOWED_INPUTS,
    ALLOWED_TELEMETRY,
    ROLE_IDS,
    TelemetryJournal,
    load_catalog,
    marker_color,
    resolve_role,
    ui_scale,
)


class DeviceRoleCatalogTests(unittest.TestCase):
    def test_catalog_covers_four_roles(self) -> None:
        catalog = load_catalog()
        self.assertEqual(catalog.get("game_id"), "pedestrian-pursuit")
        self.assertEqual(catalog.get("evidence_class"), "SOFTWARE")
        self.assertEqual(catalog.get("physical_status"), "PHYSICAL_PENDING")
        roles = catalog.get("roles") or {}
        self.assertEqual(set(roles), set(ROLE_IDS))

    def test_each_role_has_input_map_gps(self) -> None:
        catalog = load_catalog()
        for role_id in ROLE_IDS:
            resolved = resolve_role(catalog, role_id)
            self.assertIn(resolved["input_default"], ALLOWED_INPUTS)
            self.assertIn(resolved["gps_mode"], ALLOWED_GPS)
            self.assertTrue(resolved["hud_layout"])
            self.assertIn("map_profile", resolved["role"])

    def test_gps_never_live(self) -> None:
        catalog = load_catalog()
        for role_id in ROLE_IDS:
            resolved = resolve_role(catalog, role_id)
            self.assertNotEqual(resolved["gps_mode"].upper(), "LIVE")
            self.assertNotEqual(resolved["gps_mode"].upper(), "DEVICE")

    def test_pedestrian_matrix_alignment(self) -> None:
        catalog = load_catalog()
        expected = {
            "student_14_5": ("keyboard", "sim_campus", "SIMULATED"),
            "handheld_hybrid": ("touch", "sim_neighborhood", "SIMULATED"),
            "ds_xl_coder": ("keyboard", "debug_overlay", "SIMULATED"),
            "edge_io_rings": ("ring_confirm", "n/a", "none"),
        }
        for role_id, (inp, mapa, gps) in expected.items():
            resolved = resolve_role(catalog, role_id)
            self.assertEqual(resolved["input_default"], inp)
            self.assertEqual(resolved["role"]["map_profile"], mapa)
            self.assertEqual(resolved["gps_mode"], gps)

    def test_touch_role_shows_touch_controls(self) -> None:
        catalog = load_catalog()
        hybrid = resolve_role(catalog, "handheld_hybrid")
        self.assertTrue(hybrid["role"].get("show_touch_controls"))
        self.assertTrue(hybrid["role"].get("soft_path_assist"))
        student = resolve_role(catalog, "student_14_5")
        self.assertFalse(student["role"].get("show_touch_controls"))
        self.assertFalse(student["role"].get("soft_path_assist"))


class AccessibilityRuntimeTests(unittest.TestCase):
    def test_colorblind_markers_differ_from_default(self) -> None:
        for kind in ("player", "checkpoint", "finish", "hazard", "ai"):
            self.assertNotEqual(marker_color(kind, False), marker_color(kind, True))

    def test_larger_ui_scales_role(self) -> None:
        self.assertAlmostEqual(ui_scale(1.0, False), 1.0)
        self.assertAlmostEqual(ui_scale(1.0, True), 1.25)
        self.assertAlmostEqual(ui_scale(1.15, True), 1.15 * 1.25)

    def test_autoload_scripts_exist(self) -> None:
        for rel in (
            "scripts/core/DeviceRoleRuntime.gd",
            "scripts/core/AccessibilitySettings.gd",
            "scripts/core/TelemetryBus.gd",
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_project_registers_autoloads(self) -> None:
        text = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('DeviceRoleRuntime="*res://scripts/core/DeviceRoleRuntime.gd"', text)
        self.assertIn('AccessibilitySettings="*res://scripts/core/AccessibilitySettings.gd"', text)
        self.assertIn('TelemetryBus="*res://scripts/core/TelemetryBus.gd"', text)


class TelemetryRuntimeTests(unittest.TestCase):
    def test_allowed_events_round_trip_jsonl(self) -> None:
        journal = TelemetryJournal()
        journal.record("race_start", {"track_id": "verdant_cascade_circuit", "laps": 3})
        journal.record("checkpoint", {"checkpoint_index": 1, "lap": 0})
        journal.record("item_use", {"item_id": "turbo_toes"})
        journal.record("finish", {"position": 2, "finished": True})
        journal.record("restart", {"reason": "rematch"})
        lines = [ln for ln in journal.to_jsonl().splitlines() if ln]
        self.assertEqual(len(lines), 5)
        names = [json.loads(ln)["event"] for ln in lines]
        self.assertEqual(names, list(ALLOWED_TELEMETRY))

    def test_rejects_unknown_event(self) -> None:
        journal = TelemetryJournal()
        with self.assertRaises(ValueError):
            journal.record("host_loss", {})


    def test_finish_may_include_perf_payload(self) -> None:
        journal = TelemetryJournal()
        journal.record(
            "finish",
            {
                "track_id": "verdant_cascade_circuit",
                "position": 1,
                "finished": True,
                "perf": {"fps": 60, "frame_ms": 16.67, "within_budget": True},
            },
        )
        entry = journal.events[0]
        self.assertIn("perf", entry["payload"])
        self.assertTrue(entry["payload"]["perf"]["within_budget"])


class NoProtectedAssetsTests(unittest.TestCase):
    def test_device_ux_has_no_protected_ip_names(self) -> None:
        banned = ("mario", "kirby", "sonic", "nintendo", "sega")
        for path in (ROOT / "device_ux").rglob("*"):
            if not path.is_file():
                continue
            text = path.read_text(encoding="utf-8", errors="ignore").lower()
            for word in banned:
                self.assertNotIn(word, text, f"{word!r} in {path}")


if __name__ == "__main__":
    unittest.main()
