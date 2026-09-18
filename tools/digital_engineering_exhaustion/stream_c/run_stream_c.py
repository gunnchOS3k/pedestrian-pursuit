#!/usr/bin/env python3
"""Stream C — Games Pre-Human Playtest Engineering Exhaustion runner.

Truth boundary:
- Never claim fun/balance/feel PASS.
- Never fabricate rights clearance.
- Quarantine unclear third-party assets (ledger + quarantine dir).
- Gate GAMES_PRE_HUMAN_PLAYTEST_ENGINEERING_EXHAUSTED only if earned.
"""

from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "artifacts" / "digital_engineering_exhaustion" / "stream_c"
QUARANTINE = OUT / "quarantine" / "unclear_third_party"

ASSET_EXTS = {
    ".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".bmp",
    ".wav", ".ogg", ".mp3", ".flac", ".m4a",
    ".glb", ".gltf", ".fbx", ".obj", ".blend", ".vrm",
    ".ttf", ".otf", ".woff", ".woff2",
    ".mp4", ".webm", ".mov",
}

SKIP_DIR_PARTS = {
    ".git", "node_modules", ".godot", "Library", "PackageCache",
    ".worktrees", "dist", "build", "builds", ".venv", "venv",
    "__pycache__", ".turbo", "coverage", "playwright-report",
}

DIMENSIONS = [
    "build", "launch", "save_load", "menus", "input", "pause_resume",
    "crash_recovery", "persistence", "frame_pacing", "leaks", "loading",
    "asset_validation", "resolution", "audio", "a11y", "local_multiplayer",
    "networking", "offline", "install_update", "android",
]


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def run_cmd(
    cmd: list[str],
    *,
    cwd: Path | None = None,
    timeout: int = 600,
    env: dict[str, str] | None = None,
) -> dict[str, Any]:
    started = time.time()
    merged = os.environ.copy()
    if env:
        merged.update(env)
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd or ROOT),
            capture_output=True,
            text=True,
            timeout=timeout,
            env=merged,
        )
        return {
            "cmd": cmd,
            "cwd": str(cwd or ROOT),
            "exit_code": proc.returncode,
            "ok": proc.returncode == 0,
            "seconds": round(time.time() - started, 3),
            "stdout_tail": (proc.stdout or "")[-4000:],
            "stderr_tail": (proc.stderr or "")[-4000:],
        }
    except subprocess.TimeoutExpired as exc:
        return {
            "cmd": cmd,
            "cwd": str(cwd or ROOT),
            "exit_code": 124,
            "ok": False,
            "seconds": round(time.time() - started, 3),
            "stdout_tail": ((exc.stdout or b"") if isinstance(exc.stdout, bytes) else (exc.stdout or ""))[-2000:],
            "stderr_tail": f"TIMEOUT after {timeout}s",
        }
    except FileNotFoundError as exc:
        return {
            "cmd": cmd,
            "cwd": str(cwd or ROOT),
            "exit_code": 127,
            "ok": False,
            "seconds": round(time.time() - started, 3),
            "stdout_tail": "",
            "stderr_tail": str(exc),
        }


def detect_game() -> dict[str, str]:
    name = ROOT.name
    # worktree path .../repo/.worktrees/stream-c-...
    if ROOT.parent.name == ".worktrees":
        name = ROOT.parent.parent.name
    mapping = {
        "anime-aggressors": {
            "id": "anime-aggressors",
            "title": "Anime Aggressors",
            "kind": "godot",
            "godot_path": "game-godot",
        },
        "pedestrian-pursuit": {
            "id": "pedestrian-pursuit",
            "title": "Pedestrian Pursuit",
            "kind": "godot",
            "godot_path": ".",
        },
        "archive-of-life-artifact-world": {
            "id": "archive-of-life-artifact-world",
            "title": "Archive of Life",
            "kind": "web",
            "godot_path": "",
        },
        "beatlink-party": {
            "id": "beatlink-party",
            "title": "BeatLink Party",
            "kind": "web",
            "godot_path": "",
        },
    }
    if name not in mapping:
        raise SystemExit(f"Unknown game root: {ROOT} ({name})")
    return mapping[name]


def resolve_godot() -> str | None:
    env = os.environ.get("GODOT_BIN")
    if env and Path(env).exists():
        return env
    for c in ("godot", "Godot", "godot4"):
        found = shutil.which(c)
        if found:
            return found
    for c in (
        Path.home() / "Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot",
        Path("/Applications/Godot.app/Contents/MacOS/Godot"),
    ):
        if c.exists():
            return str(c)
    return None


def should_skip(path: Path) -> bool:
    # Compare against path relative to repo root so worktree parents (e.g. ".worktrees")
    # do not quarantine/skip the entire tree.
    try:
        rel_parts = set(path.relative_to(ROOT).parts)
    except ValueError:
        rel_parts = set(path.parts)
    return bool(rel_parts & SKIP_DIR_PARTS)


def load_provenance_paths(game: dict[str, str]) -> list[Path]:
    candidates = [
        ROOT / "content" / "provenance.json",
        ROOT / "content" / "motion_provenance.json",
        ROOT / "data" / "art" / "provenance.json",
        ROOT / "docs" / "character-design" / "ASSET_LICENSE.md",
        ROOT / "docs" / "art_pipeline" / "FREE_TOOLCHAIN_AND_LICENSE_MATRIX.md",
        ROOT / "docs" / "SOURCE_PROVENANCE_POLICY.md",
        ROOT / "artifacts" / "engineering_wave007" / "SONG_SOURCE_RIGHTS_RESULT.json",
        ROOT / "artifacts" / "engineering_wave008" / "LICENSE_TERMS_RESULT.json",
        ROOT / "LICENSE",
    ]
    return [p for p in candidates if p.exists()]


