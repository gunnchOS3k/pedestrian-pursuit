extends RefCounted
class_name CourseIdentityCatalog

## Authored identities and landmarks for the eight launch courses.
## V4 extends V3 with route topology, signature mechanics, boost moments, silhouette grammar.
## Original procedural landmarks only — no real-world or copyrighted copies.

const PATH_V4 := "res://data/gamefeel/course_identity_v4.json"
const PATH_V3 := "res://data/gamefeel/course_identity_v3.json"
const PATH := PATH_V4
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

const V4_REQUIRED_KEYS := [
	"visual_theme",
	"route_topology",
	"route_rhythm",
	"signature_mechanic",
	"signature_mechanic_blurb",
	"boost_moment",
	"boost_moment_blurb",
	"landmark_memory",
	"silhouette_grammar",
	"shortcut_style",
	"lighting",
	"audio_direction",
	"challenge_identity",
	"preview",
]

static var _cache: Dictionary = {}


static func load_catalog() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var path := PATH_V4 if FileAccess.file_exists(PATH_V4) else PATH_V3
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
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


static func preview_copy(track_id: String) -> String:
	var ident := identity_for(track_id)
	if ident.is_empty():
		return ""
	var preview: Dictionary = ident.get("preview", {})
	return (
		"%s\nLandmark: %s\nMechanic: %s\nBoost: %s\nShortcut: %s"
		% [
			str(preview.get("silhouette", ident.get("route_topology", ""))),
			str(preview.get("landmark", ident.get("landmark_memory", ""))),
			str(preview.get("mechanic", ident.get("signature_mechanic_blurb", ""))),
			str(preview.get("boost", ident.get("boost_moment_blurb", ""))),
			str(ident.get("shortcut_style", "")),
		]
	)



static func course_preview(track_id: String) -> Dictionary:
	var identity := identity_for(track_id)
	var preview: Dictionary = identity.get("preview", {})
	if preview.is_empty():
		return {
			"silhouette": str(identity.get("silhouette_grammar", identity.get("route_topology", ""))),
			"landmark": str(identity.get("landmark_memory", "")),
			"mechanic": str(identity.get("signature_mechanic_blurb", identity.get("signature_mechanic", ""))),
			"shortcut_risk": str(identity.get("shortcut_style", "")),
			"boost_identity": str(identity.get("boost_moment_blurb", identity.get("boost_moment", ""))),
			"boost": str(identity.get("boost_moment_blurb", identity.get("boost_moment", ""))),
		}
	return preview.duplicate(true)


