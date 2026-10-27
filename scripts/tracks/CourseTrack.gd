class_name CourseTrack
extends Node3D
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")

## Builds an original, data-defined course with collision, race path, checkpoints,
## gameplay zones, and lightweight mobile-friendly scenery.

const CHECKPOINT_SCRIPT := preload("res://scripts/race/Checkpoint.gd")
const SPEED_LANE_SCRIPT := preload("res://scripts/tracks/SpeedLane.gd")
const TERRAIN_ZONE_SCRIPT := preload("res://scripts/tracks/TerrainZone.gd")
const BOUNCE_PAD_SCRIPT := preload("res://scripts/tracks/BouncePad.gd")
const BOOST_PICKUP_SCRIPT := preload("res://scripts/tracks/BoostPickup.gd")
const SHORTCUT_SCRIPT := preload("res://scripts/tracks/ShortcutCorridor.gd")
const ITEM_BOX_SCENE := preload("res://scenes/items/ItemBox.tscn")

var _data: Dictionary = {}
var _course_points: Array[Vector3] = []
var _checkpoint_point_indices: Array[int] = []
var _checkpoints: Array[Node3D] = []
var _race_path: Path3D
var _start_transform := Transform3D.IDENTITY
var _lane_width: float = 14.0
var _built: bool = false
var _material_cache: Dictionary = {}


func configure(course_data: Dictionary) -> void:
	if _built:
		push_warning("CourseTrack cannot be reconfigured after build")
		return
	_data = course_data.duplicate(true)


func build() -> bool:
	if _built:
		return true
	var errors := _TrackCatalog.validate_track(_data)
	if not errors.is_empty():
		push_error("Course build rejected: %s" % "; ".join(errors))
		return false
	_lane_width = float(_data.get("lane_width", 14.0))
	for raw_point in _data.get("path_points", []):
		_course_points.append(
			Vector3(float(raw_point[0]), float(raw_point[1]), float(raw_point[2]))
		)
	for raw_index in _data.get("checkpoint_points", []):
		_checkpoint_point_indices.append(int(raw_index))
	_build_environment()
	_build_race_path()
	_build_surface()
	_build_checkpoints()
	_build_features()
	_build_scenery()
	_build_start_marker()
	_start_transform = _transform_at_point(0, 1.05)
	_built = true
	return true


func get_checkpoints() -> Array:
	return _checkpoints.duplicate()


func get_start_transform() -> Transform3D:
	return _start_transform


func get_race_path() -> Path3D:
	return _race_path


func snap_body_to_nearest_path(body: Node3D, lane_offset: float = 0.0) -> bool:
	## Production void/off-track recovery onto the authored racing line.
	## Used by RaceScene / PlayerController — not an E2E gate teleporter.
	if body == null or _race_path == null or _race_path.curve == null:
		return false
	var curve: Curve3D = _race_path.curve
	var path_len: float = maxf(curve.get_baked_length(), 1.0)
	var offset: float = curve.get_closest_offset(_race_path.to_local(body.global_position))
	var pos: Vector3 = _race_path.to_global(curve.sample_baked(offset))
	var next: Vector3 = _race_path.to_global(curve.sample_baked(fposmod(offset + 2.0, path_len)))
	var direction: Vector3 = next - pos
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	var right: Vector3 = direction.normalized().cross(Vector3.UP)
	body.global_position = pos + Vector3(0, 1.05, 0) + right * lane_offset
	var look_target: Vector3 = body.global_position + direction.normalized() * 4.0
	look_target.y = body.global_position.y
	body.look_at(look_target, Vector3.UP)
	if "velocity" in body:
		body.velocity = Vector3.ZERO
	if "horizontal_speed" in body:
		body.horizontal_speed = minf(float(body.horizontal_speed), 10.0)
	return true


func get_display_name() -> String:
	return str(_data.get("display_name", "Unknown Course"))


func get_rail_world_points() -> Array:
	## World-space points for grindable rail segments (launch procedural).
	var points: Array = []
	for raw_index in _data.get("rail_segments", []):
		var idx := int(raw_index)
		if idx < 0 or idx >= _course_points.size():
			continue
		points.append(_course_points[idx] + Vector3(0.0, 1.15, 0.0))
	return points


func get_shortcut_routes() -> Array:
	return _data.get("shortcut_routes", [])


