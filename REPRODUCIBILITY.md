# Reproducibility — Pedestrian Pursuit

This is a **product/game** repository (arcade foot racer). Not a wireless experiment.

Human playtest remains `HUMAN_QA_PENDING`.

## Canonical commands

```bash
python3 tools/validate_content.py
python3 -m unittest discover -s tests -p 'test_*.py' -v
bash tools/rc_packaging_check.sh
```

Headless Godot 4.5 (when the editor is installed):

```bash
GODOT_BIN="$HOME/Applications/Godot/Godot-4.5.app/Contents/MacOS/Godot" \
  ./tools/run_godot_headless.sh
```

Android (authorized device required by the installer script):

```bash
export ANDROID_SERIAL=27211JEGR06194
tools/android/build_and_install.sh
```

Package id: `com.gunnchos.pedestrianpursuit`. See `docs/PIXEL_6A_ACCEPTANCE.md`.
