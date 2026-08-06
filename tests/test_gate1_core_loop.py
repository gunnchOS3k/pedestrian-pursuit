import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "gate1" / "tools"))
from core_loop_runner import run_core_loop, write_evidence, REQUIRED_STEPS

REQUIRED_FIELDS = [
    "game", "build_id", "commit", "platform", "session_id",
    "step", "timestamp", "result", "state_checksum", "evidence_type",
]

def test_core_loop():
    events, ok = run_core_loop()
    write_evidence(events, ok)
    assert ok
    for step in REQUIRED_STEPS:
        assert any(e["step"] == step and e["result"] == "pass" for e in events)
    for e in events:
        for k in REQUIRED_FIELDS:
            assert e.get(k), k
        assert len(e["state_checksum"]) >= 8
        assert len(e["commit"]) >= 7
    schema = json.loads((ROOT / "gate1/contracts/game_core_loop.schema.json").read_text())
    for k in REQUIRED_FIELDS:
        assert k in schema["required"]

if __name__ == "__main__":
    test_core_loop()
    print("PASS")