func get_checkpoint_recovery_transform(checkpoint_index: int) -> Transform3D:
	if checkpoint_index < 0 or checkpoint_index >= _checkpoint_point_indices.size():
		return _start_transform
	return _transform_at_point(_checkpoint_point_indices[checkpoint_index], 1.05)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = _color("sky_color", Color(0.2, 0.4, 0.7))
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.88, 0.9, 1.0)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var theme := str(_data.get("theme", ""))
	if theme == "cascade_garden":
		## Misty riverside read — fog softens the horizon without hiding gates.
		environment.ambient_light_color = Color(0.78, 0.9, 0.95)
		environment.ambient_light_energy = 0.92
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.72, 0.86, 0.9)
		environment.fog_density = 0.0045
		environment.fog_aerial_perspective = 0.35
		environment.glow_enabled = true
		environment.glow_intensity = 0.35
		environment.glow_bloom = 0.12
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	if theme == "cascade_garden":
		sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
		sun.light_energy = 1.35
		sun.light_color = Color(1.0, 0.97, 0.9)
		var fill := OmniLight3D.new()
		fill.name = "CascadeFill"
		fill.position = Vector3(0.0, 14.0, 0.0)
		fill.light_energy = 2.4
		fill.light_color = Color(0.55, 0.85, 0.95)
		fill.omni_range = 90.0
		add_child(fill)
	add_child(sun)


func _build_race_path() -> void:
	_race_path = Path3D.new()
	_race_path.name = "RacePath"
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for point in _course_points:
		curve.add_point(point + Vector3(0.0, 0.8, 0.0))
	curve.add_point(_course_points[0] + Vector3(0.0, 0.8, 0.0))
	_race_path.curve = curve
	add_child(_race_path)


func _build_surface() -> void:
	var surfaces := Node3D.new()
	surfaces.name = "CourseSurface"
	add_child(surfaces)
	for index in range(_course_points.size()):
		var next_index := (index + 1) % _course_points.size()
		_add_track_segment(surfaces, _course_points[index], _course_points[next_index], index)
		_add_track_junction(surfaces, _course_points[index], index)


func _add_track_segment(
	parent: Node3D, start_point: Vector3, end_point: Vector3, index: int
) -> void:
	var length := start_point.distance_to(end_point)
	var body := StaticBody3D.new()
	body.name = "Segment%02d" % index
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.global_position = (start_point + end_point) * 0.5 + Vector3(0.0, -0.3, 0.0)
	body.look_at(end_point + Vector3(0.0, -0.3, 0.0), Vector3.UP)

	var surface_size := Vector3(_lane_width, 0.6, length + _lane_width * 0.4)
	var shape := BoxShape3D.new()
	shape.size = surface_size
	var collider := CollisionShape3D.new()
	collider.name = "TrackCollision"
	collider.shape = shape
	body.add_child(collider)

	var mesh := BoxMesh.new()
	mesh.size = surface_size
	var visual := MeshInstance3D.new()
	visual.name = "TrackVisual"
	visual.mesh = mesh
	var theme := str(_data.get("theme", ""))
	var track_mat := _make_material(_segment_color(index), theme == "prism_void")
	if theme == "cascade_garden":
		## Wet riverside asphalt: moss tint + soft specular read.
		track_mat = track_mat.duplicate()
		track_mat.roughness = 0.42
		track_mat.metallic = 0.08
		track_mat.albedo_color = track_mat.albedo_color.lerp(Color(0.28, 0.42, 0.36), 0.22)
	visual.material_override = track_mat
	body.add_child(visual)

	if bool(_data.get("guard_rails", false)):
		for side in [-1.0, 1.0]:
			if _rail_side_open_for_shortcut(index, side):
				continue
			var rail_size := Vector3(0.45, 1.4, maxf(1.0, length - _lane_width * 0.25))
			var rail_shape := BoxShape3D.new()
			rail_shape.size = rail_size
			var rail_collider := CollisionShape3D.new()
			rail_collider.name = "RailCollision"
			rail_collider.position = Vector3(side * (_lane_width * 0.5 - 0.25), 0.85, 0.0)
			rail_collider.shape = rail_shape
			body.add_child(rail_collider)
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = rail_size
			var rail_visual := MeshInstance3D.new()
			rail_visual.name = "RailVisual"
			rail_visual.position = rail_collider.position
			rail_visual.mesh = rail_mesh
			rail_visual.material_override = _make_material(
				_color("accent_color", Color.WHITE), true
			)
			body.add_child(rail_visual)


