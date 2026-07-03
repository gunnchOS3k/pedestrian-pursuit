class_name ItemData
extends RefCounted

## Loads item definition JSON.

static func load_from_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ItemData: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ItemData: invalid JSON at %s" % path)
		return {}
	return parsed


static func load_by_id(item_id: String) -> Dictionary:
	return load_from_file("res://data/items/%s.json" % item_id)


static func all_mvp_ids() -> Array[String]:
	return ["turbo_toes", "lace_trap", "sole_shield"]
