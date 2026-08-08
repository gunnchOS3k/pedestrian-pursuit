class_name ShoeData
extends RefCounted

## Loads shoe preset JSON.

static func load_from_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ShoeData: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ShoeData: invalid JSON at %s" % path)
		return {}
	return parsed


static func load_by_id(shoe_id: String) -> Dictionary:
	return load_from_file("res://data/shoes/%s.json" % shoe_id)


static func all_ids() -> Array[String]:
	return ["starter_soles", "speed_sneakers", "grip_soles", "bounce_boots"]