func _add_track_junction(parent: Node3D, point: Vector3, index: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Junction%02d" % index
	body.position = point + Vector3(0.0, -0.32, 0.0)
	body.collision_layer = 1
	body.collision_mask = 0
	var radius := _lane_width * 0.62
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.6
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _make_material(
		_segment_color(index), _data.get("theme", "") == "prism_void"
	)
	body.add_child(visual)
	parent.add_child(body)


func _build_checkpoints() -> void:
	var checkpoint_root := Node3D.new()
	checkpoint_root.name = "Checkpoints"
	add_child(checkpoint_root)
	for order in range(_checkpoint_point_indices.size()):
		var point_index := _checkpoint_point_indices[order]
		var checkpoint := Area3D.new()
		checkpoint.name = "Checkpoint%d" % order
		checkpoint.set_script(CHECKPOINT_SCRIPT)
		checkpoint.set("checkpoint_index", order)
		checkpoint.transform = _transform_at_point(point_index, 1.8)
		var shape := BoxShape3D.new()
		# Slightly deeper gates so mobile lines still register ordered checkpoints.
		shape.size = Vector3(_lane_width * 0.95, 5.0, 3.6)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		checkpoint.add_child(collider)
		checkpoint_root.add_child(checkpoint)
		_checkpoints.append(checkpoint)


func _build_features() -> void:
	var feature_root := Node3D.new()
	feature_root.name = "CourseFeatures"
	add_child(feature_root)
	for definition in _data.get("speed_lanes", []):
		_add_speed_lane(feature_root, definition)
	for definition in _data.get("terrain_zones", []):
		_add_terrain_zone(feature_root, definition)
	for definition in _data.get("bounce_pads", []):
		_add_bounce_pad(feature_root, definition)
	for point_index in _data.get("item_boxes", []):
		var item_box := ITEM_BOX_SCENE.instantiate() as Node3D
		if item_box:
			item_box.name = "ItemBox%d" % int(point_index)
			item_box.transform = _transform_at_point(int(point_index), 1.3)
			feature_root.add_child(item_box)
	for point_index in _data.get("boost_pickups", []):
		_add_boost_pickup(feature_root, int(point_index))
	for route in _data.get("shortcut_routes", []):
		if typeof(route) == TYPE_DICTIONARY:
			_add_shortcut_corridor(feature_root, route)


func _add_speed_lane(parent: Node3D, definition: Dictionary) -> void:
	var lane := Area3D.new()
	lane.name = "SpeedLane%d" % int(definition.get("point_index", 0))
	lane.set_script(SPEED_LANE_SCRIPT)
	lane.set("speed_bonus", float(definition.get("speed_bonus", 1.2)))
	lane.transform = _transform_at_point(int(definition.get("point_index", 0)), 0.16)
	_add_box_trigger_visual(
		lane,
		_feature_size(definition, Vector2(6.0, 12.0)),
		_color("accent_color", Color.CYAN),
		true
	)
	parent.add_child(lane)


func _add_terrain_zone(parent: Node3D, definition: Dictionary) -> void:
	var zone := Area3D.new()
	zone.name = "TerrainZone%d" % int(definition.get("point_index", 0))
	zone.set_script(TERRAIN_ZONE_SCRIPT)
	zone.set("terrain_name", str(definition.get("terrain_name", "slow_terrain")))
	zone.set("speed_multiplier", float(definition.get("speed_multiplier", 0.8)))
	zone.set("handling_multiplier", float(definition.get("handling_multiplier", 0.9)))
	zone.transform = _transform_at_point(int(definition.get("point_index", 0)), 0.13)
	var zone_color := Color.from_string(
		str(definition.get("color", "#557755")), Color(0.3, 0.4, 0.3)
	)
	_add_box_trigger_visual(zone, _feature_size(definition, Vector2(10.0, 12.0)), zone_color, false)
	parent.add_child(zone)


func _add_bounce_pad(parent: Node3D, definition: Dictionary) -> void:
	var point_index := int(definition.get("point_index", 0))
	var pad := Area3D.new()
	pad.name = "BouncePad%d" % point_index
	pad.set_script(BOUNCE_PAD_SCRIPT)
	pad.set("bounce_force", float(definition.get("bounce_force", 12.0)))
	pad.set("forward_boost", float(definition.get("forward_boost", 4.0)))
	var next_index := (point_index + 1) % _course_points.size()
	var line := _course_points[next_index] - _course_points[point_index]
	line.y = 0.0
	if line.length_squared() > 0.001:
		pad.set("launch_forward", line.normalized())
	pad.transform = _transform_at_point(point_index, 0.2)
	_add_box_trigger_visual(
		pad, _feature_size(definition, Vector2(5.0, 5.0)), Color(0.96, 0.45, 0.25), true
	)
	parent.add_child(pad)


func _add_boost_pickup(parent: Node3D, point_index: int) -> void:
	var pickup := Area3D.new()
	pickup.name = "BoostPickup%d" % point_index
	pickup.set_script(BOOST_PICKUP_SCRIPT)
	pickup.transform = _transform_at_point(point_index, 1.45)
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	var collider := CollisionShape3D.new()
	collider.shape = shape
	pickup.add_child(collider)
	var mesh := SphereMesh.new()
	mesh.radius = 0.65
	mesh.height = 1.3
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _make_material(_color("accent_color", Color.YELLOW), true)
	pickup.add_child(visual)
	parent.add_child(pickup)


func _rail_side_open_for_shortcut(segment_index: int, side: float) -> bool:
	## Drop the rail on the side an authored shortcut leaves or rejoins.
	## The racing line itself stays walled on the outside.
	var count := _course_points.size()
	if count < 2 or segment_index < 0 or segment_index >= count:
		return false
	var start := _course_points[segment_index]
	var end := _course_points[(segment_index + 1) % count]
	var forward := end - start
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return false
	# look_at points local -Z along travel, so local +X is forward × up.
	var local_x := forward.normalized().cross(Vector3.UP)
	var start_index := segment_index
	var end_index := (segment_index + 1) % count
	for route in _data.get("shortcut_routes", []):
		if typeof(route) != TYPE_DICTIONARY:
			continue
		var entry_i := int(route.get("entry_point_index", -1))
		var exit_i := int(route.get("exit_point_index", -1))
		if entry_i < 0 or exit_i < 0 or entry_i >= count or exit_i >= count or entry_i == exit_i:
			continue
		var anchor := -1
		var other := -1
		if start_index == entry_i or end_index == entry_i:
			anchor = entry_i
			other = exit_i
		elif start_index == exit_i or end_index == exit_i:
			anchor = exit_i
			other = entry_i
		if anchor < 0:
			continue
		var to_target := _course_points[other] - _course_points[anchor]
		to_target.y = 0.0
		var side_dot := to_target.dot(local_x)
		if side > 0.0 and side_dot > 0.5:
			return true
		if side < 0.0 and side_dot < -0.5:
			return true
	return false


func _add_shortcut_floor(parent: Node3D, start_point: Vector3, end_point: Vector3, shortcut_id: String) -> void:
	## Collision under the authored chord. The trigger alone is not a drivable route.
	var surface_y := (start_point.y + end_point.y) * 0.5
	var flat_start := Vector3(start_point.x, surface_y, start_point.z)
	var flat_end := Vector3(end_point.x, surface_y, end_point.z)
	var length := flat_start.distance_to(flat_end)
	if length < 1.0:
		return
	var body := StaticBody3D.new()
	body.name = "ShortcutFloor_%s" % shortcut_id
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.global_position = (flat_start + flat_end) * 0.5 + Vector3(0.0, -0.3, 0.0)
	var look_target := flat_end + Vector3(0.0, -0.3, 0.0)
	if body.global_position.distance_squared_to(look_target) > 0.04:
		body.look_at(look_target, Vector3.UP)
	var width := _lane_width * 0.55
	var surface_size := Vector3(width, 0.6, length)
	var shape := BoxShape3D.new()
	shape.size = surface_size
	var collider := CollisionShape3D.new()
	collider.name = "ShortcutFloorCollision"
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = surface_size
	var visual := MeshInstance3D.new()
	visual.name = "ShortcutFloorVisual"
	visual.mesh = mesh
	visual.material_override = _make_material(Color(0.95, 0.75, 0.2), true)
	body.add_child(visual)


func _add_shortcut_corridor(parent: Node3D, route: Dictionary) -> void:
	## Physical corridor between entry/exit path points. Does not alter checkpoint sequence.
	var entry_i := int(route.get("entry_point_index", 0))
	var exit_i := int(route.get("exit_point_index", entry_i))
	if entry_i < 0 or exit_i < 0 or entry_i >= _course_points.size() or exit_i >= _course_points.size():
		return
	var entry := _course_points[entry_i]
	var exitp := _course_points[exit_i]
	_add_shortcut_floor(parent, entry, exitp, str(route.get("id", "cut")))
	var mid := entry.lerp(exitp, 0.5)
	var corridor := Area3D.new()
	corridor.name = "Shortcut_%s" % str(route.get("id", "cut"))
	corridor.set_script(SHORTCUT_SCRIPT)
	corridor.set("shortcut_id", str(route.get("id", "shortcut")))
	var risk := str(route.get("risk", ""))
	if not risk.is_empty():
		corridor.set("risk_terrain", risk)
		corridor.set("risk_speed_mult", 0.86)
		corridor.set("risk_handling_mult", 0.9)
	var xf := Transform3D()
	xf.origin = mid + Vector3(0, 0.2, 0)
	var dir := exitp - entry
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		xf = xf.looking_at(mid + dir.normalized(), Vector3.UP)
	corridor.transform = xf
	var length := maxf(entry.distance_to(exitp) * 0.55, 6.0)
	_add_box_trigger_visual(corridor, Vector2(_lane_width * 0.55, length), Color(0.95, 0.75, 0.2), true)
	parent.add_child(corridor)
	# AI preference metadata for path follower (no teleport).
	corridor.set_meta("ai_preference", float(route.get("ai_preference", 0.3)))
	corridor.set_meta("entry_point_index", entry_i)
	corridor.set_meta("exit_point_index", exit_i)


func _add_box_trigger_visual(area: Area3D, size_2d: Vector2, color: Color, emissive: bool) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(size_2d.x, 1.3, size_2d.y)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	area.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_2d.x, 0.08, size_2d.y)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _make_material(color, emissive)
	area.add_child(visual)


