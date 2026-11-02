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


static func championship_procedural_raceable_honesty() -> Dictionary:
	## S7S art deepen: championship procedural raceable banks ≠ finished art.
	load_registry()
	var championship := 0
	var launch := 0
	var approved := 0
	var total := 0
	for entry in _cache.get("tracks", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		total += 1
		var art := str(entry.get("art_status", ""))
		if art == "CHAMPIONSHIP_PROCEDURAL_RACEABLE":
			championship += 1
		elif art == "LAUNCH_PROCEDURAL_FINAL":
			launch += 1
		var fas := str(entry.get("final_track_art_status", ""))
		if fas in ["final_track_art_approved", "track_art_approved"]:
			approved += 1
		if bool(entry.get("human_track_art_approved", false)):
			approved += 1
	var procedural_neq_finished := (
		approved == 0
		and procedural_never_satisfies_commercial()
		and (championship + launch) == total
		and total == 32
	)
	return {
		"schema": "pp_championship_procedural_raceable_honesty/v1",
		"track_count": total,
		"championship_procedural_raceable": championship,
		"launch_procedural_final": launch,
		"final_track_art_approved": approved,
		"procedural_neq_finished": procedural_neq_finished,
		"COURSE_ACCEPTED": false,
		"HUMAN": false,
		"RC2": false,
		"V1": false,
	}


static func camera_identity_art_cohonesty() -> Dictionary:
	## S7O camera deepen: every raceable track keeps camera_identity (from track JSON)
	## + candidate art without claiming finished/commercial track art.
	## Does not touch CameraRig / RaceScene / wave010.
	load_registry()
	var with_identity := 0
	var candidates := 0
	var approved := 0
	var procedural_launch := 0
	var total := 0
	for entry in _cache.get("tracks", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		total += 1
		var tid := str(entry.get("id", ""))
		var track_path := "res://data/tracks/%s.json" % tid
		if FileAccess.file_exists(track_path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(track_path))
			if typeof(parsed) == TYPE_DICTIONARY:
				if not str((parsed as Dictionary).get("camera_identity", "")).is_empty():
					with_identity += 1
		var fas := str(entry.get("final_track_art_status", ""))
		if fas in ["track_art_candidate", "final_track_art_candidate"]:
			candidates += 1
		if fas in ["final_track_art_approved", "track_art_approved"]:
			approved += 1
		if bool(entry.get("human_track_art_approved", false)):
			approved += 1
		var art := str(entry.get("art_status", ""))
		## Procedural raceable banks (launch or championship) ≠ finished painted art.
		if art in ["LAUNCH_PROCEDURAL_FINAL", "CHAMPIONSHIP_PROCEDURAL_RACEABLE"]:
			procedural_launch += 1
	var procedural_neq_finished := (
		approved == 0
		and procedural_never_satisfies_commercial()
		and procedural_launch == total
		and total == 32
		and candidates == 32
		and with_identity == 32
	)
	return {
		"schema": "pp_camera_identity_art_cohonesty/v1",
		"track_count": total,
		"with_camera_identity": with_identity,
		"track_art_candidate": candidates,
		"procedural_raceable_count": procedural_launch,
		"final_track_art_approved": approved,
		"procedural_neq_finished": procedural_neq_finished,
		"COURSE_ACCEPTED": false,
		"HUMAN": false,
		"RC2": false,
		"V1": false,
	}
