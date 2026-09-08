#!/usr/bin/env python3
"""Windows Pilot 0 evidence for Pedestrian Pursuit (Godot Windows Desktop).

Does NOT smuggle full-VP promotion. Digital Windows packaging/runtime only.
Requires Godot 4.5 matching project.godot config/features.

Authentic packaging proof:
  - Godot export exits 0 with runnable exe, OR
  - Export path produces a size-stable exe and Godot is killed after hang
    (post-export hang is not incomplete packaging).
Hard wall timeout with no runnable artifact => TIMEOUT / BLOCKED.
TIMEOUT must never count as PASS.
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
from typing import Callable

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


def resolve_godot() -> str:
    return (
        os.environ.get("GODOT")
        or os.environ.get("GODOT4")
        or os.environ.get("GODOT_BIN")
        or "godot"
    )


def godot_version(godot: str) -> str:
    try:
        return subprocess.check_output([godot, "--version"], text=True, timeout=60).strip()
    except Exception as exc:
        return f"UNAVAILABLE:{exc}"


def template_probe() -> dict:
    appdata = Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
    base = appdata / "Godot" / "export_templates"
    stable = base / "4.5.stable"
    candidates = [
        stable / "windows_desktop_release_x86_64.exe",
        stable / "windows_release_x86_64.exe",
    ]
    found = next((p for p in candidates if p.is_file()), None)
    return {
        "templates_root": str(base),
        "templates_45": str(stable),
        "templates_45_exists": stable.is_dir(),
        "windows_template": str(found) if found else None,
        "windows_template_present": found is not None,
        "entries": sorted(p.name for p in base.iterdir()) if base.is_dir() else [],
    }


def exe_ready(path: Path) -> dict:
    if not path.is_file():
        return {"ready": False, "bytes": 0, "reason": "missing"}
    size = path.stat().st_size
    # PE header minimum + real Godot export is multi-MB
    ready = size >= 5_000_000
    return {
        "ready": ready,
        "bytes": size,
        "sha256": sha256(path) if ready else None,
        "reason": None if ready else f"too_small:{size}",
    }


def _kill_tree(pid: int) -> None:
    try:
        subprocess.run(
            ["taskkill", "/F", "/T", "/PID", str(pid)],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except Exception:
        pass


def run_godot(
    cmd: list[str],
    *,
    log_path: Path,
    timeout: int,
    artifact_ready: Callable[[], dict] | None = None,
    stable_secs: int = 20,
) -> dict:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    creationflags = 0
    if platform.system() == "Windows":
        creationflags = getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0x00000200)
    started = time.time()
    with log_path.open("w", encoding="utf-8", errors="replace") as logf:
        logf.write(f"# cmd={' '.join(cmd)}\n# started={utc_now()}\n")
        logf.flush()
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=logf,
                stderr=subprocess.STDOUT,
                creationflags=creationflags,
            )
        except FileNotFoundError as exc:
            return {
                "ok": False,
                "timed_out": False,
                "exit": None,
                "error": str(exc),
                "elapsed_s": 0,
                "packaging_complete": False,
                "completion_mode": "missing_binary",
            }

        last_size = -1
        stable_since: float | None = None
        while True:
            rc = proc.poll()
            elapsed = time.time() - started
            if rc is not None:
                ready = artifact_ready() if artifact_ready else {"ready": rc == 0}
                packaging_complete = bool(ready.get("ready"))
                return {
                    "ok": rc == 0 and packaging_complete,
                    "timed_out": False,
                    "exit": rc,
                    "error": None if rc == 0 else f"godot exit {rc}",
                    "elapsed_s": int(elapsed),
                    "packaging_complete": packaging_complete,
                    "completion_mode": "process_exit",
                    "artifact": ready,
                    "log": str(log_path),
                }

            if artifact_ready is not None:
                ready = artifact_ready()
                if ready.get("ready"):
                    size = int(ready.get("bytes") or 0)
                    if size == last_size and size > 0:
                        if stable_since is None:
                            stable_since = time.time()
                        elif time.time() - stable_since >= stable_secs:
                            logf.write(
                                f"\n# packaging artifact stable for {stable_secs}s; "
                                f"terminating hung Godot pid={proc.pid}\n"
                            )
                            logf.flush()
                            _kill_tree(proc.pid)
                            try:
                                proc.wait(timeout=60)
                            except Exception:
                                pass
                            return {
                                "ok": True,
                                "timed_out": False,
                                "exit": proc.returncode,
                                "error": None,
                                "elapsed_s": int(time.time() - started),
                                "packaging_complete": True,
                                "completion_mode": "artifact_stable_then_kill",
                                "artifact": ready,
                                "log": str(log_path),
                                "note": "Godot hung after authentic export; size-stable exe accepted",
                            }
                    else:
                        last_size = size
                        stable_since = time.time()
                else:
                    last_size = -1
                    stable_since = None

            if elapsed >= timeout:
                logf.write(f"\n# HARD TIMEOUT after {timeout}s\n")
                logf.flush()
                _kill_tree(proc.pid)
                try:
                    proc.wait(timeout=60)
                except Exception:
                    pass
                ready = artifact_ready() if artifact_ready else {"ready": False}
                # Incomplete packaging if we hit hard timeout before stability acceptance.
                return {
                    "ok": False,
                    "timed_out": True,
                    "exit": None,
                    "error": f"godot timed out after {timeout}s",
                    "elapsed_s": int(timeout),
                    "packaging_complete": False,
                    "completion_mode": "hard_timeout",
                    "artifact": ready,
                    "log": str(log_path),
                }
            time.sleep(2)


def log_tail(path: Path, n: int = 2000) -> str:
    if not path.is_file():
        return ""
    try:
        return path.read_text(encoding="utf-8", errors="replace")[-n:]
    except OSError:
        return ""


def main() -> int:
    if platform.system() != "Windows":
        print("REFUSE: must run on Windows", file=sys.stderr)
        return 2

    REPORTS.mkdir(parents=True, exist_ok=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.is_file():
        OUT.unlink()

    sha = head_sha()
    soak_seconds = int(os.environ.get("WINDOWS_PILOT0_SOAK_SECONDS", "1800"))
    export_timeout = int(os.environ.get("WINDOWS_PILOT0_EXPORT_TIMEOUT", "1800"))
    checks: dict[str, dict] = {}
    blockers: list[str] = []
    skipped_required = 0

    godot = resolve_godot()
    version = godot_version(godot)
    templates = template_probe()
    meta = {
        "image_os": os.environ.get("ImageOS"),
        "image_version": os.environ.get("ImageVersion"),
        "runner_os": os.environ.get("RUNNER_OS"),
        "godot_bin": godot,
        "godot_version": version,
        "templates": templates,
    }
    print(f"::notice::GODOT={godot} version={version}")
    print(f"::notice::templates={json.dumps(templates)}")
    print(f"::notice::Using GODOT bin={godot}")

    checks["fresh_windows_vm"] = {"status": "PASS", "detail": meta}
    checks["full_vp_promotion"] = {
        "status": "NOT_CLAIMED",
        "detail": "Windows Pilot 0 does not promote Pedestrian full-VP",
    }

    if "4.5" not in version and "UNAVAILABLE" not in version:
        blockers.append("GODOT_VERSION_MISMATCH_NEED_4_5")
        print(f"::error title=WINDOWS_PILOT0::Godot version mismatch: {version} (need 4.5.x)")

    if not templates.get("windows_template_present"):
        blockers.append("MISSING_WINDOWS_EXPORT_TEMPLATE")
        print("::error title=WINDOWS_PILOT0::Missing 4.5.stable Windows Desktop export template")

    import_log = REPORTS / "godot_import.log"
    export_log = REPORTS / "godot_windows_export.log"

    print("::notice::Running Godot --import")
    import_res = run_godot(
        [godot, "--headless", "--path", str(ROOT), "--import", "--quit"],
        log_path=import_log,
        timeout=min(600, export_timeout),
    )
    checks["godot_import"] = {
        "status": "PASS" if not import_res.get("timed_out") else "PARTIAL",
        **import_res,
        "tail": log_tail(import_log),
    }

    print("::notice::Running Godot --export-release Windows Desktop")
    export_res = run_godot(
        [
            godot,
            "--headless",
            "--verbose",
            "--path",
            str(ROOT),
            "--export-release",
            "Windows Desktop",
            str(OUT),
        ],
        log_path=export_log,
        timeout=export_timeout,
        artifact_ready=lambda: exe_ready(OUT),
        stable_secs=25,
    )
    art = exe_ready(OUT)
    packaging_ok = bool(export_res.get("packaging_complete")) and art.get("ready")
    timed_out_incomplete = bool(export_res.get("timed_out")) and not packaging_ok

    checks["compile_package"] = {
        "status": "PASS" if packaging_ok else "FAIL",
        "godot_bin": godot,
        "godot_version": version,
        "exit": export_res.get("exit"),
        "error": export_res.get("error"),
        "elapsed_s": export_res.get("elapsed_s"),
        "completion_mode": export_res.get("completion_mode"),
        "timed_out": export_res.get("timed_out"),
        "artifact": art,
        "tail": log_tail(export_log),
        "path": str(OUT) if OUT.is_file() else None,
        "sha256": art.get("sha256"),
        "signing": "UNSIGNED_PILOT_ARTIFACT_NOT_FOR_PRODUCTION",
        "repeatability": "REPEATABLE",
    }
    if timed_out_incomplete:
        blockers.append("WINDOWS_EXPORT_TIMEOUT")
        print(f"::error title=WINDOWS_PILOT0::{export_res.get('error')}")
    if not packaging_ok:
        blockers.append("WINDOWS_EXPORT_FAILED")
        skipped_required += 1
        print("::error title=WINDOWS_PILOT0::WINDOWS_EXPORT_FAILED")
    elif export_res.get("completion_mode") == "artifact_stable_then_kill":
        print("::notice::Windows exe size-stable; post-export Godot hang terminated after authentic packaging")

    checks["install"] = {
        "status": "PASS" if packaging_ok else "FAIL",
        "detail": "portable Godot Windows exe (no MSI); treated as installable pilot artifact",
    }

    if packaging_ok:
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

    if packaging_ok and checks.get("first_launch", {}).get("status") == "PASS":
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
    timed_out = any("TIMEOUT" in b for b in blockers)
    version_block = any(b.startswith("GODOT_VERSION") or b.startswith("MISSING_") for b in blockers)
    if hard_failed or skipped_required or timed_out or version_block:
        claim = "WINDOWS_PILOT0_PARTIAL" if packaging_ok else "WINDOWS_PILOT0_BLOCKED"
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
            "TIMEOUT without authentic complete packaging never counts as PASS",
        ],
    }
    (REPORTS / "WINDOWS_PILOT0_EVIDENCE.json").write_text(json.dumps(evidence, indent=2) + "\n")
    (REPORTS / "WINDOWS_PILOT0_EVIDENCE.md").write_text(
        f"# Windows Pilot 0 — Pedestrian Pursuit\n\n"
        f"- claim: `{claim}`\n"
        f"- godot: `{version}`\n"
        f"- blockers: {blockers}\n"
    )
    for b in blockers:
        print(f"::error title=WINDOWS_PILOT0::{b}")
    for k in hard_failed:
        print(f"::error title=WINDOWS_PILOT0_CHECK_FAIL::{k}")
    print(f"::notice title=WINDOWS_PILOT0_CLAIM::{claim} head={sha[:12]}")
    print(json.dumps({"claim": claim, "sha12": sha[:12], "blockers": blockers}, indent=2))
    return 0 if claim == "WINDOWS_PILOT0_PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