func _build_scenery() -> void:
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	match str(_data.get("theme", "")):
		"cascade_garden":
			_build_cascade_scenery(scenery)
		"windy_ranch":
			_build_ranch_scenery(scenery)
		"prism_void":
			_build_prism_scenery(scenery)
		"ember_fortress":
			_build_ember_scenery(scenery)
		"harbor_glass":
			_build_harbor_scenery(scenery)
		"neon_yard":
			_build_neon_scenery(scenery)
		"ridge_cloud":
			_build_ridge_scenery(scenery)
		"mesa_mirage":
			_build_mesa_scenery(scenery)
		_:
			_add_visual_box(
				scenery,
				Vector3(0.0, -0.75, 0.0),
				Vector3(140.0, 0.2, 140.0),
				_color("backdrop_color", Color.DARK_GREEN)
			)


func _build_cascade_scenery(parent: Node3D) -> void:
	## Kinetic Sole riverside: garden banks, mist columns, vertical cliff route,
	## and a readable start arch. Collision path stays on the authored race line.
	_add_visual_box(
		parent,
		Vector3(0.0, -0.78, 0.0),
		Vector3(150.0, 0.22, 150.0),
		_color("backdrop_color", Color(0.2, 0.5, 0.3))
	)
	## Shallow runoff basin (emissive water read).
	_add_visual_cylinder(parent, Vector3(0.0, -0.52, 0.0), 28.0, 0.22, Color(0.18, 0.62, 0.82), true)
	_add_visual_cylinder(parent, Vector3(4.0, -0.42, -6.0), 12.0, 0.16, Color(0.32, 0.78, 0.9), true)
	## Cascade columns — misty vertical landmarks.
	for position in [
		Vector3(-13, 7, -2), Vector3(0, 9, -10), Vector3(14, 6, 2),
		Vector3(-22, 5, 10), Vector3(18, 8, -14), Vector3(-6, 6.5, 16)
	]:
		_add_visual_cylinder(parent, position, 2.6, position.y * 2.0, Color(0.4, 0.86, 0.95), true)
		_add_visual_cylinder(
			parent, position + Vector3(0.0, -position.y * 0.15, 0.0), 3.4, 0.35, Color(0.55, 0.9, 1.0), true
		)
	## Garden canopy trees with layered crowns.
	for position in [
		Vector3(-10, 1.1, 14), Vector3(12, 1.1, -18), Vector3(-24, 1.1, -4),
		Vector3(24, 1.1, 10), Vector3(-16, 1.1, -20), Vector3(8, 1.1, 22),
		Vector3(28, 1.1, -6), Vector3(-28, 1.1, 14)
	]:
		_add_visual_box(parent, position, Vector3(1.1, 2.8, 1.1), Color(0.28, 0.2, 0.12))
		_add_visual_sphere(parent, position + Vector3(0, 2.4, 0), 2.4, Color(0.28, 0.58, 0.26))
		_add_visual_sphere(parent, position + Vector3(0.8, 3.2, -0.4), 1.5, Color(0.34, 0.68, 0.3))
	## Cliff terrace — vertical playground route outside the racing line.
	var cliff_root := Node3D.new()
	cliff_root.name = "CascadeCliffTerrace"
	cliff_root.position = Vector3(36.0, 0.0, -18.0)
	parent.add_child(cliff_root)
	for step in range(5):
		var y := 1.2 + float(step) * 2.4
		var shelf := Vector3(float(step) * -1.6, y, float(step) * -1.2)
		_add_visual_box(cliff_root, shelf, Vector3(7.5, 0.55, 4.2), Color(0.42, 0.5, 0.38))
		_add_visual_box(
			cliff_root, shelf + Vector3(0.0, 1.1, -1.8), Vector3(6.5, 2.0, 0.45), Color(0.35, 0.45, 0.32)
		)
		## Soft collision shelves so the terrace is a real vertical route.
		var body := StaticBody3D.new()
		body.name = "CliffShelf%d" % step
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = shelf + Vector3(0.0, -0.15, 0.0)
		cliff_root.add_child(body)
		var shape := BoxShape3D.new()
		shape.size = Vector3(7.5, 0.55, 4.2)
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
	## Stone bridge landmark spanning the inner basin.
	_add_visual_box(parent, Vector3(2.0, 2.4, -4.0), Vector3(18.0, 0.55, 3.2), Color(0.55, 0.52, 0.45))
	_add_visual_box(parent, Vector3(-5.0, 1.2, -4.0), Vector3(1.2, 2.6, 1.2), Color(0.48, 0.45, 0.4))
	_add_visual_box(parent, Vector3(9.0, 1.2, -4.0), Vector3(1.2, 2.6, 1.2), Color(0.48, 0.45, 0.4))
	## Start arch — Kinetic Sole midsole yellow + pursuit blue accents.
	var start := _course_points[0] if not _course_points.is_empty() else Vector3.ZERO
	_add_visual_box(parent, start + Vector3(-5.5, 3.2, 0.0), Vector3(1.0, 6.4, 1.0), Color(0.24, 0.3, 0.42))
	_add_visual_box(parent, start + Vector3(5.5, 3.2, 0.0), Vector3(1.0, 6.4, 1.0), Color(0.24, 0.3, 0.42))
	_add_visual_box(parent, start + Vector3(0.0, 6.4, 0.0), Vector3(12.0, 0.7, 1.2), Color(0.96, 0.77, 0.09), true)
	_add_visual_box(parent, start + Vector3(0.0, 5.6, 0.35), Vector3(10.0, 0.25, 0.35), Color(1.0, 0.42, 0.24), true)
	## Moss rocks + lanterns along the banks.
	for position in [
		Vector3(-18, 0.6, 8), Vector3(16, 0.55, 14), Vector3(-4, 0.5, -28), Vector3(20, 0.6, -22)
	]:
		_add_visual_sphere(parent, position, 1.4, Color(0.32, 0.42, 0.3))
		_add_visual_cylinder(parent, position + Vector3(0.0, 1.8, 0.0), 0.18, 2.4, Color(0.35, 0.3, 0.22))
		_add_visual_sphere(parent, position + Vector3(0.0, 3.1, 0.0), 0.55, Color(0.18, 0.9, 0.85), true)
	## Mist particle sheet near the main cascade.
	var mist := GPUParticles3D.new()
	mist.name = "CascadeMist"
	mist.position = Vector3(0.0, 4.0, -8.0)
	mist.amount = 48
	mist.lifetime = 3.2
	mist.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 30, 60))
	var mist_mat := ParticleProcessMaterial.new()
	mist_mat.direction = Vector3(0.0, 1.0, 0.15)
	mist_mat.spread = 28.0
	mist_mat.initial_velocity_min = 0.4
	mist_mat.initial_velocity_max = 1.6
	mist_mat.gravity = Vector3(0.0, 0.15, 0.0)
	mist_mat.scale_min = 0.35
	mist_mat.scale_max = 0.9
	mist_mat.color = Color(0.75, 0.92, 0.98, 0.35)
	mist.process_material = mist_mat
	var mist_mesh := SphereMesh.new()
	mist_mesh.radius = 0.35
	mist_mesh.height = 0.7
	mist.draw_pass_1 = mist_mesh
	mist.emitting = true
	parent.add_child(mist)



