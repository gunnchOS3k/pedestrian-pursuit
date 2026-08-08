#!/usr/bin/env python3
"""Generate ORIGINAL procedural audio banks for Pedestrian Pursuit digital RC.

Music beds, ambience, footsteps, item SFX, UI SFX — pure synthesis, no samples.
"""
from __future__ import annotations

import hashlib
import json
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
MANIFEST = ROOT / "gate1" / "evidence" / "visual_qa" / "audio_bank_manifest.json"

TRACKS = (
    "verdant_cascade_circuit",
    "cloverwind_ranch",
    "prism_apex",
    "emberkeep_gauntlet",
    "tideglass_harbor",
    "neon_switchyard",
    "cloudstep_ridge",
    "mirage_mesa",
)
SURFACES = ("asphalt", "grass", "mud", "ash", "sand", "metal", "wet")
ITEMS = (
    "turbo_toes",
    "lace_trap",
    "sole_shield",
    "pulse_horn",
    "magnet_lace",
    "bounce_bubble",
)
UI = ("confirm", "back", "select", "start", "finish", "countdown")

TRACK_ROOT = {
    "verdant_cascade_circuit": 130.8,
    "cloverwind_ranch": 146.8,
    "prism_apex": 196.0,
    "emberkeep_gauntlet": 110.0,
    "tideglass_harbor": 98.0,
    "neon_switchyard": 164.8,
    "cloudstep_ridge": 123.5,
    "mirage_mesa": 87.3,
}


def clamp(v: float) -> int:
    return max(-32767, min(32767, int(v)))


def write_wav(path: Path, samples: list[float], rate: int = 44100) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        wf.writeframes(b"".join(struct.pack("<h", clamp(s * 32767.0)) for s in samples))


def env(i: int, n: int, attack: float = 0.02, release: float = 0.2) -> float:
    a = max(1, int(n * attack))
    r = max(1, int(n * release))
    if i < a:
        return i / a
    if i > n - r:
        return max(0.0, (n - i) / r)
    return 1.0


def noise(i: int, seed: float = 1.0) -> float:
    x = math.sin(i * 12.9898 + seed * 78.233) * 43758.5453
    return (x - math.floor(x)) * 2.0 - 1.0


def tone(freq: float, seconds: float, amp: float = 0.3, kind: str = "sine", rate: int = 44100) -> list[float]:
    n = int(seconds * rate)
    out = []
    for i in range(n):
        t = i / rate
        phase = 2 * math.pi * freq * t
        if kind == "square":
            v = 1.0 if math.sin(phase) >= 0 else -1.0
        elif kind == "saw":
            v = 2.0 * ((freq * t) % 1.0) - 1.0
        elif kind == "noise":
            v = noise(i, freq)
        else:
            v = math.sin(phase)
        out.append(v * amp * env(i, n))
    return out


def chord(freqs: list[float], seconds: float, amp: float = 0.18) -> list[float]:
    layers = [tone(f, seconds, amp, "sine") for f in freqs]
    n = len(layers[0])
    return [sum(layer[i] for layer in layers) / max(len(layers), 1) for i in range(n)]


def music_bed(root: float, seconds: float = 8.0) -> list[float]:
    # Short looping bed: root + fifth + octave pulse
    a = chord([root, root * 1.5, root * 2.0], seconds, 0.16)
    pulse = tone(root * 0.5, seconds, 0.08, "square")
    hat = []
    rate = 44100
    n = int(seconds * rate)
    for i in range(n):
        beat = (i % int(rate * 0.25)) < int(rate * 0.02)
        hat.append((noise(i, root) * 0.05 if beat else 0.0))
    return [a[i] + pulse[i] * 0.5 + hat[i] for i in range(n)]


def footstep(surface: str) -> list[float]:
    base = {
        "asphalt": 180.0,
        "grass": 140.0,
        "mud": 90.0,
        "ash": 120.0,
        "sand": 100.0,
        "metal": 260.0,
        "wet": 150.0,
    }[surface]
    thump = tone(base, 0.08, 0.35, "sine")
    grit = tone(base * 3.2, 0.05, 0.12 if surface != "mud" else 0.05, "noise")
    return thump + grit


def item_sfx(item_id: str) -> list[float]:
    mapping = {
        "turbo_toes": tone(420, 0.12, 0.3, "saw") + tone(640, 0.15, 0.22, "sine"),
        "lace_trap": tone(70, 0.18, 0.35, "square") + tone(55, 0.1, 0.2, "noise"),
        "sole_shield": chord([220, 330, 440], 0.28, 0.22),
        "pulse_horn": tone(180, 0.2, 0.4, "square") + tone(90, 0.25, 0.25, "saw"),
        "magnet_lace": tone(300, 0.15, 0.25, "sine") + tone(450, 0.18, 0.2, "sine"),
        "bounce_bubble": tone(520, 0.1, 0.2, "sine") + tone(260, 0.15, 0.18, "noise"),
    }
    return mapping[item_id]


