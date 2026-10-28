class_name VehicleCatalog
extends RefCounted

## Authoritative Kinetic Sole garage — 50 footwear vehicles, reusable archetypes.

const REGISTRY_PATH := "res://data/vehicles/vehicle_registry.json"

static var _cache: Dictionary = {}
static var _by_id: Dictionary = {}


static func load_registry(force: bool = false) -> Dictionary:
	if not force and not _cache.is_empty():
		return _cache
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("VehicleCatalog: cannot open %s" % REGISTRY_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("VehicleCatalog: invalid registry JSON")
		return {}
	_cache = parsed
	_by_id.clear()
	for entry in _cache.get("vehicles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var vid := str(entry.get("id", ""))
		if not vid.is_empty():
			_by_id[vid] = entry
	return _cache


static func all_ids() -> Array[String]:
	load_registry()
	var out: Array[String] = []
	for entry in _cache.get("vehicles", []):
		if typeof(entry) == TYPE_DICTIONARY:
			out.append(str(entry.get("id", "")))
	return out


static func playable_ids() -> Array[String]:
	load_registry()
	var out: Array[String] = []
	for entry in _cache.get("vehicles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if bool(entry.get("playable", false)):
			out.append(str(entry.get("id", "")))
	return out


static func stub_ids() -> Array[String]:
	load_registry()
	var out: Array[String] = []
	for entry in _cache.get("vehicles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not bool(entry.get("playable", false)):
			out.append(str(entry.get("id", "")))
	return out


static func by_id(vehicle_id: String) -> Dictionary:
	load_registry()
	if _by_id.has(vehicle_id):
		return _by_id[vehicle_id]
	return {}


static func family_ids() -> Array[String]:
	load_registry()
	var out: Array[String] = []
	for fam in _cache.get("families", []):
		if typeof(fam) == TYPE_DICTIONARY:
			out.append(str(fam.get("id", "")))
	return out


static func vehicles_in_family(family_id: String) -> Array[Dictionary]:
	load_registry()
	var out: Array[Dictionary] = []
	for entry in _cache.get("vehicles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("family_id", "")) == family_id:
			out.append(entry)
	return out


static func signature_vehicle_for_runner(runner_id: String) -> String:
	load_registry()
	for entry in _cache.get("vehicles", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("signature_runner_id", "")) == runner_id and bool(entry.get("playable", false)):
			return str(entry.get("id", ""))
	return ""


static func is_playable(vehicle_id: String) -> bool:
	var v := by_id(vehicle_id)
	return bool(v.get("playable", false))


static func art_status(vehicle_id: String) -> String:
	var v := by_id(vehicle_id)
	return str(v.get("art_status", "stub_not_final"))


static func movement_archetype(vehicle_id: String) -> String:
	var v := by_id(vehicle_id)
	return str(v.get("movement_archetype", "street_balanced"))


static func counts() -> Dictionary:
	load_registry()
	return {
		"total": int(_cache.get("vehicle_count", all_ids().size())),
		"playable": int(_cache.get("playable_count", playable_ids().size())),
		"stub": int(_cache.get("stub_count", stub_ids().size())),
	}
