# Pixel 6a acceptance — Pedestrian Pursuit

**Status:** `HUMAN_QA_PENDING` / `PIXEL_6A_READY = BLOCKED`  
**Do not mark PASS.** Cursor cannot install, launch, or capture device evidence while the phone is unauthorized.

## Why blocked (this supervisor-ready pass)

`adb devices` on 2026-08-18 showed:

```text
27211JEGR06194	unauthorized
```

An unauthorized session is not a device. Historical notes under `docs/product-quality/` (if present) are **not** a PASS for this branch.

## Prerequisite (Edmund)

Unlock the Pixel 6a, accept the USB debugging prompt, then confirm:

```bash
adb devices -l
# expected: 27211JEGR06194    device
adb shell getprop ro.product.model
# expected: Pixel 6a
```

If the line still says `unauthorized`, stop. Do not retry install.

## Exact commands (after authorized)

Package: `com.gunnchos.pedestrianpursuit`  
Title: **Pedestrian Pursuit**

```bash
# 1. Confirm device
adb devices -l
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release

# 2. Install (replace APK path after a local debug export)
adb install -r build/android/pedestrian-pursuit-debug.apk

# 3. Launch
adb shell monkey -p com.gunnchos.pedestrianpursuit -c android.intent.category.LAUNCHER 1

# 4. Capture logcat during smoke
adb logcat -c
# play: cold launch → main flow → pause/resume → back/home
adb logcat -d > artifacts/pixel6a/logcat.txt

# 5. Package identity
adb shell dumpsys package com.gunnchos.pedestrianpursuit | head -n 40
adb shell pm path com.gunnchos.pedestrianpursuit
```

```bash
# from repo root after Godot 4.5 + Android SDK + JDK 17
tools/android/build_and_install.sh
# script refuses to run unless adb get-state is `device`
```

Package id in `export_presets.cfg` and `tools/android/build_and_install.sh` is `com.gunnchos.pedestrianpursuit` (not `com.gunnchos3k.pedestrianpursuit`).


## Expected evidence (do not fabricate)

Store under `artifacts/pixel6a/` on a private machine if needed. Public git: no screenshots invented, no PII.

- device model / Android build
- package name matching `com.gunnchos.pedestrianpursuit`
- install success
- smoke notes (launch, one playable loop, pause/resume, back)
- logcat excerpt

## Status transition

Authorized device + passing smoke → Android line may move toward `DEVICE_MEASURED` **for install/launch only**. That is not RF evidence, not a signed playtest, and not a dissertation contribution.
