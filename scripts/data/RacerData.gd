class_name RacerData
extends RefCounted

## Loads racer JSON into a typed dictionary.

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
	return load_from_file("res://data/racers/%s.json" % racer_id)