static func has_v4_fields(track_id: String) -> bool:
	var ident := identity_for(track_id)
	if ident.is_empty():
		return false
	for key in V4_REQUIRED_KEYS:
		var value: Variant = ident.get(key, null)
		if value == null:
			return false
		if typeof(value) == TYPE_STRING and str(value).is_empty():
			return false
		if typeof(value) == TYPE_DICTIONARY and (value as Dictionary).is_empty():
			return false
	return true


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
			_box(node, Vector3(0, 8.0 * scale, 0), Vector3(4.2 * scale, 16.0 * scale, 1.6 * scale), Color(0.35, 0.78, 0.9), make_material, true)
			_box(node, Vector3(2.8 * scale, 6.0 * scale, 0.8 * scale), Vector3(2.0 * scale, 12.0 * scale, 1.2 * scale), Color(0.45, 0.85, 0.95), make_material, true)
			_box(node, Vector3(-2.4 * scale, 5.0 * scale, 0.4 * scale), Vector3(1.8 * scale, 10.0 * scale, 1.0 * scale), Color(0.55, 0.9, 1.0), make_material, true)
		"gate":
			_box(node, Vector3(-5.5 * scale, 3.5 * scale, 0), Vector3(1.0 * scale, 7.0 * scale, 1.0 * scale), Color(0.45, 0.32, 0.18), make_material)
			_box(node, Vector3(5.5 * scale, 3.5 * scale, 0), Vector3(1.0 * scale, 7.0 * scale, 1.0 * scale), Color(0.45, 0.32, 0.18), make_material)
			_box(node, Vector3(0, 7.2 * scale, 0), Vector3(12.2 * scale, 0.7 * scale, 1.2 * scale), Color(0.92, 0.86, 0.6), make_material, true)
		"skyline":
			_box(node, Vector3(-3, 8 * scale, -10), Vector3(3.0 * scale, 16.0 * scale, 3.0 * scale), Color(0.3, 0.32, 0.4), make_material)
			_box(node, Vector3(4, 6 * scale, -12), Vector3(2.4 * scale, 12.0 * scale, 2.4 * scale), Color(0.28, 0.3, 0.38), make_material)
		"windmill":
			_cyl(node, Vector3(0, 6.0 * scale, 0), 1.0 * scale, 12.0 * scale, Color(0.75, 0.72, 0.65), make_material)
			_box(node, Vector3(0, 11.0 * scale, 0), Vector3(12.0 * scale, 0.45 * scale, 0.45 * scale), Color(0.92, 0.9, 0.78), make_material, true)
			_box(node, Vector3(0, 11.0 * scale, 0), Vector3(0.45 * scale, 0.45 * scale, 12.0 * scale), Color(0.92, 0.9, 0.78), make_material, true)
		"barn":
			_box(node, Vector3(0, 3.5 * scale, 0), Vector3(10.0 * scale, 7.0 * scale, 8.0 * scale), Color(0.55, 0.3, 0.15), make_material)
			_box(node, Vector3(0, 7.5 * scale, 0), Vector3(12.0 * scale, 1.2 * scale, 9.0 * scale), Color(0.42, 0.2, 0.1), make_material)
		"crane":
			_box(node, Vector3(0, 8.0 * scale, 0), Vector3(1.4 * scale, 16.0 * scale, 1.4 * scale), Color(0.8, 0.6, 0.2), make_material, true)
			_box(node, Vector3(5.0 * scale, 14.0 * scale, 0), Vector3(12.0 * scale, 0.7 * scale, 0.7 * scale), Color(0.9, 0.75, 0.3), make_material, true)
			_box(node, Vector3(10.0 * scale, 10.0 * scale, 0), Vector3(1.5 * scale, 3.0 * scale, 1.5 * scale), Color(0.7, 0.55, 0.2), make_material)
		"lighthouse":
			_cyl(node, Vector3(0, 7.0 * scale, 0), 1.8 * scale, 14.0 * scale, Color(0.88, 0.88, 0.82), make_material)
			_sphere(node, Vector3(0, 14.5 * scale, 0), 2.0 * scale, Color(1.0, 0.95, 0.5), make_material, true)
		"hull":
			_box(node, Vector3(0, 1.5 * scale, 0), Vector3(4.0 * scale, 2.5 * scale, 12.0 * scale), Color(0.35, 0.38, 0.42), make_material)
			_box(node, Vector3(0, 3.2 * scale, -2.0 * scale), Vector3(1.0 * scale, 3.0 * scale, 1.0 * scale), Color(0.5, 0.5, 0.55), make_material)
		"gantry":
			_box(node, Vector3(-6.0 * scale, 5.0 * scale, 0), Vector3(1.0 * scale, 10.0 * scale, 1.0 * scale), Color(0.95, 0.2, 0.8), make_material, true)
			_box(node, Vector3(6.0 * scale, 5.0 * scale, 0), Vector3(1.0 * scale, 10.0 * scale, 1.0 * scale), Color(0.95, 0.2, 0.8), make_material, true)
			_box(node, Vector3(0, 10.0 * scale, 0), Vector3(14.0 * scale, 0.6 * scale, 0.6 * scale), Color(0.2, 0.95, 1.0), make_material, true)
		"signal":
			_cyl(node, Vector3(0, 3.5 * scale, 0), 0.35 * scale, 7.0 * scale, Color(0.3, 0.32, 0.36), make_material)
			_sphere(node, Vector3(0, 7.2 * scale, 0), 0.9 * scale, Color(1.0, 0.2, 0.35), make_material, true)
			_sphere(node, Vector3(0, 5.8 * scale, 0), 0.9 * scale, Color(1.0, 0.85, 0.15), make_material, true)
		"cliff":
			_box(node, Vector3(0, 6.0 * scale, 0), Vector3(8.0 * scale, 12.0 * scale, 4.0 * scale), Color(0.48, 0.52, 0.56), make_material)
			_box(node, Vector3(3.0 * scale, 4.0 * scale, 2.0 * scale), Vector3(6.0 * scale, 8.0 * scale, 3.0 * scale), Color(0.42, 0.46, 0.5), make_material)
		"ribbon":
			_box(node, Vector3(0, 4.0 * scale, 0), Vector3(1.2 * scale, 0.5 * scale, 14.0 * scale), Color(0.6, 0.85, 1.0), make_material, true)
			_box(node, Vector3(2.0 * scale, 6.0 * scale, 2.0 * scale), Vector3(1.0 * scale, 0.4 * scale, 10.0 * scale), Color(0.9, 0.5, 1.0), make_material, true)
		"orbit":
			_cyl(node, Vector3(0, 5.0 * scale, 0), 6.0 * scale, 0.4 * scale, Color(0.55, 0.75, 1.0), make_material, true)
			_cyl(node, Vector3(0, 5.0 * scale, 0), 4.0 * scale, 0.35 * scale, Color(0.85, 0.45, 1.0), make_material, true)
		"canyon":
			_box(node, Vector3(-4.0 * scale, 5.0 * scale, 0), Vector3(4.0 * scale, 10.0 * scale, 12.0 * scale), Color(0.68, 0.42, 0.24), make_material)
			_box(node, Vector3(4.0 * scale, 4.0 * scale, 0), Vector3(4.0 * scale, 8.0 * scale, 12.0 * scale), Color(0.74, 0.48, 0.28), make_material)
		"vent":
			_cyl(node, Vector3(0, 2.5 * scale, 0), 2.0 * scale, 5.0 * scale, Color(0.25, 0.2, 0.22), make_material)
			_sphere(node, Vector3(0, 5.5 * scale, 0), 2.2 * scale, Color(1.0, 0.4, 0.1), make_material, true)
			_box(node, Vector3(0, 8.0 * scale, 0), Vector3(1.5 * scale, 4.0 * scale, 1.5 * scale), Color(1.0, 0.55, 0.15), make_material, true)
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


