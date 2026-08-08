extends RefCounted
class_name InputProfileCatalog

## Named digital input profiles for keyboard / gamepad / touch / local MP.


const PROFILE_DIR := "res://data/input_profiles/"


static func all_ids() -> PackedStringArray:
	return PackedStringArray(["keyboard_default", "gamepad_default", "touch_assist", "local_mp_split"])


static func load_profile(profile_id: String) -> Dictionary:
	var path := PROFILE_DIR + "%s.json" % profile_id
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func apply(profile_id: String) -> Dictionary:
	var profile := load_profile(profile_id)
	if profile.is_empty():
		return {}
	if InputManager != null and InputManager.has_method("apply_device_role"):
		InputManager.apply_device_role(profile)
	return profile


static func describe_all() -> Dictionary:
	var out := {}
	for pid in all_ids():
		out[pid] = load_profile(str(pid))
	return {
		"schema": "pp_input_profiles/v1",
		"profiles": out,
	}
