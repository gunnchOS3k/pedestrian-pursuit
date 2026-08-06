#!/usr/bin/env python3
import json, sys
from datetime import datetime, timezone
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "gate1" / "evidence" / "out" / "runtime_logs.jsonl"
OUT.parent.mkdir(parents=True, exist_ok=True)
entry = {
  "game": "pedestrian-pursuit",
  "evidence_type": "log_collector",
  "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
  "message": " ".join(sys.argv[1:]) or "log collector invoked",
}
with OUT.open("a") as f:
  f.write(json.dumps(entry) + "\n")
print(OUT)
