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
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
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
	visual.material_override = _make_material(
		_segment_color(index), _data.get("theme", "") == "prism_void"
	)
	body.add_child(visual)

	if bool(_data.get("guard_rails", false)):
		for side in [-1.0, 1.0]:
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
	var pad := Area3D.new()
	pad.name = "BouncePad%d" % int(definition.get("point_index", 0))
	pad.set_script(BOUNCE_PAD_SCRIPT)
	pad.set("bounce_force", float(definition.get("bounce_force", 12.0)))
	pad.set("forward_boost", float(definition.get("forward_boost", 4.0)))
	pad.transform = _transform_at_point(int(definition.get("point_index", 0)), 0.2)
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


func _add_shortcut_corridor(parent: Node3D, route: Dictionary) -> void:
	## Physical corridor between entry/exit path points. Does not alter checkpoint sequence.
	var entry_i := int(route.get("entry_point_index", 0))
	var exit_i := int(route.get("exit_point_index", entry_i))
	if entry_i < 0 or exit_i < 0 or entry_i >= _course_points.size() or exit_i >= _course_points.size():
		return
	var entry := _course_points[entry_i]
	var exitp := _course_points[exit_i]
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
	## Procedural-final launch riverside presentation.
	_add_visual_box(
		parent,
		Vector3(0.0, -0.78, 0.0),
		Vector3(140.0, 0.18, 140.0),
		_color("backdrop_color", Color(0.2, 0.5, 0.3))
	)
	_add_visual_cylinder(parent, Vector3(0.0, -0.55, 0.0), 24.0, 0.18, Color(0.2, 0.65, 0.82), true)
	for position in [Vector3(-13, 6, -2), Vector3(0, 8, -8), Vector3(14, 5, 2), Vector3(-20, 4, 10), Vector3(18, 7, -14)]:
		_add_visual_cylinder(parent, position, 3.2, position.y * 2.0, Color(0.35, 0.8, 0.9), true)
	for position in [Vector3(-8, 1.2, 12), Vector3(10, 1.2, -16), Vector3(-22, 1.2, -6), Vector3(22, 1.2, 8)]:
		_add_visual_box(parent, position, Vector3(1.4, 2.4, 1.4), Color(0.25, 0.45, 0.22))
		_add_visual_sphere(parent, position + Vector3(0, 2.0, 0), 2.2, Color(0.3, 0.62, 0.28))



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
