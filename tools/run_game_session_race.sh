#!/usr/bin/env bash
# Godot produces the race file. Node only redeems the room and publishes that file.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export GAME_SESSION_DIR="$ROOT/tmp/game-session"
mkdir -p "$GAME_SESSION_DIR"
node "$ROOT/tools/game_session_two_client.mjs" run
