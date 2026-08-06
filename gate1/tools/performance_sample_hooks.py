#!/usr/bin/env python3
import json, time
from datetime import datetime, timezone
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
start = time.perf_counter()
n = sum(i % 9 for i in range(50000))
out = {
  "game": "pedestrian-pursuit",
  "evidence_type": "performance_sample",
  "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
  "sample_ms": (time.perf_counter() - start) * 1000,
  "hook": "python_cpu_microbench",
  "n": n,
}
path = ROOT / "gate1" / "evidence" / "out" / "performance_sample.json"
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(out, indent=2))
print(json.dumps(out))
