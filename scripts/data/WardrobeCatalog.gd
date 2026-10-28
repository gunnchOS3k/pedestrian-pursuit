class_name WardrobeCatalog
extends RefCounted

const PATH := "res://data/wardrobe/wardrobe_catalog.json"

static var _cache: Dictionary = {}


static func load_catalog(force: bool = false) -> Dictionary:
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


static func slots() -> Array[String]:
	load_catalog()
	var out: Array[String] = []
	for s in _cache.get("slots", []):
		out.append(str(s))
	return out


static func garments() -> Array[Dictionary]:
	load_catalog()
	var out: Array[Dictionary] = []
	for g in _cache.get("garments", []):
		if typeof(g) == TYPE_DICTIONARY:
			out.append(g)
	return out


static func garment_by_id(garment_id: String) -> Dictionary:
	for g in garments():
		if str(g.get("id", "")) == garment_id:
			return g
	return {}


static func garments_in_slot(slot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in garments():
		if str(g.get("slot", "")) == slot:
			out.append(g)
	return out


static func preset(preset_id: String) -> Dictionary:
	load_catalog()
	for p in _cache.get("presets", []):
		if typeof(p) == TYPE_DICTIONARY and str(p.get("id", "")) == preset_id:
			return p
	return {}


static func integrated_complete_outfit_ids() -> Array[String]:
	## Presets whose key slots all have integrated_mesh_v1 garments.
	var out: Array[String] = []
	load_catalog()
	for p in _cache.get("presets", []):
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var slots: Dictionary = p.get("slots", {})
		var ok := true
		for key in ["base_underlayer", "top", "bottom", "outerwear"]:
			var gid := str(slots.get(key, ""))
			var g := garment_by_id(gid)
			if g.is_empty() or str(g.get("art_status", "")) != "integrated_mesh_v1":
				ok = false
				break
		if ok:
			out.append(str(p.get("id", "")))
	return out


static func family_art_status(family_id: String) -> String:
	load_catalog()
	for fam in _cache.get("families", []):
		if typeof(fam) == TYPE_DICTIONARY and str(fam.get("id", "")) == family_id:
			return str(fam.get("art_status", "catalog_art_pending"))
	return "catalog_art_pending"