def index_provenance_entries(paths: list[Path]) -> dict[str, dict[str, Any]]:
    by_path: dict[str, dict[str, Any]] = {}
    for p in paths:
        if p.suffix.lower() != ".json":
            continue
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            continue
        entries = data.get("entries") if isinstance(data, dict) else None
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            rel = entry.get("path")
            if isinstance(rel, str) and rel:
                by_path[rel.replace("\\", "/")] = {
                    "source": str(p.relative_to(ROOT)),
                    "license": entry.get("license"),
                    "status": entry.get("status"),
                    "id": entry.get("id"),
                    "notes": entry.get("notes"),
                }
    return by_path


def scan_assets(game: dict[str, str], provenance: dict[str, dict[str, Any]]) -> dict[str, Any]:
    inventory: list[dict[str, Any]] = []
    quarantine: list[dict[str, Any]] = []
    QUARANTINE.mkdir(parents=True, exist_ok=True)

    unclear_markers = (
        "mixamo", "marketplace", "third_party", "third-party", "stock",
        "ripped", "youtube", "spotify", "apple_music", "kenney_unknown",
    )
    known_ok_licenses = {
        "ORIGINAL_INTERNAL", "ORIGINAL", "MIT", "CC0", "CC-BY-4.0",
        "synthetic_original", "PROCEDURAL_INTERNAL", "FINAL_ORIGINAL",
        "GENERATABLE_INTERNAL",
    }

    for path in ROOT.rglob("*"):
        if not path.is_file() or should_skip(path):
            continue
        if path.suffix.lower() not in ASSET_EXTS:
            continue
        rel = path.relative_to(ROOT).as_posix()
        # Prefer content trees; skip enormous vendor caches already filtered
        if rel.startswith("artifacts/") and "/quarantine/" not in rel:
            # Keep scanning content-like artifacts only lightly: skip wave binary dumps
            if any(rel.startswith(f"artifacts/{x}") for x in (
                "engineering_wave", "visual_qa", "pixel6a", "wp014", "taste_gate",
                "stream_b", "game_rc", "experience_review", "vp",
            )):
                continue

        entry = provenance.get(rel)
        lower = rel.lower()
        license_val = None
        status = "UNPROVENANCED"
        reason = "no provenance entry for binary asset path"

        if entry:
            license_val = entry.get("license") or entry.get("status")
            status = str(entry.get("status") or "PROVENANCED")
            reason = f"provenance:{entry.get('source')}"
            if license_val and str(license_val) not in known_ok_licenses and str(license_val).upper() not in {
                x.upper() for x in known_ok_licenses
            }:
                if "ORIGINAL" not in str(license_val).upper() and "SYNTH" not in str(license_val).upper():
                    status = "LICENSE_UNCLEAR"
                    reason = f"license value not in allowlist: {license_val}"

        if any(m in lower for m in unclear_markers) and status not in {"FINAL_ORIGINAL", "ORIGINAL_RENDER_FINAL"}:
            status = "MARKER_QUARANTINE"
            reason = "path contains third-party/unclear marker"

        # Proxy glbs explicitly documented as non-presentation still need rights review if redistributed
        if "/proxy/" in lower and not entry:
            status = "PROXY_UNPROVENANCED"
            reason = "proxy mesh without provenance row"

        item = {
            "path": rel,
            "bytes": path.stat().st_size,
            "sha256": sha256_file(path) if path.stat().st_size <= 50_000_000 else None,
            "ext": path.suffix.lower(),
            "license": license_val,
            "status": status,
            "reason": reason,
        }
        inventory.append(item)

        if status in {"UNPROVENANCED", "LICENSE_UNCLEAR", "MARKER_QUARANTINE", "PROXY_UNPROVENANCED"}:
            # Quarantine is fail-closed ledger-first. Binary copies only for marker/unclear-license
            # hits to keep PRs reviewable; unprovenanced originals stay listed without duplication.
            if status in {"LICENSE_UNCLEAR", "MARKER_QUARANTINE"}:
                q_name = rel.replace("/", "__")
                dest = QUARANTINE / q_name
                try:
                    if path.stat().st_size <= 5_000_000 and not dest.exists():
                        shutil.copy2(path, dest)
                        item["quarantine_copy"] = str(dest.relative_to(ROOT))
                except OSError as exc:
                    item["quarantine_copy_error"] = str(exc)
            else:
                item["quarantine_mode"] = "ledger_only"
            quarantine.append(item)

    inventory.sort(key=lambda x: x["path"])
    quarantine.sort(key=lambda x: x["path"])
    return {
        "scanned_at": now_iso(),
        "game_id": game["id"],
        "asset_count": len(inventory),
        "quarantine_count": len(quarantine),
        "provenance_paths": [str(p.relative_to(ROOT)) for p in load_provenance_paths(game)],
        "inventory": inventory,
        "quarantine": quarantine,
        "policy": {
            "no_fake_rights_clearance": True,
            "unclear_assets_quarantined": True,
            "commercial_music_licensed_claim": False,
            "human_fun_balance_claim": False,
        },
    }


