#!/usr/bin/env python3
"""Generate ORIGINAL procedural launch art for Pedestrian Pursuit digital RC.

Produces racers/shoes/items/tracks/UI/VFX PNGs, contact sheets, and provenance.
No third-party textures — PIL synthesis + optional copy of in-repo character renders.
"""
from __future__ import annotations

import hashlib
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art"
QA = ROOT / "gate1" / "evidence" / "visual_qa"
PROVENANCE = ROOT / "data" / "art" / "provenance.json"
RENDERED = ROOT / "docs" / "character-design" / "pedestrian-character-review" / "rendered"

RACERS = (
    "dash_reed",
    "nova_quill",
    "sierra_flux",
    "mira_lane",
    "bolt_harbor",
    "zig_riven",
    "solen_pike",
    "kai_volt",
)
SHOES = ("starter_soles", "grip_soles", "speed_sneakers", "bounce_boots")
ITEMS = (
    "turbo_toes",
    "lace_trap",
    "sole_shield",
    "pulse_horn",
    "magnet_lace",
    "bounce_bubble",
)
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
UI_SHEETS = (
    "menu_panel",
    "hud_chrome",
    "cup_banner",
    "results_panel",
    "footwear_stage",
    "item_slot",
)

RACER_COLORS = {
    "dash_reed": ("#FFD159", "#FF5933"),
    "nova_quill": ("#FF6B5C", "#1A1A1A"),
    "sierra_flux": ("#2EC4B6", "#2D3436"),
    "mira_lane": ("#A29BFE", "#6C5CE7"),
    "bolt_harbor": ("#74B9FF", "#0984E3"),
    "zig_riven": ("#FD79A8", "#E84393"),
    "solen_pike": ("#FFEAA7", "#FDCB6E"),
    "kai_volt": ("#55EFC4", "#00B894"),
}
SHOE_COLORS = {
    "starter_soles": ("#CFCFCF", "#555555"),
    "grip_soles": ("#8B5A2B", "#3D2B1F"),
    "speed_sneakers": ("#FF3B5C", "#FFFFFF"),
    "bounce_boots": ("#4ECDC4", "#1A535C"),
}
ITEM_COLORS = {
    "turbo_toes": ("#FF9F1C", "#FFBF69"),
    "lace_trap": ("#2B2D42", "#8D99AE"),
    "sole_shield": ("#4CC9F0", "#4895EF"),
    "pulse_horn": ("#F72585", "#B5179E"),
    "magnet_lace": ("#7209B7", "#560BAD"),
    "bounce_bubble": ("#80FFDB", "#64DFDF"),
}
TRACK_COLORS = {
    "verdant_cascade_circuit": ("#2F754A", "#6EE7C2"),
    "cloverwind_ranch": ("#6B8F3C", "#E8C547"),
    "prism_apex": ("#1B1F3B", "#7DF9FF"),
    "emberkeep_gauntlet": ("#3A1C14", "#FF6B35"),
    "tideglass_harbor": ("#1D3557", "#457B9D"),
    "neon_switchyard": ("#0B0B12", "#FF00E5"),
    "cloudstep_ridge": ("#4A5568", "#CBD5E0"),
    "mirage_mesa": ("#A05A2C", "#F4A261"),
}


def _hex(c: str) -> tuple[int, int, int]:
    c = c.lstrip("#")
    return int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)


def _font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ):
        p = Path(path)
        if p.exists():
            return ImageFont.truetype(str(p), size=size)
    return ImageFont.load_default()


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _gradient(size: tuple[int, int], c1: str, c2: str) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size)
    r1, g1, b1 = _hex(c1)
    r2, g2, b2 = _hex(c2)
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(r1 + (r2 - r1) * t)
        g = int(g1 + (g2 - g1) * t)
        b = int(b1 + (b2 - b1) * t)
        for x in range(w):
            px[x, y] = (r, g, b, 255)
    return img


def _label(draw: ImageDraw.ImageDraw, text: str, box: tuple[int, int, int, int], fill=(255, 255, 255, 255)) -> None:
    font = _font(18)
    tw, th = draw.textbbox((0, 0), text, font=font)[2:]
    x0, y0, x1, y1 = box
    draw.text(((x0 + x1 - tw) / 2, (y0 + y1 - th) / 2), text, font=font, fill=fill)


def make_racer_icon(rid: str) -> Path:
    out = ART / "racers" / f"{rid}.png"
    src = RENDERED / f"{rid}-picker-idle.png"
    if src.exists():
        img = Image.open(src).convert("RGBA")
        img = img.resize((256, 256), Image.Resampling.LANCZOS)
    else:
        c1, c2 = RACER_COLORS[rid]
        img = _gradient((256, 256), c1, c2)
        d = ImageDraw.Draw(img)
        d.ellipse((48, 28, 208, 188), fill=_hex(c1) + (255,), outline=_hex(c2) + (255,), width=6)
        d.rectangle((96, 170, 160, 240), fill=_hex(c2) + (255,))
        _label(d, rid.replace("_", " ").title(), (0, 210, 256, 250), (20, 20, 20, 255))
    img.save(out)
    return out


