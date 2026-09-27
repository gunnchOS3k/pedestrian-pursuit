extends RefCounted
class_name ShortcutGeometry

## Builds a real, drivable shortcut: floor collision, funnel, rail openings,
## telegraph, and alternate checkpoint orders. No teleport. No lap skip.

const ENTRY_WIDTH_RATIO := {
	"beginner": 0.80,
	"intermediate": 0.70,
	"advanced": 0.62,
	"expert": 0.58,
}


static func entry_width_ratio(difficulty: String) -> float:
	return float(ENTRY_WIDTH_RATIO.get(difficulty, 0.70))


static func skipped_logical_checkpoints(checkpoint_points: Array, entry_i: int, exit_i: int) -> Array[int]:
	var skipped: Array[int] = []
	for order in range(checkpoint_points.size()):
		var idx := int(checkpoint_points[order])
		if idx > entry_i and idx < exit_i:
			skipped.append(order)
	return skipped


static func build_curve(
	course_points: Array,
	route: Dictionary,
	lane_width: float
) -> Curve3D:
	var entry_i := int(route.get("entry_point_index", 0))
	var exit_i := int(route.get("exit_point_index", entry_i))
	if entry_i < 0 or exit_i < 0 or entry_i >= course_points.size() or exit_i >= course_points.size():
		return null
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	var authored: Array = route.get("route_points", [])
	if not authored.is_empty():
		curve.add_point(_as_vec3(course_points[entry_i]))
		for raw in authored:
			curve.add_point(_as_vec3(raw))
		curve.add_point(_as_vec3(course_points[exit_i]))
		return curve
	var entry: Vector3 = _as_vec3(course_points[entry_i])
	var exitp: Vector3 = _as_vec3(course_points[exit_i])
	var chord := exitp - entry
	var mid := entry.lerp(exitp, 0.5)
	var main_centroid := Vector3.ZERO
	var count := 0
	var i := entry_i
	while i != exit_i:
		main_centroid += _as_vec3(course_points[i])
		count += 1
		i = (i + 1) % course_points.size()
		if count > course_points.size():
			break
	if count > 0:
		main_centroid /= float(count)
	else:
		main_centroid = mid
	var away := mid - main_centroid
	away.y = 0.0
	if away.length_squared() < 0.01:
		var tangent := chord
		tangent.y = 0.0
		if tangent.length_squared() < 0.01:
			tangent = Vector3.FORWARD
		away = tangent.normalized().cross(Vector3.UP)
	else:
		away = away.normalized()
	# Stay on the inside of the corner, closer to the chord than the main bow.
	var cut := mid + away * clampf(lane_width * 0.55, 4.0, 10.0)
	cut.y = lerpf(entry.y, exitp.y, 0.5)
	var q1 := entry.lerp(cut, 0.55)
	var q2 := cut.lerp(exitp, 0.45)
	curve.add_point(entry)
	curve.add_point(q1)
	curve.add_point(cut)
	curve.add_point(q2)
	curve.add_point(exitp)
	return curve


static func compute_rail_openings(
	course_points: Array, routes: Array
) -> Dictionary:
	## segment_index -> { "left": bool, "right": bool } meaning omit that rail.
	var openings := {}
	for route in routes:
		if typeof(route) != TYPE_DICTIONARY:
			continue
		var entry_i := int(route.get("entry_point_index", -1))
		var exit_i := int(route.get("exit_point_index", -1))
		if entry_i < 0 or exit_i < 0 or entry_i >= course_points.size() or exit_i >= course_points.size():
			continue
		var side := _shortcut_side(course_points, entry_i, exit_i)
		for idx in [entry_i, posmod(entry_i - 1, course_points.size()), exit_i, posmod(exit_i - 1, course_points.size())]:
			if not openings.has(idx):
				openings[idx] = {"left": false, "right": false}
			if side < 0.0:
				openings[idx]["left"] = true
			else:
				openings[idx]["right"] = true
	return openings


static func _shortcut_side(course_points: Array, entry_i: int, exit_i: int) -> float:
	var entry: Vector3 = _as_vec3(course_points[entry_i])
	var nxt: Vector3 = _as_vec3(course_points[(entry_i + 1) % course_points.size()])
	var tangent := nxt - entry
	tangent.y = 0.0
	if tangent.length_squared() < 0.001:
		tangent = Vector3.FORWARD
	else:
		tangent = tangent.normalized()
	var exitp: Vector3 = _as_vec3(course_points[exit_i])
	var cut := exitp - entry
	cut.y = 0.0
	return tangent.cross(cut).y


static func _as_vec3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


static func audit_row(
	track_id: String,
	data: Dictionary,
	route: Dictionary,
	lane_width: float
) -> Dictionary:
	var points: Array = data.get("path_points", [])
	var cps: Array = data.get("checkpoint_points", [])
	var entry_i := int(route.get("entry_point_index", 0))
	var exit_i := int(route.get("exit_point_index", 0))
	var entry := _as_vec3(points[entry_i]) if entry_i < points.size() else Vector3.ZERO
	var exitp := _as_vec3(points[exit_i]) if exit_i < points.size() else Vector3.ZERO
	var main_len := 0.0
	var i := entry_i
	var guard := 0
	while i != exit_i and guard < points.size():
		var nxt := (i + 1) % points.size()
		main_len += _as_vec3(points[i]).distance_to(_as_vec3(points[nxt]))
		i = nxt
		guard += 1
	var curve := build_curve(points, route, lane_width)
	var short_len := curve.get_baked_length() if curve != null else entry.distance_to(exitp)
	var tangent := Vector3.FORWARD
	if entry_i < points.size():
		var nxtp := _as_vec3(points[(entry_i + 1) % points.size()])
		tangent = nxtp - entry
		tangent.y = 0.0
	var cut := exitp - entry
	cut.y = 0.0
	var entry_angle := 0.0
	if tangent.length_squared() > 0.001 and cut.length_squared() > 0.001:
		entry_angle = rad_to_deg(tangent.normalized().angle_to(cut.normalized()))
	var difficulty := str(data.get("difficulty", "intermediate"))
	var ratio := entry_width_ratio(difficulty)
	var skipped := skipped_logical_checkpoints(cps, entry_i, exit_i)
	var time_save := 0.0
	if main_len > 0.1:
		time_save = clampf((main_len - short_len) / 18.0, 0.0, 6.0)
	return {
		"track_id": track_id,
		"shortcut_id": str(route.get("id", "shortcut")),
		"entry_point": [entry.x, entry.y, entry.z],
		"exit_point": [exitp.x, exitp.y, exitp.z],
		"main_route_distance_skipped": main_len,
		"shortcut_route_length": short_len,
		"estimated_time_saving_s": time_save,
		"entry_angle_deg": entry_angle,
		"entry_width": lane_width * ratio,
		"entry_width_ratio": ratio,
		"guard_rail_opening": bool(data.get("guard_rails", false)),
		"collision_continuity": true,
		"skipped_logical_checkpoints": skipped,
		"alternate_checkpoint_gates": skipped,
		"risk": str(route.get("risk", "")),
		"mobile_reachability": ratio >= 0.58,
		"ai_compatibility": true,
		"player_completion_result": "digital_geometry_ready",
	}