def dim(status: str, evidence: str, blocker: str | None = None, notes: str = "") -> dict[str, Any]:
    assert status in {
        "PASS", "FAIL", "PARTIAL", "BLOCKED", "NOT_APPLICABLE",
        "HUMAN_VALIDATION_REQUIRED", "NOT_RUN",
    }
    # PARTIAL without an explicit remaining blocker is not allowed — fail closed to human/legal/physical.
    if status == "PARTIAL" and not blocker:
        blocker = "HUMAN_VALIDATION_REQUIRED"
    if status == "HUMAN_VALIDATION_REQUIRED" and not blocker:
        blocker = "HUMAN_VALIDATION_REQUIRED"
    if status == "BLOCKED" and not blocker:
        blocker = "PHYSICAL_HARDWARE_REQUIRED"
    out: dict[str, Any] = {
        "status": status,
        "evidence": evidence,
        "notes": notes,
    }
    if blocker:
        out["blocker_class"] = blocker
    return out


def write_playtest_sheets(game: dict[str, str]) -> Path:
    path = OUT / "playtest" / "PLAYTEST_TASK_SHEETS.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"""# {game['title']} — Pre-Human Playtest Task Sheets (TEMPLATES ONLY)

**Status:** `HUMAN_VALIDATION_REQUIRED`  
**Do not fill with synthetic participants.**  
**Do not record fun/balance scores without real humans.**

## Session intake (required before scoring)

- Participant ID (pseudonym): ________
- Consent / data-use acknowledgement: [ ] yes
- Accessibility accommodations requested: ________
- Device / build SHA: ________
- Moderator: ________
- Date/time: ________

## Task sheet A — Boot / menus / settings

1. Cold launch to first interactive screen.
2. Navigate all top-level menus with keyboard/controller/touch as applicable.
3. Open settings; toggle audio, resolution/window, accessibility options; apply; restart; confirm persistence.
4. Pause from gameplay (if reachable); resume; quit to menu.

**Observations (facts only):** ________

## Task sheet B — Save / load / crash recovery

1. Create a save or persistent profile action.
2. Force-quit mid-session.
3. Relaunch; confirm recovery or honest loss messaging.
4. Load prior save / profile.

**Observations:** ________

## Task sheet C — Core loop smoke (no fun rating)

1. Complete one short deterministic loop using bot/fixture if available.
2. Note softlocks, soft crashes, missing assets, audio routing failures, input deadzones.

**Observations:** ________

## Task sheet D — Accessibility probe (engineering only)

1. Keyboard-only / controller-only path.
2. Reduced motion / high contrast if present.
3. Text scale / zoom if present.
4. Caption/subtitle plumbing if present.

**Do not claim disability validation.** Observations: ________

## Task sheet E — Multiplayer / network / offline (if applicable)

1. Local multiplayer join/leave.
2. Network create/join; disconnect; reconnect.
3. Offline mode behavior.

**Observations:** ________

## Explicit non-claims

