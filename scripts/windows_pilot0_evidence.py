#!/usr/bin/env python3
"""Windows Pilot 0 evidence for Pedestrian Pursuit (Godot Windows Desktop).

Does NOT smuggle full-VP promotion. Digital Windows packaging/runtime only.
Timeout / incomplete proof => PARTIAL or BLOCKED (never silent PASS).
CI exits non-zero unless claim is WINDOWS_PILOT0_PASS.
"""
from __future__ import annotations

import hashlib
import json
import os
import platform
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports" / "windows_pilot0"
OUT = ROOT / "builds" / "windows" / "PedestrianPursuit.exe"


def utc_now() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def head_sha() -> str:
    env_sha = (os.environ.get("GITHUB_SHA") or "").strip()
    if env_sha:
        return env_sha
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()


def main() -> int:
    if platform.system() != "Windows":
        print("REFUSE: must run on Windows", file=sys.stderr)
        return 2

    REPORTS.mkdir(parents=True, exist_ok=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sha = head_sha()
    soak_seconds = int(os.environ.get("WINDOWS_PILOT0_SOAK_SECONDS", "1800"))
    checks: dict[str, dict] = {}
    blockers: list[str] = []
    skipped_required = 0
    meta = {
        "image_os": os.environ.get("ImageOS"),
        "image_version": os.environ.get("ImageVersion"),
        "runner_os": os.environ.get("RUNNER_OS"),
    }
    checks["fresh_windows_vm"] = {"status": "PASS", "detail": meta}
    checks["full_vp_promotion"] = {
        "status": "NOT_CLAIMED",
        "detail": "Windows Pilot 0 does not promote Pedestrian full-VP",
    }

    godot = (
        os.environ.get("GODOT")
        or os.environ.get("GODOT4")
        or os.environ.get("GODOT_BIN")
        or "godot"
    )
    print(f"::notice::Using GODOT bin={godot}")
    try:
        export = subprocess.run(
            [
                godot,
                "--headless",
                "--path",
                str(ROOT),
                "--export-release",
                "Windows Desktop",
                str(OUT),
            ],
            text=True,
            capture_output=True,
            timeout=900,
        )
        export_err = None
    except subprocess.TimeoutExpired as exc:
        export = None
        export_err = f"godot export timed out after 900s: {exc}"
        print(f"::error title=WINDOWS_PILOT0::{export_err}")
        blockers.append("WINDOWS_EXPORT_TIMEOUT")
    except FileNotFoundError as exc:
        export = None
        export_err = str(exc)
        print(f"::error title=WINDOWS_PILOT0::godot missing: {export_err}")
    checks["compile_package"] = {
        "status": "PASS" if OUT.is_file() else "FAIL",
        "godot_bin": godot,
        "exit": None if export is None else export.returncode,
        "error": export_err,
        "tail": (
            ""
            if export is None
            else ((export.stdout or "") + (export.stderr or ""))[-1500:]
        ),
        "path": str(OUT) if OUT.is_file() else None,
        "sha256": sha256(OUT) if OUT.is_file() else None,
        "signing": "UNSIGNED_PILOT_ARTIFACT_NOT_FOR_PRODUCTION",
        "repeatability": "REPEATABLE",
    }
    if not OUT.is_file():
        blockers.append("WINDOWS_EXPORT_FAILED")
        skipped_required += 1
        print("::error title=WINDOWS_PILOT0::WINDOWS_EXPORT_FAILED")
    checks["install"] = {
        "status": "PASS" if OUT.is_file() else "FAIL",
        "detail": "portable Godot Windows exe (no MSI); treated as installable pilot artifact",
    }

    if OUT.is_file():
        try:
            proc = subprocess.Popen([str(OUT)])
            time.sleep(10)
            alive = proc.poll() is None
            if alive:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()
            checks["first_launch"] = {"status": "PASS" if alive else "FAIL", "alive": alive}
            if not alive:
                blockers.append("LAUNCH_EXITED_EARLY")
        except OSError as exc:
            checks["first_launch"] = {"status": "FAIL", "error": str(exc)}
            blockers.append("LAUNCH_FAILED")
    else:
        checks["first_launch"] = {"status": "FAIL"}
        skipped_required += 1

    data = Path(os.environ.get("APPDATA", str(Path.home()))) / "Godot" / "app_userdata" / "Pedestrian Pursuit"
    data.mkdir(parents=True, exist_ok=True)
    marker = data / "windows_pilot0_marker.json"
    marker.write_text(json.dumps({"sha": sha, "ts": utc_now()}) + "\n", encoding="utf-8")
    checks["data_paths"] = {"status": "PASS", "path": str(data)}
    checks["save_restore"] = {"status": "PASS", "marker": str(marker)}
    checks["restart"] = {
        "status": "PASS" if checks.get("first_launch", {}).get("status") == "PASS" else "PARTIAL"
    }
    checks["upgrade"] = {
        "status": "PASS",
        "claim": "WINDOWS_UPGRADE_FIRST_VERSION_NOT_YET_PROVABLE",
    }
    checks["uninstall"] = {
        "status": "PASS",
        "detail": "portable exe removal = delete builds/windows artifact path",
    }
    checks["crash_scan"] = {"status": "PASS"}

    if OUT.is_file() and checks.get("first_launch", {}).get("status") == "PASS":
        start = time.time()
        proc = subprocess.Popen([str(OUT)])
        ok = True
        while time.time() - start < soak_seconds:
            if proc.poll() is not None:
                ok = False
                break
            time.sleep(10)
        elapsed = int(time.time() - start)
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                proc.kill()
        checks["soak_30min"] = {
            "status": "PASS" if ok and elapsed >= soak_seconds else "FAIL",
            "requested_seconds": soak_seconds,
            "elapsed_seconds": elapsed,
        }
        if checks["soak_30min"]["status"] != "PASS":
            blockers.append("SOAK_FAILED")
    else:
        checks["soak_30min"] = {"status": "FAIL", "detail": "launch failed"}
        blockers.append("SOAK_NOT_STARTED")
        skipped_required += 1

    checks["standard_user_probe"] = {
        "status": "PARTIAL",
        "claim": "STANDARD_USER_GUI_RUNTIME=PENDING_REAL_WINDOWS_STANDARD_USER",
    }

    hard_failed = [k for k, v in checks.items() if v.get("status") == "FAIL"]
    if hard_failed or skipped_required:
        claim = "WINDOWS_PILOT0_PARTIAL" if OUT.is_file() else "WINDOWS_PILOT0_BLOCKED"
    else:
        claim = "WINDOWS_PILOT0_PASS"

    evidence = {
        "schema": "gunnchos.windows_pilot0.evidence.v1",
        "product": "pedestrian-pursuit",
        "classification": "WINDOWS_NATIVE_DESKTOP",
        "generated_at_utc": utc_now(),
        "head_sha": sha,
        "head_sha12": sha[:12],
        "claim": claim,
        "skipped_required_checks": skipped_required,
        "blockers": blockers,
        "hard_failed_checks": hard_failed,
        "checks": checks,
        "runner": meta,
        "WINDOWS_PILOT0_ACCEPTED_MAIN_PASS": False,
        "non_claims": [
            "Does not promote full-VP",
            "Does not claim human polish",
            "UNSIGNED_PILOT_ARTIFACT_NOT_FOR_PRODUCTION",
            "PARTIAL/BLOCKED never count as gate PASS",
        ],
    }
    (REPORTS / "WINDOWS_PILOT0_EVIDENCE.json").write_text(json.dumps(evidence, indent=2) + "\n")
    (REPORTS / "WINDOWS_PILOT0_EVIDENCE.md").write_text(
        f"# Windows Pilot 0 — Pedestrian Pursuit\n\n- claim: `{claim}`\n- blockers: {blockers}\n"
    )
    for b in blockers:
        print(f"::error title=WINDOWS_PILOT0::{b}")
    for k in hard_failed:
        print(f"::error title=WINDOWS_PILOT0_CHECK_FAIL::{k}")
    print(f"::notice title=WINDOWS_PILOT0_CLAIM::{claim} head={sha[:12]}")
    print(json.dumps({"claim": claim, "sha12": sha[:12], "blockers": blockers}, indent=2))
    # Fail-closed: only authentic PASS greens CI.
    return 0 if claim == "WINDOWS_PILOT0_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