func _build_ranch_scenery(parent: Node3D) -> void:
	_add_visual_box(
		parent,
		Vector3(0.0, -0.78, 0.0),
		Vector3(150.0, 0.18, 150.0),
		_color("backdrop_color", Color(0.4, 0.6, 0.25))
	)
	for position in [
		Vector3(-18, 1.2, -4), Vector3(8, 1.2, 5), Vector3(25, 1.2, -12), Vector3(-6, 1.2, 18)
	]:
		_add_visual_cylinder(
			parent, position, 1.7, 2.4, Color(0.84, 0.64, 0.23), false, Vector3(0.0, 0.0, 90.0)
		)
	for position in [Vector3(-22, 4, 5), Vector3(18, 4, 14)]:
		_add_visual_box(parent, position, Vector3(1.1, 8.0, 1.1), Color(0.55, 0.35, 0.18))
		_add_visual_box(
			parent, position + Vector3(0, 3.0, 0), Vector3(8.0, 0.4, 0.8), Color(0.92, 0.9, 0.72)
		)
		_add_visual_box(
			parent, position + Vector3(0, 3.0, 0), Vector3(0.8, 0.4, 8.0), Color(0.92, 0.9, 0.72)
		)


func _build_prism_scenery(parent: Node3D) -> void:
	for index in range(30):
		var angle := float(index) * 2.39996
		var radius := 66.0 + float((index * 13) % 34)
		var position := Vector3(
			cos(angle) * radius, float((index * 7) % 24) - 6.0, sin(angle) * radius
		)
		_add_visual_sphere(
			parent, position, 0.18 + float(index % 3) * 0.08, Color(0.8, 0.9, 1.0), true
		)
	for position in [Vector3(-10, 6, 0), Vector3(12, 8, -4), Vector3(0, 10, 14)]:
		_add_visual_cylinder(
			parent, position, 0.8, position.y * 2.0, _color("accent_color", Color.CYAN), true
		)


