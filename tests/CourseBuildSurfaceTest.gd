extends SceneTree

const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CourseTrack = preload("res://scripts/tracks/CourseTrack.gd")

## Verdant Cascade Circuit must build a drivable shortcut chord.
## The main spawn and checkpoints stay on the built racing line.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	await _exercise_course("verdant_cascade_circuit", failures)
	await _exercise_course("cloverwind_ranch", failures)
	await _exercise_course("prism_apex", failures)
	await _exercise_course("emberkeep_gauntlet", failures)
	await _exercise_course("sneaker_city_sprintway", failures)
	await _exercise_course("metro_pulse_loop", failures)
	if failures.is_empty():
		print(
			"COURSE_BUILD_SURFACE_PASS verdant_cascade_circuit cloverwind_ranch prism_apex emberkeep_gauntlet sneaker_city_sprintway metro_pulse_loop"
		)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _exercise_course(track_id: String, failures: PackedStringArray) -> void:
	var data := _TrackCatalog.load_track(track_id)
	if data.is_empty():
		failures.append("%s course did not load" % track_id)
		return
	var course: Node3D = _CourseTrack.new()
	get_root().add_child(course)
	course.configure(data)
	if not course.build():
		failures.append("CourseTrack.build() rejected %s" % track_id)
		course.queue_free()
		return
	await physics_frame
	await physics_frame
	_assert_on_route(course, data, failures)
	_assert_shortcut_floor(course, data, failures)
	if track_id == "cloverwind_ranch":
		var scenery := course.get_node_or_null("Scenery")
		if scenery == null or scenery.get_node_or_null("RanchBarn") == null:
			failures.append("cloverwind missing RanchBarn scenery landmark")
		if scenery == null or scenery.get_node_or_null("RanchWindmill") == null:
			failures.append("cloverwind missing RanchWindmill landmark")
	elif track_id == "prism_apex":
		var scenery := course.get_node_or_null("Scenery")
		if scenery == null or scenery.get_node_or_null("PrismApexSpire") == null:
			failures.append("prism missing PrismApexSpire landmark")
		if scenery == null or scenery.get_node_or_null("PrismBoostGate2") == null:
			failures.append("prism missing PrismBoostGate2 landmark")
	elif track_id == "emberkeep_gauntlet":
		var scenery := course.get_node_or_null("Scenery")
		if scenery == null or scenery.get_node_or_null("EmberkeepCitadel") == null:
			failures.append("emberkeep missing EmberkeepCitadel landmark")
		if scenery == null or scenery.get_node_or_null("EmberCourtyardGate") == null:
			failures.append("emberkeep missing EmberCourtyardGate landmark")
	elif track_id == "sneaker_city_sprintway":
		var scenery := course.get_node_or_null("Scenery")
		if scenery == null or scenery.get_node_or_null("BillboardArch") == null:
			failures.append("sneaker_city missing BillboardArch landmark")
		if scenery == null or scenery.get_node_or_null("CrosswalkPlanter") == null:
			failures.append("sneaker_city missing CrosswalkPlanter hazard")
	elif track_id == "metro_pulse_loop":
		var scenery := course.get_node_or_null("Scenery")
		if scenery == null or scenery.get_node_or_null("PulseStation") == null:
			failures.append("metro_pulse missing PulseStation landmark")
		if scenery == null or scenery.get_node_or_null("PlatformCrate") == null:
			failures.append("metro_pulse missing PlatformCrate hazard")
	course.queue_free()


func _assert_on_route(course: Node3D, data: Dictionary, failures: PackedStringArray) -> void:
	var path: Path3D = course.get_race_path()
	if path == null or path.curve == null:
		failures.append("built course has no race path")
		return
	var spawn: Vector3 = course.get_start_transform().origin
	if _xz_distance(path, spawn) > 1.5:
		failures.append("spawn is not on the built route")
	var expected: int = data.get("checkpoint_points", []).size()
	if course.get_checkpoints().size() != expected:
		failures.append("checkpoint count differed from course data")
	for checkpoint in course.get_checkpoints():
		if _xz_distance(path, (checkpoint as Node3D).global_position) > 1.5:
			failures.append("checkpoint %s is not on the built path" % checkpoint.name)
	if _floor_gap(course, spawn) < 0.0 or _floor_gap(course, spawn) > 3.0:
		failures.append("spawn has no course floor under it")


func _assert_shortcut_floor(course: Node3D, data: Dictionary, failures: PackedStringArray) -> void:
	var routes: Array = data.get("shortcut_routes", [])
	if routes.is_empty():
		failures.append("shortcut_routes missing")
		return
	var route: Dictionary = routes[0]
	var points: Array = data.get("path_points", [])
	var entry_i := int(route.get("entry_point_index", -1))
	var exit_i := int(route.get("exit_point_index", -1))
	if entry_i < 0 or exit_i < 0 or entry_i >= points.size() or exit_i >= points.size():
		failures.append("shortcut indices are not on the built path")
		return
	var entry := _point(points[entry_i])
	var exitp := _point(points[exit_i])
	var mid := entry.lerp(exitp, 0.5)
	var gap := _floor_gap(course, mid + Vector3(0.0, 2.0, 0.0))
	if gap < 0.0 or gap > 4.0:
		failures.append("shortcut chord has no built floor (gap %.3f)" % gap)
	var dir := exitp - entry
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		failures.append("shortcut chord has no direction")
		return
	var origin := entry + Vector3(0.0, 1.05, 0.0) + dir.normalized() * 2.0
	var dest := origin + dir.normalized() * minf(dir.length() * 0.35, 12.0)
	var world := course.get_world_3d()
	var query := PhysicsRayQueryParameters3D.create(origin, dest)
	query.collision_mask = 1
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Node = hit.get("collider")
		var label := str(collider)
		if collider is Node:
			label = str(collider.get_path())
		failures.append("shortcut entry is blocked by %s at %s" % [label, str(hit.get("position"))])


func _point(raw: Array) -> Vector3:
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))


func _xz_distance(path: Path3D, world_pos: Vector3) -> float:
	var curve := path.curve
	var offset := curve.get_closest_offset(path.to_local(world_pos))
	var nearest := path.to_global(curve.sample_baked(offset))
	return Vector2(world_pos.x, world_pos.z).distance_to(Vector2(nearest.x, nearest.z))


func _floor_gap(course: Node3D, from_pos: Vector3) -> float:
	var world := course.get_world_3d()
	if world == null:
		return -1.0
	var query := PhysicsRayQueryParameters3D.create(from_pos, from_pos + Vector3(0.0, -8.0, 0.0))
	query.collision_mask = 1
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1.0
	return from_pos.y - (hit.position as Vector3).y
