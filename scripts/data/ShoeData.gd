class_name ShoeData
extends RefCounted

## Loads shoe preset JSON with material / surface affinities AI can reason about.

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


static func material_family(shoe_id: String) -> String:
	var shoe := load_by_id(shoe_id)
	return str(shoe.get("material_family", "balanced_rubber"))


static func surface_affinity(shoe_id: String, surface: String) -> float:
	var shoe := load_by_id(shoe_id)
	var affinities: Dictionary = shoe.get("surface_affinities", {})
	if affinities.is_empty():
		return 1.0
	return float(affinities.get(surface, affinities.get("standard", 1.0)))


static func soft_surface_penalty(shoe_id: String) -> float:
	## Lower = more cautious on mud/wet/ash. Used by AI braking heuristics.
	var mud := surface_affinity(shoe_id, "mud")
	var wet := surface_affinity(shoe_id, "wet")
	var ash := surface_affinity(shoe_id, "ash")
	return (mud + wet + ash) / 3.0


static func prefers_vertical(shoe_id: String) -> bool:
	return surface_affinity(shoe_id, "bounce") >= 1.1 or surface_affinity(shoe_id, "rail") >= 1.1
