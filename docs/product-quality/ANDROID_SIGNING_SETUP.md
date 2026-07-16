# Android Signing Setup — Pedestrian Pursuit (Internal RC)

Keep secrets and keystores **outside** the repository.

## Canonical internal keystore layout (local machine only)

```text
~/.android/gunnchos-internal-keys/
  pedestrian-internal-release.jks
  passwords.env          # never commit
```

Shared fleet may also contain other app keystores; Pedestrian release signing uses **only** `pedestrian-internal-release.jks`.

`passwords.env` example (do not commit real values):

```bash
export GUNNCHOS_KEYSTORE_DIR="$HOME/.android/gunnchos-internal-keys"
export PEDESTRIAN_STORE_PASSWORD='…'
export PEDESTRIAN_KEY_PASSWORD='…'
export PEDESTRIAN_KEY_ALIAS='pedestrian_internal'
```

## Required environment

| Variable | Purpose |
| --- | --- |
| `GODOT_BIN` | Path to Godot 4.5 CLI |
| `JAVA_HOME` | JDK **17** (Corretto recommended) |
| `ANDROID_SDK_ROOT` / `ANDROID_HOME` | Android SDK |
| `GUNNCHOS_KEYSTORE_DIR` | Directory containing `pedestrian-internal-release.jks` |
| `PEDESTRIAN_STORE_PASSWORD` | Keystore password (legacy `PEDESTRIAN_KEYSTORE_PASS` still accepted) |
| `PEDESTRIAN_KEY_ALIAS` | Alias (default `pedestrian_internal`) |
| `PEDESTRIAN_KEY_PASSWORD` | Key password (falls back to store password) |

## Workflow

1. `source ~/.android/gunnchos-internal-keys/passwords.env`
2. Prefer the wrapper export script (apply signing, clean Godot `.import` sidecars during Gradle merge, restore presets).
3. Or manually: `apply` → export → `restore`.

```bash
# Recommended
bash tools/android/export-release-apk.sh

# Manual
bash tools/android/prepare_release_signing.sh apply
# … export release APK …
bash tools/android/prepare_release_signing.sh restore
```

### Godot `.import` resource merge issue

Godot may write `*.import` sidecars next to launcher PNGs under `android/build/res/mipmap*/`. Android resource merge then fails. `tools/android/export-release-apk.sh` deletes those sidecars during export and can fall back to `./gradlew assembleStandardRelease`.

## Committed presets

`export_presets.cfg` may store:

- `package/unique_name` (`com.gunnchos.pedestrianpursuit`)
- `keystore/release_user` (alias — not a secret)
- empty `keystore/release` and empty `keystore/release_password`

It must **not** store:

- passwords
- absolute machine-specific keystore paths after restore

## Validation errors (expected)

| Error | Fix |
| --- | --- |
| `GUNNCHOS_KEYSTORE_DIR unset` | Export `GUNNCHOS_KEYSTORE_DIR` |
| `keystore file missing` | Place `pedestrian-internal-release.jks` in that directory |
| `PEDESTRIAN_STORE_PASSWORD unset` | Source `passwords.env` |
| `JAVA_HOME is not JDK 17` | Point `JAVA_HOME` at Corretto 17 |
| Godot: “Release Keystore, User AND Password…” | Run `apply` before export; do not leave only one of the three fields filled |
| Gradle `*.png.import` resource merge error | Use `tools/android/export-release-apk.sh` |

## Package

| App | Package ID | Alias (default) | Keystore |
| --- | --- | --- | --- |
| Pedestrian Pursuit | `com.gunnchos.pedestrianpursuit` | `pedestrian_internal` | `pedestrian-internal-release.jks` |

## Verification after APK

- `aapt dump badging` → package + version
- `apksigner verify --print-certs`
- `debuggable=false`
- 16 KB ELF alignment on arm64 shared libraries
