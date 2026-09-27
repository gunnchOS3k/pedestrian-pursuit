from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CORE = [
    "dash_reed",
    "nova_quill",
    "sierra_flux",
    "mira_lane",
    "bolt_harbor",
    "zig_riven",
    "solen_pike",
    "kai_volt",
]
GUEST = [
    "ember_vale",
    "rook_ironside",
    "juno_spark",
    "kaia_windrow",
    "nix_calder",
    "orion_vell",
    "vesper_nyx",
]
EXPECTED_SHA = {
    "ember_vale": "1da02b8882b06f3c88f97b5d4a595c89917203dfc02ff2d4055cd1cfde5db93e",
    "rook_ironside": "18d96e68de21152b44fabdd6294935d9964f1b16f8aca73b6a1db08f039c3b2e",
    "juno_spark": "2f579f1a24c599007242e065079e5a5d280fed005731cde30ba663339a0e5067",
    "kaia_windrow": "af3d540a18dda9370c17c3b88a5e18adcc1783c02e419312e043a8675c52853b",
    "nix_calder": "324556bb3ad563397d96a29825b43ff552de8468b604ae619f19461930054c0f",
    "orion_vell": "7e688084067236905db9604018a1ced240273cb1db7db274e14b4dece76997c3",
    "vesper_nyx": "706dedbe6d4c2d32831d131f4f33cbee3774740e9573fd03d405dd03effaf8b7",
}
STAT_KEYS = [
    "top_speed",
    "acceleration",
    "handling",
    "drift_control",
    "trick_skill",
    "recovery",
    "strength",
    "boost_efficiency",
]


def _sha(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


class AaGuestRunnerTests(unittest.TestCase):
    def test_core_ids_still_exist(self) -> None:
        roster = json.loads((ROOT / "data/racers/runner_roster.json").read_text(encoding="utf-8"))
        ids = [row["id"] for row in roster["runners"]]
        for rid in CORE:
            self.assertIn(rid, ids)
            self.assertTrue((ROOT / f"data/racers/{rid}.json").exists())

    def test_guest_ids_exist_and_are_unique(self) -> None:
        roster = json.loads((ROOT / "data/racers/runner_roster.json").read_text(encoding="utf-8"))
        ids = [row["id"] for row in roster["runners"]]
        self.assertEqual(len(ids), 15)
        self.assertEqual(len(set(ids)), 15)
        for rid in GUEST:
            self.assertIn(rid, ids)
            self.assertTrue((ROOT / f"data/racers/{rid}.json").exists())
        self.assertEqual(set(CORE) & set(GUEST), set())

    def test_guest_stats_match_twin_envelopes(self) -> None:
        for rid in GUEST:
            guest = json.loads((ROOT / f"data/racers/{rid}.json").read_text(encoding="utf-8"))
            twin_id = guest["stat_envelope_twin"]
            self.assertIn(twin_id, CORE)
            twin = json.loads((ROOT / f"data/racers/{twin_id}.json").read_text(encoding="utf-8"))
            for key in STAT_KEYS:
                self.assertEqual(float(guest[key]), float(twin[key]), f"{rid}.{key}")
            self.assertFalse(guest.get("guest_unique_ability", True))

    def test_models_and_hashes(self) -> None:
        for rid, digest in EXPECTED_SHA.items():
            path = ROOT / f"assets/models/guest_runners/{rid}/{rid}.glb"
            self.assertTrue(path.exists(), rid)
            self.assertEqual(_sha(path), digest, rid)

    def test_provenance_label(self) -> None:
        prov = json.loads(
            (ROOT / "artifacts/guest_runners/GUEST_RUNNER_PROVENANCE.json").read_text(encoding="utf-8")
        )
        self.assertEqual(prov["label"], "AA_CC0_CANDIDATE_DERIVATIVE")
        self.assertTrue(prov["not_bespoke_pp_human_commission"])
        self.assertFalse(prov["copied_experiment_art_v2_v9"])
        self.assertEqual(prov["models_present"], "7/7")
        self.assertEqual(len(prov["runners"]), 7)
        for row in prov["runners"]:
            self.assertEqual(row["license"], "CC0 1.0 Universal")
            self.assertTrue(row["hash_verified"])

    def test_footwear_matrix(self) -> None:
        matrix = json.loads((ROOT / "data/guest_runners/guest_footwear_compat.json").read_text(encoding="utf-8"))
        self.assertEqual(len(matrix["rows"]), 7)
        for row in matrix["rows"]:
            self.assertEqual(len(row["compatible_shoes"]), 4)
            self.assertFalse(row["guest_grants_secret_speed"])


if __name__ == "__main__":
    unittest.main()