def ui_sfx(name: str) -> list[float]:
    mapping = {
        "confirm": tone(520, 0.07, 0.25, "sine") + tone(780, 0.08, 0.2, "sine"),
        "back": tone(320, 0.07, 0.2, "sine"),
        "select": tone(640, 0.05, 0.18, "square"),
        "start": chord([262, 330, 392], 0.35, 0.22),
        "finish": chord([392, 494, 587], 0.55, 0.24),
        "countdown": tone(440, 0.12, 0.28, "sine"),
    }
    return mapping[name]


def ambience(track_id: str) -> list[float]:
    root = TRACK_ROOT[track_id] * 0.5
    bed = tone(root, 4.0, 0.08, "sine")
    air = [noise(i, root) * 0.03 * env(i, len(bed), 0.1, 0.1) for i in range(len(bed))]
    return [bed[i] + air[i] for i in range(len(bed))]


def sha(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()


def main() -> None:
    files: list[dict] = []
    music_dir = OUT / "music"
    amb_dir = OUT / "ambience"
    sfx_dir = OUT / "sfx"
    ui_dir = OUT / "ui"
    for d in (music_dir, amb_dir, sfx_dir, ui_dir):
        d.mkdir(parents=True, exist_ok=True)

    # Menu / results beds
    for name, root in (("menu_theme", 196.0), ("results_fanfare", 262.0), ("cup_theme", 174.6)):
        path = music_dir / f"{name}.wav"
        samples = music_bed(root, 6.0 if name != "results_fanfare" else 3.0)
        if name == "results_fanfare":
            samples = chord([262, 330, 392, 523], 1.2, 0.22) + chord([294, 370, 440], 1.0, 0.2)
        write_wav(path, samples)
        files.append({"id": f"music.{name}", "path": str(path.relative_to(ROOT)), "sha256": sha(path)})

    for tid in TRACKS:
        path = music_dir / f"{tid}_race.wav"
        write_wav(path, music_bed(TRACK_ROOT[tid], 8.0))
        files.append({"id": f"music.race.{tid}", "path": str(path.relative_to(ROOT)), "sha256": sha(path)})
        ap = amb_dir / f"{tid}.wav"
        write_wav(ap, ambience(tid))
        files.append({"id": f"ambience.{tid}", "path": str(ap.relative_to(ROOT)), "sha256": sha(ap)})

    for surface in SURFACES:
        path = sfx_dir / f"footstep_{surface}.wav"
        write_wav(path, footstep(surface))
        files.append({"id": f"sfx.footstep.{surface}", "path": str(path.relative_to(ROOT)), "sha256": sha(path)})

    for item in ITEMS:
        path = sfx_dir / f"item_{item}.wav"
        write_wav(path, item_sfx(item))
        files.append({"id": f"sfx.item.{item}", "path": str(path.relative_to(ROOT)), "sha256": sha(path)})

    for extra, samples in (
        ("boost", tone(200, 0.2, 0.3, "saw") + tone(400, 0.25, 0.22, "sine")),
        ("drift", tone(90, 0.25, 0.2, "noise")),
        ("jump", tone(300, 0.1, 0.22, "sine") + tone(180, 0.08, 0.15, "sine")),
        ("stomp", tone(70, 0.14, 0.4, "square")),
        ("checkpoint", tone(660, 0.08, 0.2, "sine")),
        ("item_box", tone(480, 0.06, 0.18, "square") + tone(720, 0.08, 0.16, "sine")),
    ):
        path = sfx_dir / f"{extra}.wav"
        write_wav(path, samples)
        files.append({"id": f"sfx.{extra}", "path": str(path.relative_to(ROOT)), "sha256": sha(path)})

    for name in UI:
        path = ui_dir / f"{name}.wav"
        write_wav(path, ui_sfx(name))
        files.append({"id": f"ui.{name}", "path": str(path.relative_to(ROOT)), "sha256": sha(path)})

    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(
        json.dumps(
            {
                "schema": "pp_audio_bank_manifest/v1",
                "status": "PROCEDURAL_FINAL",
                "license": "ORIGINAL_INTERNAL",
                "count": len(files),
                "files": files,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(files)} audio files")
    print("LAUNCH_AUDIO_ASSETS_OK")


if __name__ == "__main__":
    main()
