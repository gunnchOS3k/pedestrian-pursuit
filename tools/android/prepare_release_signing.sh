#!/usr/bin/env bash
# Ephemerally patch export_presets.cfg for Pedestrian release signing.
# Never commits passwords. Restores empty path/password after restore.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PRESET="$ROOT/export_presets.cfg"
JKS_NAME="pedestrian-internal-release.jks"
DEFAULT_ALIAS="pedestrian_internal"

usage() {
  echo "usage: $0 apply|restore" >&2
  exit 1
}

fail() {
  echo "[prepare_release_signing] $*" >&2
  exit 1
}

set_kv() {
  local key="$1"
  local value="$2"
  if ! grep -q "^${key}=" "$PRESET"; then
    fail "preset missing ${key}"
  fi
  # Escape sed replacement metacharacters in value.
  local escaped
  escaped="$(printf '%s' "$value" | sed -e 's/[&|\\]/\\&/g')"
  sed -i.bak -E "s|^${key}=.*$|${key}=\"${escaped}\"|" "$PRESET"
  rm -f "${PRESET}.bak"
}

apply_signing() {
  local key_dir="${GUNNCHOS_KEYSTORE_DIR:-}"
  if [[ -z "$key_dir" ]]; then
    fail "GUNNCHOS_KEYSTORE_DIR unset"
  fi
  local pass="${PEDESTRIAN_STORE_PASSWORD:-${PEDESTRIAN_KEYSTORE_PASS:-${PEDESTRIAN_KEY_PASSWORD:-}}}"
  if [[ -z "$pass" ]]; then
    fail "PEDESTRIAN_STORE_PASSWORD unset — source passwords.env"
  fi
  # Prefer key password when distinct (Godot uses one field for store in presets).
  local key_pass="${PEDESTRIAN_KEY_PASSWORD:-$pass}"
  local alias="${PEDESTRIAN_KEY_ALIAS:-$DEFAULT_ALIAS}"
  local jks="${key_dir}/${JKS_NAME}"
  if [[ ! -f "$jks" ]]; then
    fail "keystore file missing: ${jks}"
  fi
  if [[ ! -f "$PRESET" ]]; then
    fail "missing preset ${PRESET}"
  fi
  set_kv "keystore/release" "$jks"
  set_kv "keystore/release_user" "$alias"
  set_kv "keystore/release_password" "$key_pass"
  echo "Applied ephemeral signing to ${PRESET}"
  echo "Keystore: ${jks}"
  echo "Alias: ${alias}"
  echo "Remember to restore after export."
}

restore_signing() {
  if [[ ! -f "$PRESET" ]]; then
    fail "missing preset ${PRESET}"
  fi
  local alias="${PEDESTRIAN_KEY_ALIAS:-$DEFAULT_ALIAS}"
  # Keep alias; clear absolute path + password.
  set_kv "keystore/release" ""
  set_kv "keystore/release_user" "$alias"
  set_kv "keystore/release_password" ""
  echo "Restored empty keystore path/password: ${PRESET}"
}

[[ $# -eq 1 ]] || usage
case "$1" in
  apply) apply_signing ;;
  restore) restore_signing ;;
  *) usage ;;
esac
