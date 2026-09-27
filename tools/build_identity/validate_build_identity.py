#!/usr/bin/env python3
"""Fail if a review identity would embed UNKNOWN, or if stamped SHA != HEAD."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from generate_build_identity import generate

ROOT = Path(__file__).resolve().parents[2]
STAMP = ROOT / "data" / "build_identity.json"


def _head() -> str:
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()


def main() -> int:
    generated = generate(ROOT, "guest-runner-review-debug")
    failures: list[str] = []
    sha = str(generated.get("git_sha") or "")
    if not sha or sha.upper() == "UNKNOWN":
        failures.append("generated_sha_unknown")
    head = _head()
    if sha != head:
        failures.append(f"generated_sha_mismatch:{sha}:{head}")
    if STAMP.is_file():
        stamped = json.loads(STAMP.read_text(encoding="utf-8"))
        stamped_sha = str(stamped.get("git_sha") or "")
        flavor = str(stamped.get("build_flavor") or "").lower()
        if "review" in flavor and stamped_sha.upper() == "UNKNOWN":
            failures.append("stamped_review_apk_identity_unknown")
        if stamped_sha and stamped_sha != head:
            failures.append(f"stamped_sha_not_head:{stamped_sha}")
    if failures:
        print("BUILD_IDENTITY_VALIDATE=FAIL")
        for row in failures:
            print(f"FAIL {row}")
        return 1
    print("BUILD_IDENTITY_VALIDATE=PASS")
    print(json.dumps({"git_sha": sha, "ref": generated.get("ref")}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
