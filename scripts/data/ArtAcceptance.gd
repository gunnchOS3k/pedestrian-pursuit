class_name ArtAcceptance
extends RefCounted

## Final-art acceptance is separate from runtime playability.
## Procedural/garage meshes never silently satisfy human-approved commercial art.

const PATH := "res://data/art/vehicle_art_acceptance.json"

static var _cache: Dictionary = {}


static func load_registry(force: bool = false) -> Dictionary:
	if not force and not _cache.is_empty():
		return _cache
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("ArtAcceptance: missing %s" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_cache = parsed
	return _cache


static func by_id(vehicle_id: String) -> Dictionary:
	load_registry()
	for entry in _cache.get("vehicles", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) == vehicle_id:
			return entry
	return {}


static func final_art_status(vehicle_id: String) -> String:
	return str(by_id(vehicle_id).get("final_art_status", "final_art_pending"))


static func runtime_status(vehicle_id: String) -> String:
	return str(by_id(vehicle_id).get("runtime_status", "not_playable"))


static func human_commercial_art_approved(vehicle_id: String) -> bool:
	## Global gate stays false until a human commercial-art approval exists.
	if not bool(load_registry().get("human_commercial_art_gate", false)):
		return false
	return bool(by_id(vehicle_id).get("human_commercial_art_approved", false))


static func counts() -> Dictionary:
	load_registry()
	var out := {
		"playable_runtime": 0,
		"final_art_pending": 0,
		"final_art_candidate": 0,
		"final_art_approved": 0,
		"total": 0,
	}
	for entry in _cache.get("vehicles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		out["total"] = int(out["total"]) + 1
		if str(entry.get("runtime_status", "")) == "playable_runtime":
			out["playable_runtime"] = int(out["playable_runtime"]) + 1
		var fas := str(entry.get("final_art_status", ""))
		if out.has(fas):
			out[fas] = int(out[fas]) + 1
		if human_commercial_art_approved(str(entry.get("id", ""))):
			out["final_art_approved"] = int(out["final_art_approved"]) + 1
	return out


static func procedural_never_satisfies_commercial() -> bool:
	## Hard rule: no procedural/garage art_status entry may claim commercial approval.
	load_registry()
	for entry in _cache.get("vehicles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var art := str(entry.get("art_status", ""))
		if art in ["procedural_final_for_garage", "stub_not_final", "native_v1"]:
			if bool(entry.get("human_commercial_art_approved", false)):
				return false
			if str(entry.get("final_art_status", "")) == "final_art_approved":
				return false
	return not bool(_cache.get("human_commercial_art_gate", false))
