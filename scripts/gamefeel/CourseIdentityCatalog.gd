extends RefCounted
class_name CourseIdentityCatalog

## Authored identities and landmarks for the eight launch courses.
## Original procedural landmarks only — no real-world or copyrighted copies.

const PATH := "res://data/gamefeel/course_identity_v3.json"
const LAUNCH_TRACKS := [
	"verdant_cascade_circuit",
	"cloverwind_ranch",
	"tideglass_harbor",
	"neon_switchyard",
	"cloudstep_ridge",
	"prism_apex",
	"mirage_mesa",
	"emberkeep_gauntlet",
]

static var _cache: Dictionary = {}


static func load_catalog() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_cache = parsed
	return _cache


static func identity_for(track_id: String) -> Dictionary:
	var catalog := load_catalog()
	var courses: Dictionary = catalog.get("courses", {})
	if courses.has(track_id):
		return (courses[track_id] as Dictionary).duplicate(true)
	return {}


static func landmark_count(track_id: String) -> int:
	return int(identity_for(track_id).get("landmarks", []).size())


static func apply_lighting(world_environment: WorldEnvironment, sun: DirectionalLight3D, identity: Dictionary) -> void:
	if identity.is_empty():
		return
	var lighting: Dictionary = identity.get("lighting", {})
	if world_environment != null and world_environment.environment != null:
		var env: Environment = world_environment.environment
		var ambient := Color.from_string(str(lighting.get("ambient", "")), env.ambient_light_color)
		env.ambient_light_color = ambient
		env.ambient_light_energy = float(lighting.get("ambient_energy", env.ambient_light_energy))
		env.fog_enabled = float(lighting.get("fog_density", 0.0)) > 0.0001
		if env.fog_enabled:
			env.fog_light_color = Color.from_string(str(lighting.get("fog_color", "")), ambient)
			env.fog_density = float(lighting.get("fog_density", 0.004))
	if sun != null:
		var degrees: Array = lighting.get("sun_degrees", [])
		if degrees.size() >= 3:
			sun.rotation_degrees = Vector3(float(degrees[0]), float(degrees[1]), float(degrees[2]))
		sun.light_energy = float(lighting.get("sun_energy", sun.light_energy))