func _build_ember_scenery(parent: Node3D) -> void:
	_add_visual_box(
		parent, Vector3(0.0, -3.0, 0.0), Vector3(155.0, 0.35, 155.0), Color(0.82, 0.16, 0.05), true
	)
	for position in [Vector3(-18, 6, 0), Vector3(18, 6, 0), Vector3(0, 6, -18), Vector3(0, 6, 18)]:
		_add_visual_box(parent, position, Vector3(5.5, 12.0, 5.5), Color(0.16, 0.15, 0.18))
		_add_visual_box(
			parent,
			position + Vector3(0, 6.4, 0),
			Vector3(7.0, 1.0, 7.0),
			_color("accent_color", Color.ORANGE),
			true
		)


func _build_harbor_scenery(parent: Node3D) -> void:
	## Procedural-final launch harbor presentation.
	_add_visual_box(
		parent,
		Vector3(0.0, -0.78, 0.0),
		Vector3(150.0, 0.18, 150.0),
		_color("backdrop_color", Color(0.2, 0.35, 0.42))
	)
	_add_visual_box(parent, Vector3(0, -0.4, 0), Vector3(90.0, 0.2, 90.0), Color(0.25, 0.55, 0.7), true)
	for i in range(8):
		var a := float(i) * 0.785
		_add_visual_cylinder(
			parent,
			Vector3(cos(a) * 38.0, 1.2, sin(a) * 38.0),
			0.55,
			3.2,
			Color(0.45, 0.38, 0.28)
		)
	for position in [Vector3(-20, 2, 10), Vector3(22, 2, -8), Vector3(8, 2, 24), Vector3(-12, 2, -18)]:
		_add_visual_box(parent, position, Vector3(8.0, 1.2, 2.0), Color(0.55, 0.4, 0.28))
		_add_visual_box(parent, position + Vector3(0, 1.4, 0), Vector3(1.0, 2.8, 1.0), Color(0.7, 0.72, 0.75))