static func build_macro_terrain(parent: Node3D, course_points: Array, identity: Dictionary, make_material: Callable) -> int:
	## Distinct non-color macro terrain plate + skyline massing per course.
	if parent == null or identity.is_empty() or course_points.is_empty():
		return 0
	var root := Node3D.new()
	root.name = "MacroTerrain"
	parent.add_child(root)
	var topo := str(identity.get("macro_terrain", ""))
	var color := Color(0.45, 0.5, 0.42)
	match topo:
		"river_shelf_with_cascade_drop":
			color = Color(0.25, 0.55, 0.45)
			_box(root, Vector3(0, -0.6, 0), Vector3(80, 1.0, 80), color, make_material)
			_box(root, Vector3(-18, 4, -10), Vector3(8, 10, 4), Color(0.3, 0.7, 0.85), make_material, true)
		"open_field_to_timber_compression":
			color = Color(0.45, 0.62, 0.28)
			_box(root, Vector3(0, -0.5, 0), Vector3(100, 0.8, 100), color, make_material)
			_box(root, Vector3(12, 3, -8), Vector3(10, 6, 8), Color(0.45, 0.32, 0.18), make_material)
		"harbor_flat_with_pier_elevation":
			color = Color(0.35, 0.5, 0.62)
			_box(root, Vector3(0, -0.8, 0), Vector3(90, 0.6, 90), color, make_material)
			_box(root, Vector3(0, 0.4, 8), Vector3(40, 0.4, 6), Color(0.7, 0.78, 0.85), make_material, true)
		"freight_corridor_canyon":
			color = Color(0.18, 0.18, 0.24)
			_box(root, Vector3(0, -0.4, 0), Vector3(70, 0.6, 70), color, make_material)
			_box(root, Vector3(-14, 5, 0), Vector3(4, 12, 40), Color(0.25, 0.22, 0.35), make_material)
			_box(root, Vector3(14, 5, 0), Vector3(4, 12, 40), Color(0.25, 0.22, 0.35), make_material)
		"stacked_shelves_with_void_gaps":
			color = Color(0.55, 0.58, 0.62)
			_box(root, Vector3(0, 2, 0), Vector3(50, 1.0, 20), color, make_material)
			_box(root, Vector3(8, 8, -12), Vector3(30, 1.0, 16), color, make_material)
			_box(root, Vector3(-6, 14, -22), Vector3(24, 1.0, 14), color, make_material)
		"elevated_ribbon_over_void":
			color = Color(0.55, 0.45, 0.85)
			_box(root, Vector3(0, 6, 0), Vector3(60, 0.5, 6), color, make_material, true)
			_cyl(root, Vector3(0, 3, -20), 2.0, 8.0, Color(0.7, 0.6, 1.0), make_material, true)
		"mesa_plateau_canyon_walls":
			color = Color(0.78, 0.55, 0.32)
			_box(root, Vector3(0, -0.3, 0), Vector3(110, 0.6, 40), color, make_material)
			_box(root, Vector3(-20, 6, -10), Vector3(8, 14, 30), Color(0.7, 0.45, 0.25), make_material)
			_box(root, Vector3(20, 5, -8), Vector3(7, 12, 28), Color(0.72, 0.48, 0.28), make_material)
		"basalt_walls_forge_courtyard":
			color = Color(0.28, 0.22, 0.2)
			_box(root, Vector3(0, -0.4, 0), Vector3(70, 0.7, 70), color, make_material)
			_box(root, Vector3(-12, 7, 0), Vector3(5, 16, 24), Color(0.35, 0.25, 0.22), make_material)
			_box(root, Vector3(12, 7, 0), Vector3(5, 16, 24), Color(0.35, 0.25, 0.22), make_material)
			_cyl(root, Vector3(0, 5, -16), 2.5, 12.0, Color(1.0, 0.4, 0.15), make_material, true)
		_:
			_box(root, Vector3(0, -0.5, 0), Vector3(60, 0.6, 60), color, make_material)
	return root.get_child_count()
