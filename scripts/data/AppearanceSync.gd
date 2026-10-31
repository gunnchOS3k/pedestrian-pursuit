class_name AppearanceSync
extends RefCounted

## Pack/unpack cosmetic appearance for multiplayer peers.
## Cosmetics only — never mutates collision or handling stats.

const SCHEMA_VERSION := 1


static func pack_from_created_racer(racer: Dictionary, outfit_slots: Dictionary = {}) -> Dictionary:
	var slots: Dictionary = outfit_slots.duplicate(true) if not outfit_slots.is_empty() else {}
	if slots.is_empty():
		var outfit_id := str(racer.get("outfit_id", ""))
		if not outfit_id.is_empty():
			var CreatedRacerStoreScript = load("res://scripts/data/CreatedRacerStore.gd")
			var outfit: Dictionary = CreatedRacerStoreScript.get_outfit(outfit_id)
			slots = outfit.get("slots", {})
			if slots.is_empty():
				var WardrobeCatalogScript = load("res://scripts/data/WardrobeCatalog.gd")
				var preset: Dictionary = WardrobeCatalogScript.preset(outfit_id)
				slots = preset.get("slots", {})
	return {
		"schema_version": SCHEMA_VERSION,
		"racer_id": str(racer.get("id", "")),
		"display_name": str(racer.get("display_name", "Created Racer")),
		"canonical_base_id": str(racer.get("canonical_base_id", "dash_reed")),
		"appearance": (racer.get("appearance", {}) as Dictionary).duplicate(true),
		"outfit_id": str(racer.get("outfit_id", "")),
		"outfit_slots": slots.duplicate(true),
		"footwear_vehicle_id": str(racer.get("footwear_vehicle_id", "reedline_circlers")),
		"affects_collision": false,
		"affects_stats": false,
	}


static func fingerprint(payload: Dictionary) -> String:
	## Stable visual identity string peers can verify without images.
	var app: Dictionary = payload.get("appearance", {})
	var slots: Dictionary = payload.get("outfit_slots", {})
	var keys: Array = slots.keys()
	keys.sort()
	var slot_bits: PackedStringArray = PackedStringArray()
	for k in keys:
		slot_bits.append("%s=%s" % [str(k), str(slots[k])])
	return "|".join([
		str(payload.get("schema_version", SCHEMA_VERSION)),
		str(payload.get("racer_id", "")),
		str(payload.get("display_name", "")),
		str(app.get("skin_tone", "")),
		str(app.get("hair_style", "")),
		str(app.get("assistive", "")),
		str(payload.get("outfit_id", "")),
		",".join(slot_bits),
		str(payload.get("footwear_vehicle_id", "")),
	])


static func apply_to_visual(visual: Node, payload: Dictionary) -> bool:
	if visual == null or payload.is_empty():
		return false
	var ok := false
	if visual.has_method("apply_avatar_appearance"):
		visual.apply_avatar_appearance(payload.get("appearance", {}), false)
		ok = true
	var slots: Dictionary = payload.get("outfit_slots", {})
	if visual.has_method("apply_wardrobe_outfit") and not slots.is_empty():
		visual.apply_wardrobe_outfit(slots, false)
		ok = true
	var foot := str(payload.get("footwear_vehicle_id", ""))
	if not foot.is_empty() and visual.has_method("set_vehicle_id"):
		visual.set_vehicle_id(foot, false)
		ok = true
	return ok


static func write_payload(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload, "\t"))


static func read_payload(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary
