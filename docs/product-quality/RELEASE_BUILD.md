# Pedestrian Pursuit — Android release build

| Item | Value |
|------|-------|
| Editor | Godot **4.5.stable.official** (`876b29033`) at `~/Applications/Godot/Godot-4.5.app` |
| Export templates | `~/Library/Application Support/Godot/export_templates/4.5.stable/` |
| Android Gradle template | `android/` with `.build_version` = `4.5.stable` |
| JDK | Corretto **17** |
| Package | `com.gunnchos.pedestrianpursuit` |
| Version | **0.3.0** (versionCode **4**) |
| APK | `build/android/pedestrian-pursuit-release.apk` (not committed) |
| Signing | `~/.android/gunnchos-internal-keys/pedestrian-internal-release.jks` — inject password at export time from `passwords.env` (`PEDESTRIAN_*`). Do not commit passwords. |
| 16 KB | Native ELF `PT_LOAD` align **16384**; `.so` STORE uncompressed — see `evidence/android-release/elf-page-alignment.txt` |
| Certificate SHA-256 | `9499a9af54b025f57420a0209039888b269a454e840b8fa46b062b68d9776141` |

## Export

```bash
Godot-4.5 --path . --headless --export-release Android build/android/pedestrian-pursuit-release.apk
```
