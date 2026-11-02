class_name GarageProgression
extends RefCounted

## Player-facing vehicle unlocks vs race-capable playable registry.
## CI/test harness can unlock all without claiming genuine career unlocks.

const VehicleCatalogScript = preload("res://scripts/data/VehicleCatalog.gd")

static var unlock_all_for_tests: bool = false


static func set_test_unlock_all(enabled: bool) -> void:
	unlock_all_for_tests = enabled


static func unlock_mode(vehicle_id: String) -> String:
	var entry := VehicleCatalogScript.by_id(vehicle_id)
	var unlock: Variant = entry.get("unlock", {})
	if typeof(unlock) == TYPE_DICTIONARY:
		return str(unlock.get("mode", "starter"))
	return "starter"


static func starter_ids() -> Array[String]:
	var out: Array[String] = []
	for vid in VehicleCatalogScript.playable_ids():
		if unlock_mode(vid) == "starter":
			out.append(vid)
	return out


static func is_unlocked_for_player(vehicle_id: String) -> bool:
	if unlock_all_for_tests:
		return VehicleCatalogScript.is_playable(vehicle_id)
	if not VehicleCatalogScript.is_playable(vehicle_id):
		return false
	var mode := unlock_mode(vehicle_id)
	if mode == "starter":
		return true
	var prog: Node = _progression_node()
	if prog == null:
		return mode == "starter"
	if prog.has_method("is_vehicle_unlocked"):
		return bool(prog.call("is_vehicle_unlocked", vehicle_id))
	## Fallback keys.
	if prog.has_method("is_unlocked"):
		if bool(prog.call("is_unlocked", "vehicle:%s" % vehicle_id)):
			return true
		if bool(prog.call("is_unlocked", "unlock_mode:%s" % mode)):
			return true
	return false


static func player_selectable_ids() -> Array[String]:
	var out: Array[String] = []
	for vid in VehicleCatalogScript.playable_ids():
		if is_unlocked_for_player(vid):
			out.append(vid)
	return out


static func grant_mode_unlock(mode: String) -> void:
	var prog: Node = _progression_node()
	if prog != null and prog.has_method("unlock"):
		prog.call("unlock", "unlock_mode:%s" % mode)


static func grant_vehicle(vehicle_id: String) -> void:
	var prog: Node = _progression_node()
	if prog != null and prog.has_method("unlock_vehicle"):
		prog.call("unlock_vehicle", vehicle_id)
	elif prog != null and prog.has_method("unlock"):
		prog.call("unlock", "vehicle:%s" % vehicle_id)


static func _progression_node() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/ProgressionSave")
