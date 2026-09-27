#!/usr/bin/env python3
"""Stamp Pedestrian Pursuit review/dev build identity at export time."""

from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

REPO_DEFAULT = "gunnchOS3k/pedestrian-pursuit"
PACKAGE_DEFAULT = "com.gunnchos.pedestrianpursuit"
OUT_DEFAULT = "data/build_identity.json"


def _git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=repo, text=True).strip()


def _parse_export_version(presets: Path) -> tuple[str, int]:
    name = "0.0.0"
    code = 0
    if not presets.is_file():
        return name, code
    for line in presets.read_text(encoding="utf-8").splitlines():
        if line.startswith("version/name="):
            name = line.split("=", 1)[1].strip().strip('"')
        elif line.startswith("version/code="):
            try:
                code = int(line.split("=", 1)[1].strip())
            except ValueError:
                code = 0
    return name, code


def generate(repo_root: Path, flavor: str) -> dict:
    sha = _git(repo_root, "rev-parse", "HEAD")
    if not sha or sha.upper() == "UNKNOWN":
        raise SystemExit("build identity refused to embed UNKNOWN SHA")
    short = _git(repo_root, "rev-parse", "--short=12", "HEAD")
    try:
        ref = _git(repo_root, "rev-parse", "--abbrev-ref", "HEAD")
    except subprocess.CalledProcessError:
        ref = "DETACHED"
    version_name, version_code = _parse_export_version(repo_root / "export_presets.cfg")
    return {
        "repo": REPO_DEFAULT,
        "git_sha": sha,
        "git_sha_short": short,
        "ref": ref,
        "version_name": version_name,
        "version_code": version_code,
        "build_timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "build_flavor": flavor,
        "package_id": PACKAGE_DEFAULT,
        "watermark": f"PP {short}",
    }


def write_identity(repo_root: Path, out: Path, flavor: str) -> dict:
    payload = generate(repo_root, flavor)
    if payload["git_sha"].upper() == "UNKNOWN":
        raise SystemExit("build identity refused to write UNKNOWN SHA")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--out", default=OUT_DEFAULT)
    parser.add_argument("--flavor", default="guest-runner-review-debug")
    args = parser.parse_args()
    repo_root = Path(args.repo_root).resolve()
    out = Path(args.out)
    if not out.is_absolute():
        out = repo_root / out
    payload = write_identity(repo_root, out, args.flavor)
    print(json.dumps(payload, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