func _build_neon_scenery(parent: Node3D) -> void:
	## Procedural-final launch neon yard presentation.
	_add_visual_box(
		parent, Vector3(0.0, -0.78, 0.0), Vector3(140.0, 0.18, 140.0), Color(0.08, 0.09, 0.12)
	)
	for position in [Vector3(-16, 4, 0), Vector3(16, 4, 0), Vector3(0, 5, -20), Vector3(0, 5, 20), Vector3(-22, 3, 16), Vector3(22, 3, -16)]:
		_add_visual_box(
			parent, position, Vector3(1.2, 8.0, 1.2), _color("accent_color", Color.MAGENTA), true
		)
		_add_visual_box(
			parent,
			position + Vector3(0, 4.2, 0),
			Vector3(6.0, 0.35, 0.35),
			_color("accent_color", Color.CYAN),
			true
		)


func _build_ridge_scenery(parent: Node3D) -> void:
	## Procedural-final launch ridge presentation.
	_add_visual_box(
		parent,
		Vector3(0.0, -0.78, 0.0),
		Vector3(150.0, 0.18, 150.0),
		_color("backdrop_color", Color(0.35, 0.42, 0.48))
	)
	for position in [Vector3(-24, 3, -10), Vector3(20, 4, 12), Vector3(4, 5, -22), Vector3(-8, 6, 18), Vector3(28, 3, 6)]:
		_add_visual_box(parent, position, Vector3(14.0, 2.0, 6.0), Color(0.55, 0.58, 0.62))
		_add_visual_box(
			parent, position + Vector3(0, 2.2, 0), Vector3(10.0, 0.35, 4.0), Color(0.7, 0.78, 0.85), true
		)


