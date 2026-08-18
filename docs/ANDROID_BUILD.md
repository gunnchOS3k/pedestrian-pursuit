# Android Build and Device QA

The repository includes an `Android Device` export preset for a debug ARM64 APK. The debug preset is runnable, which also enables Godot's one-click deploy when an authorized device is visible.

## Toolchain

For the project's current Godot 4.3 format, install:

- Godot 4.3 editor and matching Android export templates
- OpenJDK 17
- Android SDK Platform-Tools, Build-Tools, and a supported Android platform
- An Android phone with developer mode and USB debugging enabled

In Godot, open **Editor Settings → Export → Android** and configure:

- **Java SDK Path** to the JDK 17 home
- **Android SDK Path** to the SDK directory containing `platform-tools/adb`

Godot's official 4.3 setup reference specifies Android Platform-Tools 34+, Build-Tools 34.0.0, Platform 34, JDK 17, NDK r23c, and CMake 3.10.2 for that engine line: <https://docs.godotengine.org/en/4.3/tutorials/export/exporting_for_android.html>.

## Verify the connection

Unlock the phone, accept the USB debugging authorization dialog, then run:

```bash
adb devices -l
```

The device status must be `device`, not `unauthorized` or `offline`. Godot uses the same ADB visibility for one-click deploy: <https://docs.godotengine.org/en/4.3/tutorials/export/one-click_deploy.html>.

## Build, install, and launch

```bash
GODOT_BIN="/absolute/path/to/Godot" tools/android/build_and_install.sh
```

The script:

1. verifies Godot, ADB, and an authorized device;
2. exports `build/android/pedestrian-pursuit-debug.apk`;
3. installs with `adb install -r`;
4. launches `com.gunnchos.pedestrianpursuit`.

If several devices are connected, set `ANDROID_SERIAL` to the desired serial from `adb devices -l`.

## Device smoke-test checklist

- Main menu stays within the landscape safe area and all controls respond to touch.
- Cup starts at Verdant Cascade Circuit and advances through all four courses in order.
- Left/right plus Run/Drift work simultaneously; Jump, Boost, Item, Brake, and Stomp register independently.
- Player and AI cross ordered checkpoints, laps advance once per circuit, and results appear after lap three.
- Falling from Prism Apex restores the racer at the last accepted checkpoint.
- Pause/resume works and does not leave the scene tree paused after returning to the menu.
- No sustained frame-time spikes, thermal warnings, rendering corruption, or input loss occur during one complete cup.
- App relaunches cleanly after backgrounding, screen lock, and forced stop.

Capture device model, Android version, average/minimum frame rate, peak memory, and any `adb logcat` errors in the release QA record.

## Release builds

Do not commit a keystore or password. Create a private release keystore, back it up securely, and provide credentials through Godot's Android keystore environment variables or local editor settings. Google Play requires an Android App Bundle for new applications; enable a Gradle build and export AAB for the release preset. Never use the checked-in debug APK as a store artifact.

Before release, upgrade to a currently supported Godot stable version and regenerate the export preset with that version. Re-run the complete test matrix after the engine upgrade.

## Common failures

- **No device:** run `adb devices -l`, unlock the phone, and re-authorize USB debugging.
- **Signature mismatch:** uninstall an older build of the same package if it was signed with another key.
- **Missing export template:** install the Android templates matching the exact Godot editor version.
- **SDK/JDK error:** re-check the two Godot editor paths and ensure JDK 17 is selected.
- **Older 32-bit device:** enable the ARMv7 architecture in a separate device preset; the checked-in APK is ARM64-only.