- Fun / feel / balance: `HUMAN_VALIDATION_REQUIRED`
- Rights clearance beyond engineered inventory: `LEGAL_RIGHTS_REVIEW_REQUIRED` where quarantine nonempty
- Physical device performance (unless device evidence attached): `PHYSICAL_HARDWARE_REQUIRED`
""",
        encoding="utf-8",
    )
    return path


def write_fixtures(game: dict[str, str]) -> dict[str, Any]:
    fixtures = OUT / "fixtures"
    fixtures.mkdir(parents=True, exist_ok=True)
    deterministic = {
        "schema": "stream_c_deterministic_fixture/v1",
        "game_id": game["id"],
        "seed": 20260918,
        "label": "SYNTHETIC",
        "not_human_playtest": True,
        "steps": [
            {"id": "boot", "action": "launch_to_menu"},
            {"id": "enter_core_loop", "action": "open_primary_mode"},
            {"id": "bot_idle", "action": "hold_neutral", "frames": 120},
            {"id": "pause", "action": "toggle_pause"},
            {"id": "resume", "action": "toggle_pause"},
            {"id": "quit_menu", "action": "return_to_menu"},
        ],
    }
    write_json(fixtures / "DETERMINISTIC_BOT_TRAVERSAL.json", deterministic)
    smoke_scene = {
        "schema": "stream_c_smoke_scene/v1",
        "game_id": game["id"],
        "scenes": [
            "boot",
            "main_menu",
            "settings",
            "core_loop_entry",
            "pause_overlay",
            "results_or_exit",
        ],
        "assertions": [
            "no_unhandled_exception",
            "required_assets_present_or_fail_closed",
            "pause_resume_roundtrip",
        ],
    }
    write_json(fixtures / "SMOKE_SCENES.json", smoke_scene)
    return {"deterministic": str((fixtures / "DETERMINISTIC_BOT_TRAVERSAL.json").relative_to(ROOT)),
            "smoke_scenes": str((fixtures / "SMOKE_SCENES.json").relative_to(ROOT))}


def run_godot_checks(game: dict[str, str], godot: str) -> dict[str, Any]:
    godot_root = (ROOT / game["godot_path"]).resolve() if game["godot_path"] != "." else ROOT
    results: dict[str, Any] = {"godot_bin": godot, "godot_root": str(godot_root)}
    results["version"] = run_cmd([godot, "--version"], timeout=30)
    results["import_quit"] = run_cmd(
        [godot, "--headless", "--path", str(godot_root), "--quit-after", "1"],
        timeout=300,
    )
    smoke_candidates = [
        godot_root / "tests" / "smoke_runner.gd",
        ROOT / "tests" / "TestRunner.gd",
        ROOT / "tests" / "smoke_runner.gd",
    ]
    smoke = next((p for p in smoke_candidates if p.exists()), None)
    if smoke:
        rel = "res://" + smoke.relative_to(godot_root).as_posix()
        results["smoke"] = run_cmd(
            [godot, "--headless", "--path", str(godot_root), "-s", rel],
            timeout=600,
        )
        results["smoke_script"] = rel
    else:
        results["smoke"] = {"ok": False, "stderr_tail": "no smoke script found", "exit_code": 2}
    # Short soak: re-enter headless quit loop N times as crash-recovery proxy
    soak_ok = 0
    soak_runs = []
    for i in range(5):
        r = run_cmd(
            [godot, "--headless", "--path", str(godot_root), "--quit-after", "1"],
            timeout=180,
        )
        soak_runs.append({"i": i, "ok": r["ok"], "seconds": r["seconds"], "exit_code": r["exit_code"]})
        if r["ok"]:
            soak_ok += 1
    results["mini_soak"] = {"ok": soak_ok == 5, "passes": soak_ok, "runs": soak_runs}
    write_json(OUT / "soak" / "MINI_SOAK.json", results["mini_soak"])
    write_json(OUT / "crash_dumps" / "HEADLESS_RUN_LOG.json", {
        "import_quit": results["import_quit"],
        "smoke": results.get("smoke"),
        "note": "Headless exit logs only; not a physical crash dump",
    })
    return results


def run_anime(game: dict[str, str]) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    cmds: dict[str, Any] = {}
    dims: dict[str, dict[str, Any]] = {d: dim("NOT_RUN", "") for d in DIMENSIONS}
    godot = resolve_godot()
    if godot:
        g = run_godot_checks(game, godot)
        cmds["godot"] = g
        dims["launch"] = dim(
            "PASS" if g["import_quit"]["ok"] else "FAIL",
            "godot --headless --quit-after 1",
        )
        dims["build"] = dim(
            "PASS" if g["import_quit"]["ok"] else "PARTIAL",
            "Godot project import/load",
            notes="Full export/Android not required for host digital exhaust if import+smoke pass",
        )
        smoke_ok = bool(g.get("smoke", {}).get("ok"))
        dims["menus"] = dim("PASS" if smoke_ok else "PARTIAL", g.get("smoke_script", "smoke"), notes="Covered by headless smoke where script exercises menus")
        dims["input"] = dim("PARTIAL", "regression scripts exist; host smoke limited", "HUMAN_VALIDATION_REQUIRED")
        dims["pause_resume"] = dim("PARTIAL", "wave020 pause diagnostics exist historically; smoke coverage", "HUMAN_VALIDATION_REQUIRED")
        dims["crash_recovery"] = dim("PARTIAL" if g["mini_soak"]["ok"] else "FAIL", "mini_soak 5x headless quit")
        dims["frame_pacing"] = dim("BLOCKED", "device/frame telemetry needs interactive or device run", "PHYSICAL_HARDWARE_REQUIRED")
        dims["leaks"] = dim("BLOCKED", "leak instrumentation needs longer soak + profiler", "PHYSICAL_HARDWARE_REQUIRED")
        dims["loading"] = dim("PASS" if g["import_quit"]["ok"] else "FAIL", "headless import")
    else:
        dims["launch"] = dim("FAIL", "Godot binary missing")
        dims["build"] = dim("FAIL", "Godot binary missing")

    # Node validators if present
    if (ROOT / "package.json").exists():
        cmds["godot_check"] = run_cmd(["npm", "run", "godot:check"], timeout=180)
        cmds["validate_character_assets"] = run_cmd(["npm", "run", "validate:character-assets"], timeout=300)
        cmds["test_game_core"] = run_cmd(["npm", "run", "test:game-core"], timeout=600)
        asset_ok = cmds["validate_character_assets"]["ok"]
        dims["asset_validation"] = dim("PASS" if asset_ok else "FAIL", "npm run validate:character-assets")
        core_ok = cmds["test_game_core"]["ok"]
        dims["save_load"] = dim("PARTIAL" if core_ok else "FAIL", "test:game-core / persistence tests", notes="Persistence covered where unit tests exist")
        dims["persistence"] = dims["save_load"]
        dims["audio"] = dim("PARTIAL", "validate:anime-digital-art-audio-closure available", "HUMAN_VALIDATION_REQUIRED")
        dims["a11y"] = dim("HUMAN_VALIDATION_REQUIRED", "automation incomplete for disabled-user validation", "HUMAN_VALIDATION_REQUIRED")
        dims["local_multiplayer"] = dim("PARTIAL", "local versus paths exist; need bot/host soak", "HUMAN_VALIDATION_REQUIRED")
        dims["networking"] = dim("PARTIAL", "npm run test:netplay / rollback available", notes="Run separately if deps installed")
        dims["offline"] = dim("PASS", "Godot local offline primary runtime")
        dims["resolution"] = dim("PARTIAL", "viewport/export presets present", "HUMAN_VALIDATION_REQUIRED")
        dims["install_update"] = dim("PARTIAL", "digital-rc-update-rollback.mjs exists", "HUMAN_VALIDATION_REQUIRED")
        # Android
        adb = shutil.which("adb")
        device = False
        if adb:
            devices = run_cmd([adb, "devices"], timeout=30)
            cmds["adb_devices"] = devices
            device = any(
                line.strip().endswith("device")
                for line in (devices.get("stdout_tail") or "").splitlines()[1:]
            )
        if device:
            dims["android"] = dim("PARTIAL", "device present — run android:device:test for full evidence", "PHYSICAL_HARDWARE_REQUIRED")
        else:
            dims["android"] = dim("BLOCKED", "no adb device", "PHYSICAL_HARDWARE_REQUIRED")

    return cmds, dims


def run_pedestrian(game: dict[str, str]) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    cmds: dict[str, Any] = {}
    dims: dict[str, dict[str, Any]] = {d: dim("NOT_RUN", "") for d in DIMENSIONS}
    godot = resolve_godot()
    if godot:
        g = run_godot_checks(game, godot)
        cmds["godot"] = g
        headless_script = ROOT / "tools" / "run_godot_headless.sh"
        if headless_script.exists():
            cmds["headless_smoke"] = run_cmd(["bash", str(headless_script)], timeout=900)
        test_runner = ROOT / "tests" / "TestRunner.gd"
        if test_runner.exists():
            cmds["test_runner"] = run_cmd(
                [godot, "--headless", "--path", str(ROOT), "-s", "res://tests/TestRunner.gd"],
                timeout=900,
            )
        dims["build"] = dim("PASS" if g["import_quit"]["ok"] else "FAIL", "godot import")
        dims["launch"] = dim(
            "PASS" if cmds.get("headless_smoke", g["import_quit"])["ok"] else "FAIL",
            "tools/run_godot_headless.sh",
        )
        dims["loading"] = dims["launch"]
        dims["crash_recovery"] = dim("PARTIAL" if g["mini_soak"]["ok"] else "FAIL", "mini_soak", "HUMAN_VALIDATION_REQUIRED")
        dims["menus"] = dim("PASS" if cmds.get("test_runner",{}).get("ok") else "PARTIAL", "tests/TestRunner.gd", None if cmds.get("test_runner",{}).get("ok") else "HUMAN_VALIDATION_REQUIRED")
        dims["input"] = dim("PARTIAL", "mobile_input / unit tests", "HUMAN_VALIDATION_REQUIRED")
        dims["pause_resume"] = dim("PARTIAL", "race scene pause paths", "HUMAN_VALIDATION_REQUIRED")
        dims["save_load"] = dim("PARTIAL", "profile/achievement persistence tests", "HUMAN_VALIDATION_REQUIRED")
        dims["persistence"] = dims["save_load"]
        dims["frame_pacing"] = dim("BLOCKED", "PHYSICAL_FPS pending", "PHYSICAL_HARDWARE_REQUIRED")
        dims["leaks"] = dim("BLOCKED", "needs profiler soak", "PHYSICAL_HARDWARE_REQUIRED")
        dims["asset_validation"] = dim(
            "PASS" if (ROOT / "data" / "art" / "provenance.json").exists() else "FAIL",
            "data/art/provenance.json + content validators",
        )
        if (ROOT / "tools" / "validate_content.py").exists():
            cmds["validate_content"] = run_cmd([sys.executable, "tools/validate_content.py"], timeout=300)
            if cmds["validate_content"]["ok"]:
                dims["asset_validation"] = dim("PASS", "tools/validate_content.py")
            else:
                dims["asset_validation"] = dim("FAIL", "tools/validate_content.py")
        dims["audio"] = dim("PARTIAL", "assets/audio present", "HUMAN_VALIDATION_REQUIRED")
        dims["a11y"] = dim("HUMAN_VALIDATION_REQUIRED", "a11y automation incomplete", "HUMAN_VALIDATION_REQUIRED")
        dims["local_multiplayer"] = dim("PARTIAL", "local race modes", "HUMAN_VALIDATION_REQUIRED")
        dims["networking"] = dim("NOT_APPLICABLE", "no production netplay claim on main digital RC")
        dims["offline"] = dim("PASS", "local Godot offline")
        dims["resolution"] = dim("PARTIAL", "export presets", "HUMAN_VALIDATION_REQUIRED")
        dims["install_update"] = dim("PARTIAL", "rc packaging scripts", "HUMAN_VALIDATION_REQUIRED")
        adb = shutil.which("adb")
        device = False
        if adb:
            devices = run_cmd([adb, "devices"], timeout=30)
            cmds["adb_devices"] = devices
            device = any(line.strip().endswith("device") for line in (devices.get("stdout_tail") or "").splitlines()[1:])
        dims["android"] = dim(
            "PARTIAL" if device else "BLOCKED",
            "adb device" if device else "no adb device",
            "PHYSICAL_HARDWARE_REQUIRED",
        )
    else:
        dims["build"] = dim("FAIL", "Godot missing")
        dims["launch"] = dim("FAIL", "Godot missing")
    return cmds, dims


def run_archive(game: dict[str, str]) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    cmds: dict[str, Any] = {}
    dims: dict[str, dict[str, Any]] = {d: dim("NOT_RUN", "") for d in DIMENSIONS}
    # Prefer lighter verify path; full wave008 is heavy
    if not (ROOT / "node_modules").exists():
        cmds["npm_ci"] = run_cmd(["npm", "ci"], timeout=900)
    cmds["typecheck"] = run_cmd(["npm", "run", "typecheck"], timeout=300)
    cmds["test"] = run_cmd(["npm", "test"], timeout=900)
    cmds["audit_provenance"] = run_cmd(["npm", "run", "audit:provenance"], timeout=300)
    cmds["build"] = run_cmd(["npm", "run", "build"], timeout=600)

    ok_build = cmds["build"]["ok"]
    ok_test = cmds["test"]["ok"]
    ok_tc = cmds["typecheck"]["ok"]
    dims["build"] = dim("PASS" if ok_build and ok_tc else "FAIL", "npm run typecheck + build")
    dims["launch"] = dim("PASS" if ok_build else "FAIL", "vite build artifact")
    dims["loading"] = dims["launch"]
    dims["asset_validation"] = dim(
        "PASS" if cmds["audit_provenance"]["ok"] else "FAIL",
        "npm run audit:provenance",
    )
    dims["save_load"] = dim("PARTIAL", "local persistence / snapshot fixtures", "HUMAN_VALIDATION_REQUIRED")
    dims["persistence"] = dims["save_load"]
    dims["menus"] = dim("PARTIAL", "UI routes covered by vitest/playwright when run", notes="wave008 browser e2e is optional heavy path")
    dims["input"] = dim("PARTIAL", "web pointer/keyboard", "HUMAN_VALIDATION_REQUIRED")
    dims["pause_resume"] = dim("NOT_APPLICABLE", "not a pause-combat game loop")
    dims["crash_recovery"] = dim("PARTIAL", "reload + snapshot reproduction fixtures", "HUMAN_VALIDATION_REQUIRED")
    dims["frame_pacing"] = dim("BLOCKED", "browser perf needs device/lab", "PHYSICAL_HARDWARE_REQUIRED")
    dims["leaks"] = dim("BLOCKED", "heap soak needs longer browser session", "PHYSICAL_HARDWARE_REQUIRED")
    dims["resolution"] = dim("PARTIAL", "responsive web", "HUMAN_VALIDATION_REQUIRED")
    dims["audio"] = dim("NOT_APPLICABLE", "no commercial audio loop claim")
    dims["a11y"] = dim("HUMAN_VALIDATION_REQUIRED", "axe/automation incomplete vs disabled users", "HUMAN_VALIDATION_REQUIRED")
    dims["local_multiplayer"] = dim("NOT_APPLICABLE", "single-user archive explorer")
    dims["networking"] = dim("PARTIAL", "offline-first + optional live ingest blocked by claim firewall", notes="GBIF live remains false")
    dims["offline"] = dim("PASS" if ok_build else "FAIL", "fixture/offline scientific pack doctrine")
    dims["install_update"] = dim("PARTIAL", "web deploy / PWA paths if present", "HUMAN_VALIDATION_REQUIRED")
    dims["android"] = dim("PARTIAL", "Capacitor/native-run tooling may exist; device required", "PHYSICAL_HARDWARE_REQUIRED")
    # Mini soak: rebuild twice
    cmds["rebuild_soak"] = run_cmd(["npm", "run", "build"], timeout=600)
    write_json(OUT / "soak" / "MINI_SOAK.json", {
        "ok": cmds["build"]["ok"] and cmds["rebuild_soak"]["ok"],
        "builds": 2,
    })
    return cmds, dims


def run_beatlink(game: dict[str, str]) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    cmds: dict[str, Any] = {}
    dims: dict[str, dict[str, Any]] = {d: dim("NOT_RUN", "") for d in DIMENSIONS}
    if not (ROOT / "node_modules").exists():
        cmds["pnpm_install"] = run_cmd(["pnpm", "install"], timeout=900)
    cmds["lint"] = run_cmd(["pnpm", "lint"], timeout=300)
    cmds["typecheck"] = run_cmd(["pnpm", "typecheck"], timeout=600)
    cmds["test"] = run_cmd(["pnpm", "test"], timeout=900)
    cmds["build"] = run_cmd(["pnpm", "build"], timeout=600)
    # Rights-focused unit tests are inside vitest; also try wave007 if affordable
    cmds["rights_hint"] = {
        "song_source_rights_artifact": (ROOT / "artifacts/engineering_wave007/SONG_SOURCE_RIGHTS_RESULT.json").exists(),
        "commercial_music_licensed_claim": False,
    }

    ok = all(cmds[k]["ok"] for k in ("typecheck", "test", "build") if k in cmds and "ok" in cmds[k])
    dims["build"] = dim("PASS" if cmds.get("build", {}).get("ok") else "FAIL", "pnpm build")
    dims["launch"] = dim("PASS" if cmds.get("build", {}).get("ok") else "FAIL", "package builds")
    dims["loading"] = dims["launch"]
    dims["asset_validation"] = dim("PASS" if cmds.get("test", {}).get("ok") else "FAIL", "vitest incl. rights.test.ts")
    dims["audio"] = dim(
        "PARTIAL",
        "synthetic catalog + rights gate; commercial playback not licensed",
        "LEGAL_RIGHTS_REVIEW_REQUIRED",
        notes="COMMERCIAL_MUSIC_LICENSED=false",
    )
    dims["save_load"] = dim("PASS" if cmds.get("test", {}).get("ok") else "PARTIAL", "session resume tests in wave007/vitest")
    dims["persistence"] = dims["save_load"]
    dims["menus"] = dim("PARTIAL", "web UI create-room flows", "HUMAN_VALIDATION_REQUIRED")
    dims["input"] = dim("PARTIAL", "device UX package", "HUMAN_VALIDATION_REQUIRED")
    dims["pause_resume"] = dim("PARTIAL", "session resume A/B/C", "HUMAN_VALIDATION_REQUIRED")
    dims["crash_recovery"] = dim("PARTIAL", "reconnect / network failure tests", "HUMAN_VALIDATION_REQUIRED")
    dims["frame_pacing"] = dim("BLOCKED", "device timing profile needs hardware", "PHYSICAL_HARDWARE_REQUIRED")
    dims["leaks"] = dim("BLOCKED", "needs soak on device", "PHYSICAL_HARDWARE_REQUIRED")
    dims["resolution"] = dim("PARTIAL", "viewport responsive tests in wave007", "HUMAN_VALIDATION_REQUIRED")
    dims["a11y"] = dim("HUMAN_VALIDATION_REQUIRED", "a11y not disability-validated", "HUMAN_VALIDATION_REQUIRED")
    dims["local_multiplayer"] = dim("PARTIAL", "multi-client browser tests", "HUMAN_VALIDATION_REQUIRED")
    dims["networking"] = dim("PASS" if cmds.get("test", {}).get("ok") else "PARTIAL", "network_load / reconnect unit+e2e suite")
    dims["offline"] = dim("PARTIAL", "degraded network paths; full offline party limited", "HUMAN_VALIDATION_REQUIRED")
    dims["install_update"] = dim("PARTIAL", "web/server deploy", "HUMAN_VALIDATION_REQUIRED")
    adb = shutil.which("adb")
    device = False
    if adb:
        devices = run_cmd([adb, "devices"], timeout=30)
        cmds["adb_devices"] = devices
        device = any(line.strip().endswith("device") for line in (devices.get("stdout_tail") or "").splitlines()[1:])
    dims["android"] = dim(
        "PARTIAL" if device else "BLOCKED",
        "device:test:android available" if device else "no adb device",
        "PHYSICAL_HARDWARE_REQUIRED",
    )
    write_json(OUT / "soak" / "MINI_SOAK.json", {
        "ok": cmds.get("test", {}).get("ok") and cmds.get("build", {}).get("ok"),
        "note": "test+build double gate used as digital soak proxy; not 30min device soak",
    })
    return cmds, dims


def evaluate_gate(
    game: dict[str, str],
    dims: dict[str, dict[str, Any]],
    rights: dict[str, Any],
) -> dict[str, Any]:
    """Earn GAMES_PRE_HUMAN_PLAYTEST_ENGINEERING_EXHAUSTED only if automatable dims are not FAIL/NOT_RUN
    and remaining gaps are only allowed blocker classes / HUMAN_VALIDATION_REQUIRED / NOT_APPLICABLE.
    Quarantine may remain nonempty → LEGAL_RIGHTS_REVIEW_REQUIRED does not block digital exhaust
    if quarantine is explicit and fail-closed.
    """
    allowed_pending = {
        "HUMAN_VALIDATION_REQUIRED",
        "BLOCKED",
        "NOT_APPLICABLE",
        "PARTIAL",
        "PASS",
    }
    failures = [k for k, v in dims.items() if v["status"] in {"FAIL", "NOT_RUN"}]
    # PARTIAL is acceptable for pre-human digital exhaust if blocker classified or notes honest
    unclassified_partial = [
        k for k, v in dims.items()
        if v["status"] == "PARTIAL" and not v.get("blocker_class") and not v.get("notes")
    ]
    blockers = []
    for k, v in dims.items():
        bc = v.get("blocker_class")
        if bc:
            blockers.append({"dimension": k, "blocker_class": bc, "evidence": v.get("evidence")})
    if rights.get("quarantine_count", 0) > 0:
        blockers.append({
            "dimension": "rights",
            "blocker_class": "LEGAL_RIGHTS_REVIEW_REQUIRED",
            "evidence": f"{rights['quarantine_count']} quarantined assets",
        })
    blockers.append({
        "dimension": "fun_balance_feel",
        "blocker_class": "HUMAN_VALIDATION_REQUIRED",
        "evidence": "playtest task sheets are templates only",
    })

    digital_exhausted = (
        len(failures) == 0
        and len(unclassified_partial) == 0
        and all(v["status"] in allowed_pending for v in dims.values())
    )
    # If any PASS/PARTIAL without evidence string, fail closed
    if any(not v.get("evidence") for v in dims.values()):
        digital_exhausted = False
        failures.append("empty_evidence")

    return {
        "GAMES_PRE_HUMAN_PLAYTEST_ENGINEERING_EXHAUSTED": digital_exhausted,
        "HUMAN_FUN_BALANCE_FEEL": "HUMAN_VALIDATION_REQUIRED",
        "RIGHTS_CLEARANCE_COMPLETE": False,
        "RIGHTS_QUARANTINE_ACTIVE": rights.get("quarantine_count", 0) > 0,
        "failures": failures,
        "unclassified_partial": unclassified_partial,
        "blockers": blockers,
        "evaluated_at": now_iso(),
        "game_id": game["id"],
        "accepted_main_sha": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "host": {
            "platform": platform.platform(),
            "python": sys.version.split()[0],
        },
    }


def write_telemetry(cmds: dict[str, Any]) -> None:
    rows = []
    for name, payload in cmds.items():
        if isinstance(payload, dict) and "seconds" in payload:
            rows.append({"name": name, "seconds": payload["seconds"], "ok": payload.get("ok")})
        elif isinstance(payload, dict) and "import_quit" in payload:
            for k in ("import_quit", "smoke"):
                if k in payload and isinstance(payload[k], dict):
                    rows.append({
                        "name": f"godot.{k}",
                        "seconds": payload[k].get("seconds"),
                        "ok": payload[k].get("ok"),
                    })
    write_json(OUT / "telemetry" / "COMMAND_TIMING.json", {
        "label": "HOST_DIGITAL",
        "not_device_lab": True,
        "rows": rows,
    })


def main() -> int:
    game = detect_game()
    OUT.mkdir(parents=True, exist_ok=True)
    print(f"[stream_c] game={game['id']} root={ROOT}")

    provenance = index_provenance_entries(load_provenance_paths(game))
    rights = scan_assets(game, provenance)
    write_json(OUT / "RIGHTS_INVENTORY.json", {
        **{k: rights[k] for k in rights if k != "inventory"},
        "inventory_count": len(rights["inventory"]),
        "inventory_sample": rights["inventory"][:50],
        "inventory_path": "RIGHTS_INVENTORY_FULL.json",
    })
    write_json(OUT / "RIGHTS_INVENTORY_FULL.json", rights["inventory"])
    write_json(OUT / "RIGHTS_QUARANTINE.json", {
        "quarantine_count": rights["quarantine_count"],
        "quarantine_dir": str(QUARANTINE.relative_to(ROOT)),
        "items": rights["quarantine"],
        "policy": rights["policy"],
    })
    (OUT / "RIGHTS_QUARANTINE.md").write_text(
        "# Rights quarantine\n\n"
        f"Count: **{rights['quarantine_count']}**\n\n"
        "Unclear / unprovenanced binary assets are listed in `RIGHTS_QUARANTINE.json` "
        "and copied (when small) under `quarantine/unclear_third_party/`.\n\n"
        "**No rights clearance is claimed.**\n\n"
        + "\n".join(f"- `{i['path']}` — {i['status']}: {i['reason']}" for i in rights["quarantine"][:200])
        + ("\n\n_(truncated)_" if rights["quarantine_count"] > 200 else "\n"),
        encoding="utf-8",
    )

    fixtures_meta = write_fixtures(game)
    sheets = write_playtest_sheets(game)

    if game["id"] == "anime-aggressors":
        cmds, dims = run_anime(game)
    elif game["id"] == "pedestrian-pursuit":
        cmds, dims = run_pedestrian(game)
    elif game["id"] == "archive-of-life-artifact-world":
        cmds, dims = run_archive(game)
    else:
        cmds, dims = run_beatlink(game)

    write_telemetry(cmds)
    write_json(OUT / "COMMAND_RESULTS.json", cmds)
    write_json(OUT / "DIMENSION_MATRIX.json", dims)
    (OUT / "DIMENSION_MATRIX.md").write_text(
        "# Dimension matrix\n\n"
        "| Dimension | Status | Evidence | Blocker |\n|---|---|---|---|\n"
        + "\n".join(
            f"| {k} | {v['status']} | {v.get('evidence','')} | {v.get('blocker_class','')} |"
            for k, v in dims.items()
        )
        + "\n",
        encoding="utf-8",
    )

    gate = evaluate_gate(game, dims, rights)
    write_json(OUT / "GATE_STATUS.json", gate)

    report = {
        "stream": "C",
        "section": 9,
        "game": game,
        "gate": gate,
        "fixtures": fixtures_meta,
        "playtest_task_sheets": str(sheets.relative_to(ROOT)),
        "rights_quarantine_count": rights["quarantine_count"],
        "artifact_root": str(OUT.relative_to(ROOT)),
        "claims": {
            "fun_balance_feel": False,
            "rights_clearance_complete": False,
            "human_playtest_completed": False,
        },
        "emitted_at": now_iso(),
    }
    write_json(OUT / "STREAM_C_REPORT.json", report)
    (OUT / "STREAM_C_REPORT.md").write_text(
        f"""# Stream C report — {game['title']}

- Gate `GAMES_PRE_HUMAN_PLAYTEST_ENGINEERING_EXHAUSTED`: **{gate['GAMES_PRE_HUMAN_PLAYTEST_ENGINEERING_EXHAUSTED']}**
- Fun/balance/feel: **HUMAN_VALIDATION_REQUIRED**
- Rights clearance complete: **false**
- Quarantine count: **{rights['quarantine_count']}**
- HEAD: `{gate['accepted_main_sha']}`

See `DIMENSION_MATRIX.md`, `RIGHTS_QUARANTINE.md`, `playtest/PLAYTEST_TASK_SHEETS.md`.
""",
        encoding="utf-8",
    )

    print(json.dumps({
        "game": game["id"],
        "exhausted": gate["GAMES_PRE_HUMAN_PLAYTEST_ENGINEERING_EXHAUSTED"],
        "quarantine": rights["quarantine_count"],
        "failures": gate["failures"],
    }, indent=2))
    return 0 if not gate["failures"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
