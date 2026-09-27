class_name RacerData
extends RefCounted

## Loads per-runner gameplay stats (not palette-only profiles).
## CORE / launch roster stays the original eight. Guests are additive selectables.

const RunnerIdsScript = preload("res://scripts/data/RunnerIds.gd")

const LAUNCH_RACER_IDS: Array[String] = [
	"dash_reed",
	"nova_quill",
	"sierra_flux",
	"mira_lane",
	"bolt_harbor",
	"zig_riven",
	"solen_pike",
	"kai_volt",
]
const CORE_RUNNER_IDS: Array[String] = LAUNCH_RACER_IDS
const GUEST_RUNNER_IDS: Array[String] = [
	"ember_vale",
	"rook_ironside",
	"juno_spark",
	"kaia_windrow",
	"nix_calder",
	"orion_vell",
	"vesper_nyx",
]
const ALL_SELECTABLE_RUNNER_IDS: Array[String] = [
	"dash_reed",
	"nova_quill",
	"sierra_flux",
	"mira_lane",
	"bolt_harbor",
	"zig_riven",
	"solen_pike",
	"kai_volt",
	"ember_vale",
	"rook_ironside",
	"juno_spark",
	"kaia_windrow",
	"nix_calder",
	"orion_vell",
	"vesper_nyx",
]


static func load_from_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RacerData: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RacerData: invalid JSON at %s" % path)
		return {}
	return parsed


static func load_by_id(racer_id: String) -> Dictionary:
	var path := "res://data/racers/%s.json" % racer_id
	if FileAccess.file_exists(path):
		return load_from_file(path)
	# Legacy Alpha id → balanced starter.
	if racer_id == "dash":
		return load_from_file("res://data/racers/dash_reed.json")
	return load_from_file("res://data/racers/dash_reed.json")


static func all_launch_ids() -> Array[String]:
	return LAUNCH_RACER_IDS.duplicate()


static func all_core_ids() -> Array[String]:
	return CORE_RUNNER_IDS.duplicate()


static func all_guest_ids() -> Array[String]:
	return GUEST_RUNNER_IDS.duplicate()


static func all_selectable_ids() -> Array[String]:
	return ALL_SELECTABLE_RUNNER_IDS.duplicate()


static func is_guest(racer_id: String) -> bool:
	return RunnerIdsScript.is_guest(racer_id)


static func has_gameplay_stats(racer_id: String) -> bool:
	var data := load_by_id(racer_id)
	return not data.is_empty() and data.has("top_speed") and data.has("acceleration")


static func core_stats_match_twin(guest_id: String) -> bool:
	if not is_guest(guest_id):
		return false
	var guest := load_by_id(guest_id)
	var twin_id := str(guest.get("stat_envelope_twin", ""))
	if twin_id.is_empty():
		return false
	var twin := load_by_id(twin_id)
	if twin.is_empty() or guest.is_empty():
		return false
	for key in ["top_speed", "acceleration", "handling", "drift_control", "trick_skill", "recovery", "strength", "boost_efficiency"]:
		if float(guest.get(key, -1.0)) != float(twin.get(key, -2.0)):
			return false
	return true
