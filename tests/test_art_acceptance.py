"""Final-art acceptance must stay separate from runtime playability."""

from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ArtAcceptanceTests(unittest.TestCase):
    def test_final_art_not_silent_commercial(self) -> None:
        path = ROOT / "data/art/vehicle_art_acceptance.json"
        self.assertTrue(path.exists())
        doc = json.loads(path.read_text(encoding="utf-8"))
        self.assertFalse(doc.get("human_commercial_art_gate", True))
        self.assertFalse(doc.get("HUMAN_FUN_APPROVAL", True))
        self.assertFalse(doc.get("HUMAN_COURSE_APPROVAL", True))
        self.assertFalse(doc.get("RC2_READY", True))
        self.assertFalse(doc.get("V1_0_0_RELEASE_AUTHORIZED", True))
        vehicles = doc["vehicles"]
        self.assertEqual(len(vehicles), 50)
        pending = 0
        candidate = 0
        for v in vehicles:
            self.assertEqual(v["runtime_status"], "playable_runtime")
            self.assertFalse(v.get("human_commercial_art_approved", True))
            fas = v["final_art_status"]
            self.assertIn(fas, ("final_art_pending", "final_art_candidate"))
            if fas == "final_art_pending":
                pending += 1
            else:
                candidate += 1
            ## Procedural/garage mesh statuses never equal commercial approval.
            self.assertNotEqual(fas, "final_art_approved")
        self.assertGreaterEqual(pending, 1)
        self.assertGreaterEqual(candidate, 1)
        self.assertEqual(pending + candidate, 50)

    def test_unlock_modes_not_all_starter(self) -> None:
        reg = json.loads((ROOT / "data/vehicles/vehicle_registry.json").read_text(encoding="utf-8"))
        modes = {}
        for v in reg["vehicles"]:
            mode = (v.get("unlock") or {}).get("mode", "starter")
            modes[mode] = modes.get(mode, 0) + 1
            self.assertTrue(v.get("playable"))
        self.assertGreaterEqual(modes.get("starter", 0), 8)
        self.assertLess(modes.get("starter", 0), 50)
        for need in ("cup", "challenge", "achievement", "crossover"):
            self.assertGreaterEqual(modes.get(need, 0), 1, need)

    def test_wardrobe_has_integrated_metro_pulse(self) -> None:
        cat = json.loads((ROOT / "data/wardrobe/wardrobe_catalog.json").read_text(encoding="utf-8"))
        self.assertIn("base_underlayer", cat["slots"])
        self.assertIn("footwear_vehicle", cat["slots"])
        integrated = [
            g for g in cat["garments"] if g.get("art_status") == "integrated_mesh_v1"
        ]
        self.assertGreaterEqual(len(integrated), 30)
        pending = [
            g for g in cat["garments"] if g.get("art_status") == "catalog_art_pending"
        ]
        self.assertGreaterEqual(len(pending), 1)
        families = {f["id"] for f in cat["families"]}
        for need in (
            "metro_pulse",
            "harbor_linen",
            "neon_trackside",
            "quiet_plaza",
            "midnight_atelier",
            "myth_circuit",
            "orbit_signal",
        ):
            self.assertIn(need, families)
        self.assertGreaterEqual(len(cat["presets"]), 5)
        preset = next(p for p in cat["presets"] if p["id"] == "metro_pulse_default")
        for key in ("base_underlayer", "top", "bottom", "outerwear"):
            self.assertIn(key, preset["slots"])


if __name__ == "__main__":
    unittest.main()
