# Deployment — current

```mermaid
flowchart LR
  EDITOR[Godot editor F5]
  HEADLESS[tools/run_godot_headless.sh]
  APK[tools/android/build_and_install.sh]
  PKG[com.gunnchos.pedestrianpursuit]
  EDITOR --> HEADLESS
  APK -.-> PKG
```

Pixel 6a blocked: `docs/PIXEL_6A_ACCEPTANCE.md`.