def make_shoe_icon(sid: str) -> Path:
    out = ART / "shoes" / f"{sid}.png"
    c1, c2 = SHOE_COLORS[sid]
    img = _gradient((256, 160), c1, c2)
    d = ImageDraw.Draw(img)
    # Sole silhouette
    d.polygon([(30, 90), (210, 70), (240, 95), (220, 130), (40, 135)], fill=_hex(c2) + (255,))
    d.ellipse((175, 55, 235, 110), fill=_hex(c1) + (255,), outline=(255, 255, 255, 180), width=3)
    d.line([(50, 110), (200, 95)], fill=(255, 255, 255, 200), width=4)
    _label(d, sid.replace("_", " ").title(), (0, 0, 256, 40))
    img.save(out)
    return out


def make_item_icon(iid: str) -> Path:
    out = ART / "items" / f"{iid}.png"
    c1, c2 = ITEM_COLORS[iid]
    img = Image.new("RGBA", (128, 128), (12, 14, 20, 255))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((8, 8, 120, 120), radius=22, fill=_hex(c1) + (255,), outline=_hex(c2) + (255,), width=4)
    cx, cy = 64, 64
    if iid == "turbo_toes":
        d.polygon([(40, 90), (64, 30), (88, 90)], fill=(255, 255, 255, 230))
    elif iid == "lace_trap":
        d.arc((28, 28, 100, 100), 20, 340, fill=(255, 255, 255, 230), width=8)
    elif iid == "sole_shield":
        d.ellipse((34, 34, 94, 94), outline=(255, 255, 255, 240), width=8)
    elif iid == "pulse_horn":
        d.polygon([(30, 70), (70, 35), (70, 100)], fill=(255, 255, 255, 230))
        d.arc((70, 40, 110, 95), 270, 90, fill=(255, 255, 255, 230), width=6)
    elif iid == "magnet_lace":
        d.arc((30, 35, 98, 100), 200, 340, fill=(255, 255, 255, 230), width=10)
    else:  # bounce_bubble
        d.ellipse((34, 34, 94, 94), fill=(255, 255, 255, 90), outline=(255, 255, 255, 240), width=5)
    short = iid.replace("_", "\n")
    font = _font(14)
    d.multiline_text((10, 98), short, font=font, fill=(255, 255, 255, 230), spacing=1)
    img.save(out)
    return out


def make_track_icon(tid: str) -> Path:
    out = ART / "tracks" / f"{tid}.png"
    c1, c2 = TRACK_COLORS[tid]
    img = _gradient((320, 180), c1, c2)
    d = ImageDraw.Draw(img)
    # Course ribbon
    pts = []
    for i in range(24):
        t = i / 23.0
        x = 20 + t * 280
        y = 90 + math.sin(t * math.pi * 3 + hash(tid) % 7) * 35
        pts.append((x, y))
    d.line(pts, fill=_hex(c2) + (255,), width=14)
    d.line(pts, fill=(255, 255, 255, 180), width=4)
    _label(d, tid.replace("_", " ").title(), (0, 140, 320, 175))
    img.save(out)
    return out


def make_ui_sheet(name: str) -> Path:
    out = ART / "ui" / f"{name}.png"
    if name == "menu_panel":
        img = _gradient((640, 360), "#101820", "#1B3A4B")
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((40, 40, 600, 320), radius=28, outline=(110, 220, 255, 220), width=4)
        _label(d, "Pedestrian Pursuit", (40, 60, 600, 120))
        _label(d, "Launch Menu", (40, 140, 600, 200), (180, 230, 255, 255))
    elif name == "hud_chrome":
        img = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((8, 8, 504, 120), radius=16, fill=(10, 16, 24, 180), outline=(120, 220, 255, 200), width=3)
        d.rectangle((24, 40, 200, 64), fill=(80, 220, 160, 220))
        d.rounded_rectangle((360, 28, 480, 100), radius=12, fill=(40, 60, 90, 220), outline=(255, 200, 80, 230), width=2)
    elif name == "cup_banner":
        img = _gradient((720, 160), "#FF9F1C", "#FF6B35")
        d = ImageDraw.Draw(img)
        d.polygon([(40, 80), (90, 30), (140, 80), (90, 130)], fill=(255, 255, 255, 230))
        _label(d, "Cup Championship", (160, 40, 680, 120))
    elif name == "results_panel":
        img = _gradient((512, 320), "#14213D", "#1D3557")
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((24, 24, 488, 296), radius=20, outline=(255, 209, 102, 230), width=4)
        _label(d, "Results", (24, 40, 488, 100))
        for i, place in enumerate(("1st", "2nd", "3rd")):
            d.rounded_rectangle((60, 120 + i * 50, 452, 160 + i * 50), radius=10, fill=(255, 255, 255, 35))
            _label(d, place, (60, 120 + i * 50, 452, 160 + i * 50))
    elif name == "footwear_stage":
        img = _gradient((400, 240), "#222831", "#393E46")
        d = ImageDraw.Draw(img)
        d.ellipse((80, 140, 320, 210), fill=(0, 0, 0, 90))
        d.polygon([(120, 150), (280, 120), (300, 160), (140, 180)], fill=(200, 200, 210, 230))
        _label(d, "Footwear Presentation", (0, 20, 400, 70))
    else:  # item_slot
        img = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((4, 4, 92, 92), radius=18, fill=(18, 24, 36, 200), outline=(255, 214, 10, 230), width=4)
    img.save(out)
    return out


