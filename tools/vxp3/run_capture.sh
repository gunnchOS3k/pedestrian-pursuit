#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
echo "[vxp3] structural"
python3 tools/vxp3/run_structural.py
echo "[vxp3] fixture capture"
python3 tools/vxp3/compose_fixture_evidence.py
echo "[vxp3] after snapshots of key scripts"
mkdir -p artifacts/vxp3/after
cp scripts/ui/MainMenu.gd artifacts/vxp3/after/MainMenu.gd.after.txt
cp scripts/ui/RaceHUD.gd artifacts/vxp3/after/RaceHUD.gd.after.txt
cp scripts/ui/PauseMenu.gd artifacts/vxp3/after/PauseMenu.gd.after.txt
cp scripts/ui/ResultsScreen.gd artifacts/vxp3/after/ResultsScreen.gd.after.txt
cp scripts/ui/TutorialDirector.gd artifacts/vxp3/after/TutorialDirector.gd.after.txt
echo "[vxp3] capture complete"