func _build_mesa_scenery(parent: Node3D) -> void:
	## Procedural-final launch mesa presentation.
	_add_visual_box(
		parent,
		Vector3(0.0, -0.78, 0.0),
		Vector3(160.0, 0.18, 160.0),
		_color("backdrop_color", Color(0.65, 0.4, 0.2))
	)
	for position in [Vector3(-28, 4, 8), Vector3(26, 5, -14), Vector3(0, 6, 28), Vector3(-14, 3, -24), Vector3(18, 4, 20)]:
		_add_visual_box(parent, position, Vector3(10.0, 8.0, 10.0), Color(0.72, 0.48, 0.28))
		_add_visual_cylinder(
			parent, position + Vector3(0, 5.0, 0), 3.5, 1.2, Color(0.85, 0.55, 0.3), true
		)


func _build_start_marker() -> void:
	var marker := Marker3D.new()
	marker.name = "StartPosition"
	marker.transform = _transform_at_point(0, 1.05)
	add_child(marker)
	var label := Label3D.new()
	label.name = "CourseName"
	label.position = _course_points[0] + Vector3(0.0, 5.0, 0.0)
	label.text = get_display_name()
	label.font_size = 42
	label.outline_size = 8
	label.modulate = _color("accent_color", Color.WHITE)
	add_child(label)


func _add_visual_box(
	parent: Node3D, position: Vector3, size: Vector3, color: Color, emissive: bool = false
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.position = position
	visual.mesh = mesh
	visual.material_override = _make_material(color, emissive)
	parent.add_child(visual)


func _add_visual_cylinder(
	parent: Node3D,
	position: Vector3,
	radius: float,
	height: float,
	color: Color,
	emissive: bool = false,
	rotation: Vector3 = Vector3.ZERO
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var visual := MeshInstance3D.new()
	visual.position = position
	visual.rotation_degrees = rotation
	visual.mesh = mesh
	visual.material_override = _make_material(color, emissive)
	parent.add_child(visual)


func _add_visual_sphere(
	parent: Node3D, position: Vector3, radius: float, color: Color, emissive: bool = false
) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var visual := MeshInstance3D.new()
	visual.position = position
	visual.mesh = mesh
	visual.material_override = _make_material(color, emissive)
	parent.add_child(visual)


func _make_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var cache_key := "%s:%s" % [color.to_html(true), str(emissive)]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if emissive:
		material.emission_enabled = true
		material.emission = color * 0.55
	_material_cache[cache_key] = material
	return material


func _segment_color(index: int) -> Color:
	var colors: Array = _data.get("segment_colors", [])
	if not colors.is_empty():
		return Color.from_string(
			str(colors[index % colors.size()]), _color("track_color", Color.GRAY)
		)
	return _color("track_color", Color.GRAY)


func _color(field: String, fallback: Color) -> Color:
	return Color.from_string(str(_data.get(field, "")), fallback)


func _feature_size(definition: Dictionary, fallback: Vector2) -> Vector2:
	var size: Array = definition.get("size", [])
	if size.size() != 2:
		return fallback
	return Vector2(float(size[0]), float(size[1]))


func _transform_at_point(index: int, height: float) -> Transform3D:
	var safe_index := posmod(index, _course_points.size())
	var next_index := (safe_index + 1) % _course_points.size()
	var direction := _course_points[next_index] - _course_points[safe_index]
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	var basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	return Transform3D(basis, _course_points[safe_index] + Vector3(0.0, height, 0.0))