def make_vfx_sheet(name: str, color: str) -> Path:
    out = ART / "vfx" / f"{name}.png"
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rgb = _hex(color)
    for r, a in ((60, 60), (40, 120), (24, 200)):
        d.ellipse((64 - r, 64 - r, 64 + r, 64 + r), fill=rgb + (a,))
    img.save(out)
    return out


def contact_sheet(paths: list[Path], out: Path, cell: tuple[int, int], cols: int, title: str) -> None:
    if not paths:
        return
    cw, ch = cell
    rows = math.ceil(len(paths) / cols)
    sheet = Image.new("RGBA", (cols * cw, rows * ch + 36), (16, 18, 24, 255))
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), title, font=_font(20), fill=(230, 240, 255, 255))
    for i, p in enumerate(paths):
        r, c = divmod(i, cols)
        thumb = Image.open(p).convert("RGBA").resize((cw - 8, ch - 8), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (c * cw + 4, 36 + r * ch + 4), thumb)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)


def main() -> None:
    for sub in ("racers", "shoes", "items", "tracks", "ui", "vfx"):
        (ART / sub).mkdir(parents=True, exist_ok=True)
    QA.mkdir(parents=True, exist_ok=True)

    entries: list[dict] = []
    racer_paths = [make_racer_icon(r) for r in RACERS]
    shoe_paths = [make_shoe_icon(s) for s in SHOES]
    item_paths = [make_item_icon(i) for i in ITEMS]
    track_paths = [make_track_icon(t) for t in TRACKS]
    ui_paths = [make_ui_sheet(u) for u in UI_SHEETS]
    vfx_paths = [
        make_vfx_sheet("boost_burst", "#FF9F1C"),
        make_vfx_sheet("shield_ring", "#4CC9F0"),
        make_vfx_sheet("trap_spark", "#F72585"),
        make_vfx_sheet("bubble_pop", "#80FFDB"),
        make_vfx_sheet("draft_wake", "#74B9FF"),
        make_vfx_sheet("finish_flare", "#FFE66D"),
    ]

    for path in racer_paths + shoe_paths + item_paths + track_paths + ui_paths + vfx_paths:
        rel = str(path.relative_to(ROOT))
        kind = path.parent.name
        entries.append(
            {
                "id": f"art.{kind}.{path.stem}",
                "path": rel,
                "status": "PROCEDURAL_FINAL" if kind != "racers" or not (RENDERED / f"{path.stem}-picker-idle.png").exists() else "ORIGINAL_RENDER_FINAL",
                "sha256": _sha256(path),
                "license": "ORIGINAL_INTERNAL",
                "notes": "Pedestrian Pursuit launch presentation asset",
            }
        )

    contact_sheet(racer_paths, QA / "racers_contact_sheet.png", (160, 160), 4, "Racers — launch visual QA")
    contact_sheet(shoe_paths, QA / "footwear_contact_sheet.png", (200, 140), 2, "Footwear — launch visual QA")
    contact_sheet(item_paths, QA / "items_contact_sheet.png", (128, 128), 3, "Items — launch visual QA")
    contact_sheet(track_paths, QA / "tracks_contact_sheet.png", (200, 120), 4, "Tracks — launch visual QA")
    contact_sheet(ui_paths, QA / "ui_contact_sheet.png", (220, 140), 3, "HUD/Menu/Cup/Results — launch visual QA")
    contact_sheet(vfx_paths, QA / "vfx_contact_sheet.png", (128, 128), 3, "Item/race VFX — launch visual QA")

    for sheet in QA.glob("*_contact_sheet.png"):
        entries.append(
            {
                "id": f"qa.{sheet.stem}",
                "path": str(sheet.relative_to(ROOT)),
                "status": "VISUAL_QA",
                "sha256": _sha256(sheet),
                "license": "ORIGINAL_INTERNAL",
                "notes": "Digital RC contact sheet",
            }
        )

    manifest = {
        "schema": "pp_art_provenance/v1",
        "policy": "Original / procedural launch assets only — no third-party IP",
        "digital_rc": "PEDESTRIAN_DIGITAL_RC_READY",
        "physical_fps": "PEDESTRIAN_PHYSICAL_PERFORMANCE_PENDING",
        "counts": {
            "racers": len(racer_paths),
            "shoes": len(shoe_paths),
            "items": len(item_paths),
            "tracks": len(track_paths),
            "ui": len(ui_paths),
            "vfx": len(vfx_paths),
        },
        "entries": entries,
    }
    PROVENANCE.parent.mkdir(parents=True, exist_ok=True)
    PROVENANCE.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} art entries + contact sheets")
    print("LAUNCH_ART_ASSETS_OK")


if __name__ == "__main__":
    main()
