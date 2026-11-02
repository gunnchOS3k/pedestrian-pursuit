class_name CreatedRacerStore
extends RefCounted

## Versioned created-racer save (identity ≠ avatar ≠ outfit ≠ footwear ≠ sim).

const SAVE_PATH := "user://pp_created_racers.json"
const SCHEMA_VERSION := 1

const AvatarAppearanceScript = preload("res://scripts/data/AvatarAppearance.gd")


static func _blank_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"active_racer_id": "",
		"racers": {},
		"outfits": {},
		"favorites": [],
	}


static func load_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _blank_state()
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return _blank_state()
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _blank_state()
	return migrate(parsed)


static func migrate(data: Dictionary) -> Dictionary:
	var state := _blank_state()
	state["active_racer_id"] = str(data.get("active_racer_id", ""))
	var version := int(data.get("schema_version", 0))
	var racers: Variant = data.get("racers", {})
	if typeof(racers) == TYPE_DICTIONARY:
		for rid in racers.keys():
			var entry: Variant = racers[rid]
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			state["racers"][str(rid)] = _migrate_racer(entry, version)
	var outfits: Variant = data.get("outfits", {})
	if typeof(outfits) == TYPE_DICTIONARY:
		state["outfits"] = outfits.duplicate(true)
	var favs: Variant = data.get("favorites", [])
	if typeof(favs) == TYPE_ARRAY:
		state["favorites"] = favs.duplicate()
	state["schema_version"] = SCHEMA_VERSION
	return state


static func _migrate_racer(entry: Dictionary, _from_version: int) -> Dictionary:
	var appearance_obj = AvatarAppearanceScript.from_dict(entry.get("appearance", {}))
	var appearance: Dictionary = appearance_obj.to_dict()
	return {
		"id": str(entry.get("id", "")),
		"display_name": str(entry.get("display_name", "Created Racer")),
		"pronouns": str(entry.get("pronouns", "they/them")),
		"canonical_base_id": str(entry.get("canonical_base_id", "dash_reed")),
		"appearance": appearance,
		"outfit_id": str(entry.get("outfit_id", "metro_pulse_default")),
		"footwear_vehicle_id": str(entry.get("footwear_vehicle_id", "reedline_circlers")),
		"created_at": str(entry.get("created_at", Time.get_datetime_string_from_system(true))),
		"updated_at": str(entry.get("updated_at", Time.get_datetime_string_from_system(true))),
	}


static func save_state(state: Dictionary) -> void:
	state["schema_version"] = SCHEMA_VERSION
	state["saved_at"] = Time.get_datetime_string_from_system(true)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("CreatedRacerStore: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(state, "\t"))


static func create_racer(display_name: String, base_runner_id: String = "dash_reed") -> Dictionary:
	var state := load_state()
	var rid := "created_%d" % Time.get_unix_time_from_system()
	var racer := {
		"id": rid,
		"display_name": display_name if not display_name.is_empty() else "Created Racer",
		"pronouns": "they/them",
		"canonical_base_id": base_runner_id,
		"appearance": AvatarAppearanceScript.default_appearance().to_dict(),
		"outfit_id": "metro_pulse_default",
		"footwear_vehicle_id": "reedline_circlers",
		"created_at": Time.get_datetime_string_from_system(true),
		"updated_at": Time.get_datetime_string_from_system(true),
	}
	state["racers"][rid] = racer
	state["active_racer_id"] = rid
	save_state(state)
	return racer


static func update_racer(racer: Dictionary) -> void:
	var state := load_state()
	var rid := str(racer.get("id", ""))
	if rid.is_empty():
		return
	racer["updated_at"] = Time.get_datetime_string_from_system(true)
	state["racers"][rid] = racer
	state["active_racer_id"] = rid
	save_state(state)


static func get_active() -> Dictionary:
	var state := load_state()
	var rid := str(state.get("active_racer_id", ""))
	var racers: Dictionary = state.get("racers", {})
	if racers.has(rid):
		return racers[rid]
	return {}


static func set_active(racer_id: String) -> void:
	var state := load_state()
	if state.get("racers", {}).has(racer_id):
		state["active_racer_id"] = racer_id
		save_state(state)


static func save_outfit(outfit_id: String, slots: Dictionary, favorite: bool = false) -> void:
	var state := load_state()
	state["outfits"][outfit_id] = {
		"id": outfit_id,
		"slots": slots.duplicate(true),
		"updated_at": Time.get_datetime_string_from_system(true),
	}
	if favorite:
		var favs: Array = state.get("favorites", [])
		if outfit_id not in favs:
			favs.append(outfit_id)
		state["favorites"] = favs
	save_state(state)


static func get_outfit(outfit_id: String) -> Dictionary:
	var state := load_state()
	var outfits: Dictionary = state.get("outfits", {})
	if outfits.has(outfit_id):
		return outfits[outfit_id]
	return {}
