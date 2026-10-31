class_name TrackArtAcceptance
extends RefCounted

## Track final-art acceptance is separate from runtime raceability / LAUNCH_PROCEDURAL_FINAL.

const PATH := "res://data/art/track_art_acceptance.json"

static var _cache: Dictionary = {}


static func load_registry(force: bool = false) -> Dictionary:
	if not force and not _cache.is_empty():
		return _cache
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_cache = parsed
	return _cache


static func counts() -> Dictionary:
	load_registry()
	var out := {
		"raceable": 0,
		"final_track_art_pending": 0,
		"final_track_art_candidate": 0,
		"final_track_art_approved": 0,
		"total": 0,
	}
	for entry in _cache.get("tracks", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		out["total"] = int(out["total"]) + 1
		if str(entry.get("runtime_status", "")) == "raceable":
			out["raceable"] = int(out["raceable"]) + 1
		var fas := str(entry.get("final_track_art_status", ""))
		match fas:
			"track_art_pending", "final_track_art_pending":
				out["final_track_art_pending"] = int(out["final_track_art_pending"]) + 1
			"track_art_candidate", "final_track_art_candidate":
				out["final_track_art_candidate"] = int(out["final_track_art_candidate"]) + 1
			"final_track_art_approved", "track_art_approved":
				out["final_track_art_approved"] = int(out["final_track_art_approved"]) + 1
		if bool(entry.get("human_track_art_approved", false)):
			out["final_track_art_approved"] = int(out["final_track_art_approved"]) + 1
	return out


static func procedural_never_satisfies_commercial() -> bool:
	load_registry()
	if bool(_cache.get("human_track_art_gate", false)):
		return false
	for entry in _cache.get("tracks", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if bool(entry.get("human_track_art_approved", false)):
			return false
		if str(entry.get("final_track_art_status", "")) == "final_track_art_approved":
			return false
	return true
