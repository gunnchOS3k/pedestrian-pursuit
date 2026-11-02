class_name ShoeData
extends RefCounted

## Loads shoe / Kinetic Sole vehicle JSON with material / surface affinities.
## Legacy four IDs remain for challenge + Beta contracts; playable garage IDs are race-native.

const VehicleCatalogScript = preload("res://scripts/data/VehicleCatalog.gd")
const GarageProgressionScript = preload("res://scripts/data/GarageProgression.gd")

const LEGACY_IDS: Array[String] = [
	"starter_soles",
	"speed_sneakers",
	"grip_soles",
	"bounce_boots",
]


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
	var path := "res://data/shoes/%s.json" % shoe_id
	if FileAccess.file_exists(path):
		return load_from_file(path)
	## Fall back to vehicle registry for catalog-only stubs.
	var vehicle: Dictionary = VehicleCatalogScript.by_id(shoe_id)
	if not vehicle.is_empty():
		return vehicle
	return {}


static func legacy_ids() -> Array[String]:
	return LEGACY_IDS.duplicate()


static func street_legend_ids() -> Array[String]:
	## Backward-compatible alias — returns all playable garage vehicles.
	return VehicleCatalogScript.playable_ids()


static func all_ids() -> Array[String]:
	## Race-ready footwear pool: legacy challenge set + playable garage vehicles.
	var out: Array[String] = []
	for id in LEGACY_IDS:
		out.append(id)
	for id in street_legend_ids():
		if id not in out:
			out.append(id)
	return out


static func race_selectable_ids() -> Array[String]:
	## Menu race picker: player-unlocked garage vehicles (CI may unlock all via GarageProgression).
	var playable: Array[String] = GarageProgressionScript.player_selectable_ids()
	if playable.is_empty():
		playable = VehicleCatalogScript.playable_ids()
	if playable.is_empty():
		return legacy_ids()
	return playable


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


static func movement_archetype(shoe_id: String) -> String:
	var shoe := load_by_id(shoe_id)
	var arch := str(shoe.get("movement_archetype", ""))
	if not arch.is_empty():
		return arch
	return VehicleCatalogScript.movement_archetype(shoe_id)


static func is_playable(shoe_id: String) -> bool:
	if shoe_id in LEGACY_IDS:
		return true
	var shoe := load_by_id(shoe_id)
	if shoe.has("playable"):
		return bool(shoe.get("playable"))
	return VehicleCatalogScript.is_playable(shoe_id)
