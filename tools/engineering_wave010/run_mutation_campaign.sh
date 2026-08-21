#!/usr/bin/env bash
# Wave010 mutation campaign — disposable clones only. MUTATED_FILES_COMMITTED=false
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
GODOT_BIN="${GODOT_BIN:-}"
resolve_godot() {
  if [[ -n "${GODOT_BIN}" && -x "${GODOT_BIN}" ]]; then echo "${GODOT_BIN}"; return; fi
  for c in /Applications/Godot.app/Contents/MacOS/Godot /opt/homebrew/bin/godot; do
    [[ -x "$c" ]] && { echo "$c"; return; }
  done
  command -v godot
}
GODOT="$(resolve_godot)"
OUT="$ROOT/artifacts/engineering_wave010/MUTATION_RESULT.json"
TMP="$(mktemp -d /tmp/pp-wave010-mut-XXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

attempted=0
killed=0
results=()

run_mut() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  local replacement="$4"
  attempted=$((attempted + 1))
  local work="$TMP/$name"
  mkdir -p "$work"
  # Minimal clone of needed tree
  rsync -a --exclude '.git' --exclude 'artifacts' --exclude '.worktrees' \
    "$ROOT/scripts" "$ROOT/tests" "$ROOT/data" "$ROOT/scenes" "$ROOT/project.godot" \
    "$ROOT/icon.svg" "$work/" 2>/dev/null || {
    cp -R "$ROOT/scripts" "$ROOT/tests" "$ROOT/data" "$ROOT/scenes" "$ROOT/project.godot" "$work/"
    cp "$ROOT/icon.svg" "$work/" 2>/dev/null || true
  }
  local target="$work/$file"
  if [[ ! -f "$target" ]]; then
    results+=("{\"id\":\"$name\",\"killed\":false,\"reason\":\"missing_file\"}")
    return
  fi
  python3 - "$target" "$pattern" "$replacement" <<'PY'
import sys
path, pat, rep = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if pat not in text:
    # soft: try if already mutated pattern absent
    open(path,'w').write(text)
    sys.exit(2)
open(path,'w').write(text.replace(pat, rep, 1))
PY
  local pycode=$?
  if [[ $pycode -eq 2 ]]; then
    results+=("{\"id\":\"$name\",\"killed\":false,\"reason\":\"pattern_not_found\"}")
    return
  fi
  set +e
  (cd "$work" && "$GODOT" --headless --path "$work" --quit-after 1 >/dev/null 2>&1)
  "$GODOT" --headless --path "$work" --script res://tests/engineering_wave010/Wave010RuntimeTest.gd \
    >"$TMP/${name}.log" 2>&1
  local code=$?
  set -e
  if [[ $code -ne 0 ]] || grep -Eiq 'Wave010RuntimeTest FAIL|FAIL:' "$TMP/${name}.log"; then
    killed=$((killed + 1))
    results+=("{\"id\":\"$name\",\"killed\":true,\"exit\":$code}")
  else
    results+=("{\"id\":\"$name\",\"killed\":false,\"exit\":$code}")
  fi
}

# 8 required mutation classes
run_mut accel_invert scripts/player/MovementStats.gd \
  'acceleration = float(racer.get("acceleration", 18.0)) * float(shoe.get("acceleration_modifier", 1.0))' \
  'acceleration = 0.01'

run_mut drift_stationary_farm scripts/player/DriftSystem.gd \
  'min_speed_to_drift: float = 3.5' \
  'min_speed_to_drift: float = 0.0'

run_mut boost_uncap scripts/player/BoostSystem.gd \
  'max_boost: float = 100.0' \
  'max_boost: float = 100000.0'

run_mut item_extreme scripts/race/FairComebackPolicy.gd \
  'COMPETITIVE_MAX_OFFENSE_WEIGHT := 1.15' \
  'COMPETITIVE_MAX_OFFENSE_WEIGHT := 8.0'

run_mut checkpoint_bypass scripts/race/LapManager.gd \
  'if index != state.next_checkpoint:\n\t\treturn' \
  'if false:\n\t\treturn'

run_mut racer_stats_erased scripts/data/RacerData.gd \
  'return load_from_file("res://data/racers/dash_reed.json")' \
  'var d = load_from_file("res://data/racers/dash_reed.json")\n\td["top_speed"]=22.0\n\td["acceleration"]=18.0\n\td["handling"]=12.0\n\td["drift_control"]=10.0\n\treturn d'

run_mut hidden_comeback_speed scripts/race/FairComebackPolicy.gd \
  'return 1.0' \
  'return 1.0 + float(max(0, _place - 1)) * 0.08'

run_mut mastery_flat scripts/player/BoostSystem.gd \
  'max_active_multiplier: float = 1.55' \
  'max_active_multiplier: float = 1.0'

# Fix hidden_comeback mutation - need unique pattern for competitive_speed_assist
# Re-run a clearer 7th if needed — use PlayerController doctrine break
run_mut rubber_band_speed scripts/player/PlayerController.gd \
  'return stats.top_speed * mult' \
  'var place_boost = 1.0\n\tif has_meta(\"race_place_estimate\") and int(get_meta(\"race_place_estimate\")) >= 3:\n\t\tplace_boost = 1.25\n\treturn stats.top_speed * mult * place_boost'

# Ensure at least 8 attempts recorded (attempted may be 9)
python3 - <<PY
import json, os
out = {
  "schema": "gunnchos.engineering_wave010.mutation.v1",
  "WAVE010_MUTATIONS_ATTEMPTED": $attempted,
  "WAVE010_MUTATIONS_KILLED": $killed,
  "MUTATED_FILES_COMMITTED": False,
  "results": [json.loads(x) for x in '''${results[*]}'''.split('} {') if False],
}
# rebuild results properly
raw = '''$(printf '%s\n' "${results[@]}")'''
parsed = []
for line in raw.strip().splitlines():
    line=line.strip()
    if line:
        parsed.append(json.loads(line))
out["results"] = parsed
out["WAVE010_MUTATIONS_ATTEMPTED"] = len(parsed)
out["WAVE010_MUTATIONS_KILLED"] = sum(1 for r in parsed if r.get("killed"))
out["pass"] = out["WAVE010_MUTATIONS_KILLED"] >= 8 and out["WAVE010_MUTATIONS_KILLED"] == out["WAVE010_MUTATIONS_ATTEMPTED"]
os.makedirs(os.path.dirname("$OUT"), exist_ok=True)
open("$OUT","w").write(json.dumps(out, indent=2))
print(json.dumps(out, indent=2))
if not out["pass"]:
    raise SystemExit(1)
PY
