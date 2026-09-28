extends RefCounted
class_name ShortcutDecisionDirector

## Decision-quality cues for authored shortcuts. Does not change lap or collision rules.

static func cue_for_player(player: Node3D, course_points: Array, routes: Array, speed: float) -> Dictionary:
	var empty := {"cue": "", "finish_approach": false, "near_entry": false, "shortcut_id": ""}
	if player == null or course_points.is_empty() or routes.is_empty():
		return empty
	var best := empty.duplicate()
	var best_dist := 80.0
	for route in routes:
		if typeof(route) != TYPE_DICTIONARY:
			continue
		var entry_i := int(route.get("entry_point_index", -1))
		if entry_i < 0 or entry_i >= course_points.size():
			continue
		var entry: Vector3 = course_points[entry_i]
		var to_entry: Vector3 = entry - player.global_position
		to_entry.y = 0.0
		var dist := to_entry.length()
		var look := -player.global_transform.basis.z
		look.y = 0.0
		var aligned := look.length_squared() > 0.001 and look.normalized().dot(to_entry.normalized()) > 0.15
		if dist < best_dist and aligned:
			best_dist = dist
			var eta := dist / maxf(speed, 6.0)
			var risk := str(route.get("risk", "")).replace("_", " ")
			if eta <= 3.2:
				best = {
					"cue": "CUT · %s" % (risk if not risk.is_empty() else str(route.get("id", "shortcut"))),
					"finish_approach": false,
					"near_entry": dist < 12.0,
					"shortcut_id": str(route.get("id", "")),
				}
	return best


static func finish_approach(player: Node3D, start_point: Vector3, lap: int, total_laps: int, next_checkpoint: int) -> bool:
	if player == null:
		return false
	if lap + 1 < total_laps:
		return false
	if next_checkpoint != 0:
		return false
	return player.global_position.distance_to(start_point) < 28.0
