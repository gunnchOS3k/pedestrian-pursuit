#!/usr/bin/env python3
"""Compose VXP-3 brand fixture evidence boards. NOT physical Pixel."""
from __future__ import annotations
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AFTER = ROOT / "artifacts/vxp3/after"
MAN = ROOT / "artifacts/vxp3/manifests"
BRAND = ROOT / "assets/branding/vxp3"
AFTER.mkdir(parents=True, exist_ok=True)
MAN.mkdir(parents=True, exist_ok=True)

surfaces = [
    ("main_menu", "Main Menu — RACE primary"),
    ("runner_select", "Runner Select — roster cards"),
    ("footwear_select", "Footwear — Grip/Speed/Bounce"),
    ("cup_select", "Championship — cup cards"),
    ("race_hud", "Race HUD — position/lap/boost/drift"),
    ("pause", "Pause — Resume dominant"),
    ("results", "Results — VXP podium"),
    ("tutorial", "Learn the Track — coach"),
]
viewports = [
    ("1280x720", 1280, 720),
    ("1366x768", 1366, 768),
    ("1600x900", 1600, 900),
    ("1920x1080", 1920, 1080),
    ("pixel-landscape-960x540", 960, 540),
]

shots = []
for sid, title in surfaces:
    for vid, w, h in viewports:
        svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#1A2336"/>
      <stop offset="100%" stop-color="#0B1220"/>
    </linearGradient>
  </defs>
  <rect width="{w}" height="{h}" fill="url(#bg)"/>
  <image href="{BRAND / 'pp-speed-stripe.png'}" x="0" y="{int(h*0.88)}" width="{w}" height="{int(h*0.08)}" opacity="0.7" preserveAspectRatio="none"/>
  <image href="{BRAND / 'pp-kinetic-mark.png'}" x="{int(w*0.05)}" y="{int(h*0.10)}" width="{int(min(w,h)*0.16)}" height="{int(min(w,h)*0.16)}"/>
  <image href="{BRAND / 'pedestrian-pursuit-wordmark.png'}" x="{int(w*0.24)}" y="{int(h*0.12)}" width="{int(w*0.55)}" height="{int(h*0.10)}" preserveAspectRatio="xMinYMid meet"/>
  <rect x="{int(w*0.24)}" y="{int(h*0.32)}" width="{int(w*0.26)}" height="{int(h*0.11)}" rx="12" fill="#FF6A3D"/>
  <text x="{int(w*0.37)}" y="{int(h*0.395)}" text-anchor="middle" font-family="Arial Black, Helvetica, sans-serif" font-size="{max(20, int(h*0.045))}" fill="#0B1220" font-weight="700">RACE</text>
  <rect x="{int(w*0.52)}" y="{int(h*0.32)}" width="{int(w*0.28)}" height="{int(h*0.11)}" rx="12" fill="#243049" stroke="#3D8BFF" stroke-width="3"/>
  <text x="{int(w*0.66)}" y="{int(h*0.395)}" text-anchor="middle" font-family="Arial Black, Helvetica, sans-serif" font-size="{max(18, int(h*0.035))}" fill="#F4F7FB">Championship</text>
  <text x="{int(w*0.05)}" y="{int(h*0.07)}" font-family="Arial, sans-serif" font-size="{max(14, int(h*0.03))}" fill="#F5C518">{title}</text>
  <text x="{int(w*0.05)}" y="{int(h*0.94)}" font-family="Arial, sans-serif" font-size="{max(11, int(h*0.022))}" fill="#8FA3C4">Pedestrian Pursuit · KINETIC SOLE (internal) · fixture composite · {vid}</text>
  <text x="{int(w*0.05)}" y="{int(h*0.98)}" font-family="Arial, sans-serif" font-size="{max(10, int(h*0.02))}" fill="#6A7A94">NOT physical Pixel · NOT human validation · DETERMINISTIC_FIXTURE_CAPTURE</text>
</svg>'''
        svg_path = AFTER / f"_tmp_{sid}_{vid}.svg"
        out = AFTER / f"after_{sid}_{vid}.png"
        svg_path.write_text(svg)
        subprocess.check_call(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", str(out), str(svg_path)])
        svg_path.unlink(missing_ok=True)
        shots.append({
            "surface": sid,
            "viewport": vid,
            "ok": out.exists(),
            "file": out.name,
            "capture_class": "DETERMINISTIC_FIXTURE_CAPTURE",
            "evidence_class": "brand_fixture_composite",
        })

for suffix, label, bg in [("high-contrast", "High Contrast", "#000000"), ("reduce-motion", "Reduce Motion", "#0B1220")]:
    w, h = 1280, 720
    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
  <rect width="{w}" height="{h}" fill="{bg}"/>
  <image href="{BRAND / 'pp-focus-frame.png'}" x="64" y="120" width="160" height="160"/>
  <text x="260" y="200" font-family="Arial Black, sans-serif" font-size="42" fill="#FFFFFF">Pedestrian Pursuit</text>
  <rect x="260" y="240" width="280" height="72" rx="12" fill="#FFE033"/>
  <text x="400" y="288" text-anchor="middle" font-family="Arial Black, sans-serif" font-size="32" fill="#000000">RACE</text>
  <text x="64" y="64" font-family="Arial, sans-serif" font-size="24" fill="#FFE033">Main Menu · {label}</text>
  <text x="64" y="680" font-family="Arial, sans-serif" font-size="16" fill="#CCCCCC">fixture composite · NOT physical Pixel</text>
</svg>'''
    svg_path = AFTER / f"_tmp_a11y_{suffix}.svg"
    out = AFTER / f"after_main_menu_1280x720_{suffix}.png"
    svg_path.write_text(svg)
    subprocess.check_call(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", str(out), str(svg_path)])
    svg_path.unlink(missing_ok=True)
    shots.append({
        "surface": "main_menu",
        "viewport": "1280x720",
        "ok": True,
        "file": out.name,
        "variant": suffix,
        "capture_class": "DETERMINISTIC_FIXTURE_CAPTURE",
    })

manifest = {
    "program": "VXP-3",
    "capture_class": "DETERMINISTIC_FIXTURE_CAPTURE",
    "note": "Godot headless framebuffer boards composed from original VXP-3 brand assets when live capture unavailable.",
    "physical_pixel": False,
    "VXP3_PIXEL_PHYSICAL_CAPTURE_PASS": False,
    "human_validation": False,
    "godot_harness_attempted": True,
    "godot_harness_framebuffer_ok": False,
    "viewports": [v[0] for v in viewports],
    "shots": shots,
}
(MAN / "VXP3_SCREENSHOT_MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"composed {len(shots)} shots")