static func build_landmarks(parent: Node3D, course_points: Array, identity: Dictionary, make_material: Callable) -> int:
	if parent == null or identity.is_empty():
		return 0
	var root := Node3D.new()
	root.name = "Landmarks"
	parent.add_child(root)
	var built := 0
	for raw in identity.get("landmarks", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = raw
		var idx := int(spec.get("point_index", 0))
		if idx < 0 or idx >= course_points.size():
			continue
		var base: Vector3 = course_points[idx]
		var off: Array = spec.get("offset", [0, 0, 0])
		if off.size() >= 3:
			base += Vector3(float(off[0]), float(off[1]), float(off[2]))
		var kind := str(spec.get("kind", "beacon"))
		var node := _build_kind(kind, base, float(spec.get("scale", 1.0)), make_material)
		node.name = "Landmark_%s" % str(spec.get("id", kind))
		node.set_meta("landmark_kind", kind)
		node.set_meta("landmark_role", str(spec.get("role", "")))
		root.add_child(node)
		built += 1
	return built


static func _build_kind(kind: String, origin: Vector3, scale: float, make_material: Callable) -> Node3D:
	var node := Node3D.new()
	node.position = origin
	match kind:
		"arch":
			_box(node, Vector3(-6.0 * scale, 4.0 * scale, 0.0), Vector3(1.2 * scale, 8.0 * scale, 1.2 * scale), Color(0.85, 0.82, 0.7), make_material)
			_box(node, Vector3(6.0 * scale, 4.0 * scale, 0.0), Vector3(1.2 * scale, 8.0 * scale, 1.2 * scale), Color(0.85, 0.82, 0.7), make_material)
			_box(node, Vector3(0.0, 8.2 * scale, 0.0), Vector3(13.2 * scale, 1.1 * scale, 1.6 * scale), Color(0.95, 0.88, 0.55), make_material, true)
		"tower":
			_box(node, Vector3(0, 6.0 * scale, 0), Vector3(2.4 * scale, 12.0 * scale, 2.4 * scale), Color(0.55, 0.5, 0.48), make_material)
			_cyl(node, Vector3(0, 13.0 * scale, 0), 1.6 * scale, 2.2 * scale, Color(1.0, 0.75, 0.25), make_material, true)
		"bridge":
			_box(node, Vector3(0, 1.6 * scale, 0), Vector3(16.0 * scale, 0.45 * scale, 4.2 * scale), Color(0.7, 0.72, 0.78), make_material, true)
			_box(node, Vector3(-7.0 * scale, 0.8 * scale, 0), Vector3(1.0 * scale, 1.8 * scale, 3.6 * scale), Color(0.5, 0.45, 0.4), make_material)
			_box(node, Vector3(7.0 * scale, 0.8 * scale, 0), Vector3(1.0 * scale, 1.8 * scale, 3.6 * scale), Color(0.5, 0.45, 0.4), make_material)
		"tunnel":
			_cyl(node, Vector3(0, 3.2 * scale, 0), 4.5 * scale, 8.0 * scale, Color(0.28, 0.3, 0.34), make_material)
		"sculpture":
			_cyl(node, Vector3(0, 3.5 * scale, 0), 0.7 * scale, 7.0 * scale, Color(0.75, 0.85, 0.95), make_material, true)
			_sphere(node, Vector3(0, 7.4 * scale, 0), 1.8 * scale, Color(0.95, 0.7, 0.35), make_material, true)
		"waterfall":
			_box(node, Vector3(0, 7.0 * scale, 0), Vector3(3.2 * scale, 14.0 * scale, 1.4 * scale), Color(0.35, 0.78, 0.9), make_material, true)
			_box(node, Vector3(2.4 * scale, 5.0 * scale, 0.6 * scale), Vector3(1.6 * scale, 10.0 * scale, 1.0 * scale), Color(0.45, 0.85, 0.95), make_material, true)
		"gate":
			_box(node, Vector3(-5.5 * scale, 3.5 * scale, 0), Vector3(1.0 * scale, 7.0 * scale, 1.0 * scale), Color(0.45, 0.32, 0.18), make_material)
			_box(node, Vector3(5.5 * scale, 3.5 * scale, 0), Vector3(1.0 * scale, 7.0 * scale, 1.0 * scale), Color(0.45, 0.32, 0.18), make_material)
			_box(node, Vector3(0, 7.2 * scale, 0), Vector3(12.2 * scale, 0.7 * scale, 1.2 * scale), Color(0.92, 0.86, 0.6), make_material, true)
		"skyline":
			_box(node, Vector3(-3, 8 * scale, -10), Vector3(3.0 * scale, 16.0 * scale, 3.0 * scale), Color(0.3, 0.32, 0.4), make_material)
			_box(node, Vector3(4, 6 * scale, -12), Vector3(2.4 * scale, 12.0 * scale, 2.4 * scale), Color(0.28, 0.3, 0.38), make_material)
		_:
			_cyl(node, Vector3(0, 5.5 * scale, 0), 0.55 * scale, 11.0 * scale, Color(0.95, 0.85, 0.35), make_material, true)
			_sphere(node, Vector3(0, 11.2 * scale, 0), 1.3 * scale, Color(1.0, 0.9, 0.4), make_material, true)
	return node


static func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, make_material: Callable, emissive: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.position = pos
	visual.mesh = mesh
	visual.material_override = make_material.call(color, emissive)
	parent.add_child(visual)


static func _cyl(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, make_material: Callable, emissive: bool = false) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var visual := MeshInstance3D.new()
	visual.position = pos
	visual.mesh = mesh
	visual.material_override = make_material.call(color, emissive)
	parent.add_child(visual)


static func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, make_material: Callable, emissive: bool = false) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var visual := MeshInstance3D.new()
	visual.position = pos
	visual.mesh = mesh
	visual.material_override = make_material.call(color, emissive)
	parent.add_child(visual)
