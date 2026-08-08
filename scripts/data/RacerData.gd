class_name RacerData
extends RefCounted

## Loads per-runner gameplay stats (not palette-only profiles).

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


static func has_gameplay_stats(racer_id: String) -> bool:
	var data := load_by_id(racer_id)
	return not data.is_empty() and data.has("top_speed") and data.has("acceleration")
