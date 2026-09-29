extends RefCounted
class_name CourseWorldAssembler

## V4 macro terrain + skyline assemblies. Collision stays on CourseTrack primitives.
## Each theme builds a distinct silhouette grammar — not a color swap.

static func assemble(
	parent: Node3D,
	course_points: Array,
	theme: String,
	identity: Dictionary,
	make_material: Callable
) -> Dictionary:
	var root := Node3D.new()
	root.name = "WorldAssembly_V4"
	parent.add_child(root)
	var stats := {
		"macro_props": 0,
		"skyline_props": 0,
		"silhouette_grammar": str(identity.get("silhouette_grammar", theme)),
	}
	_ground_plane(root, theme, identity, make_material)
	stats["macro_props"] += _macro_terrain(root, course_points, theme, make_material)
	stats["skyline_props"] += _skyline(root, course_points, theme, identity, make_material)
	stats["signature_props"] = _signature_elements(root, course_points, theme, identity, make_material)
	root.set_meta("v4_world_stats", stats)
	return stats


static func _ground_plane(parent: Node3D, theme: String, identity: Dictionary, make_material: Callable) -> void:
	var color := Color(0.25, 0.35, 0.28)
	var size := Vector3(160.0, 0.2, 160.0)
	match theme:
		"cascade_garden":
			color = Color(0.18, 0.42, 0.28)
			size = Vector3(150.0, 0.18, 150.0)
		"windy_ranch":
			color = Color(0.42, 0.58, 0.22)
			size = Vector3(170.0, 0.18, 170.0)
		"harbor_glass":
			color = Color(0.18, 0.32, 0.4)
			size = Vector3(160.0, 0.18, 160.0)
		"neon_yard":
			color = Color(0.07, 0.08, 0.11)
			size = Vector3(145.0, 0.18, 145.0)
		"ridge_cloud":
			color = Color(0.32, 0.38, 0.44)
			size = Vector3(165.0, 0.18, 165.0)
		"prism_void":
			color = Color(0.05, 0.06, 0.14)
			size = Vector3(180.0, 0.12, 180.0)
		"mesa_mirage":
			color = Color(0.62, 0.4, 0.2)
			size = Vector3(175.0, 0.18, 175.0)
		"ember_fortress":
			color = Color(0.22, 0.1, 0.08)
			size = Vector3(155.0, 0.22, 155.0)
	_box(parent, Vector3(0, -0.85, 0), size, color, make_material, theme == "ember_fortress" or theme == "prism_void")


static func _macro_terrain(parent: Node3D, course_points: Array, theme: String, make_material: Callable) -> int:
	var count := 0
	match theme:
		"cascade_garden":
			count += _cascade_macro(parent, course_points, make_material)
		"windy_ranch":
			count += _ranch_macro(parent, course_points, make_material)
		"harbor_glass":
			count += _harbor_macro(parent, course_points, make_material)
		"neon_yard":
			count += _neon_macro(parent, course_points, make_material)
		"ridge_cloud":
			count += _ridge_macro(parent, course_points, make_material)
		"prism_void":
			count += _prism_macro(parent, course_points, make_material)
		"mesa_mirage":
			count += _mesa_macro(parent, course_points, make_material)
		"ember_fortress":
			count += _ember_macro(parent, course_points, make_material)
		_:
			count += 1
	return count


static func _skyline(
	parent: Node3D, course_points: Array, theme: String, identity: Dictionary, make_material: Callable
) -> int:
	var count := 0
	var n := maxi(course_points.size(), 1)
	match theme:
		"cascade_garden":
			# Tiered falls wall readable across the lap.
			for i in range(5):
				var p: Vector3 = course_points[mini(2, n - 1)] + Vector3(-18.0 - float(i) * 2.0, 4.0 + float(i), 6.0 - float(i) * 1.5)
				_box(parent, p, Vector3(4.0, 8.0 + float(i) * 2.0, 2.0), Color(0.4, 0.82, 0.92), make_material, true)
				count += 1
		"windy_ranch":
			var barn_p: Vector3 = course_points[mini(3, n - 1)] + Vector3(22, 4, 4)
			_box(parent, barn_p, Vector3(14, 8, 10), Color(0.55, 0.32, 0.16), make_material)
			_box(parent, barn_p + Vector3(0, 5.5, 0), Vector3(16, 1.2, 12), Color(0.45, 0.2, 0.12), make_material)
			count += 2
			var mill: Vector3 = course_points[mini(7, n - 1)] + Vector3(-20, 6, 8)
			_cyl(parent, mill, 1.2, 12.0, Color(0.7, 0.68, 0.6), make_material)
			_box(parent, mill + Vector3(0, 5, 0), Vector3(10, 0.4, 0.6), Color(0.9, 0.88, 0.75), make_material, true)
			count += 2
		"harbor_glass":
			var crane: Vector3 = course_points[mini(4, n - 1)] + Vector3(24, 8, 10)
			_box(parent, crane, Vector3(1.5, 16, 1.5), Color(0.75, 0.55, 0.2), make_material, true)
			_box(parent, crane + Vector3(6, 7, 0), Vector3(14, 0.6, 0.6), Color(0.85, 0.7, 0.25), make_material, true)
			count += 2
			var light: Vector3 = course_points[0] + Vector3(-16, 8, 14)
			_cyl(parent, light, 2.0, 16.0, Color(0.85, 0.85, 0.8), make_material)
			_sphere(parent, light + Vector3(0, 9, 0), 2.2, Color(1.0, 0.95, 0.55), make_material, true)
			count += 2
		"neon_yard":
			for i in range(6):
				var ang := float(i) * 1.05
				var p := Vector3(cos(ang) * 42.0, 6.0, sin(ang) * 42.0)
				_box(parent, p, Vector3(1.4, 12.0, 1.4), Color(0.95, 0.15, 0.75), make_material, true)
				_box(parent, p + Vector3(0, 6, 0), Vector3(10, 0.35, 0.35), Color(0.2, 0.95, 1.0), make_material, true)
				count += 2
			# Container skyline
			for i in range(8):
				var cp: Vector3 = course_points[i % n] + Vector3(28 * (1 if i % 2 == 0 else -1), 2.5, float(i % 3) * 4.0)
				_box(parent, cp, Vector3(5, 4, 8), Color(0.2 + float(i % 3) * 0.15, 0.25, 0.35), make_material)
				count += 1
		"ridge_cloud":
			for i in range(5):
				var p: Vector3 = course_points[mini(i * 2, n - 1)] + Vector3(-22.0 - float(i), 3.0 + float(i) * 1.5, float(i) * 3.0)
				_box(parent, p, Vector3(18, 3 + float(i), 8), Color(0.5, 0.55, 0.6), make_material)
				count += 1
			# Cloud banks
			for i in range(6):
				var c := Vector3(cos(float(i)) * 50.0, 14.0 + float(i % 3), sin(float(i)) * 50.0)
				_sphere(parent, c, 5.0 + float(i % 2), Color(0.85, 0.9, 0.95, 0.55), make_material, true)
				count += 1
		"prism_void":
			for i in range(10):
				var a := float(i) * 0.62
				var r := 55.0 + float(i % 4) * 6.0
				_cyl(parent, Vector3(cos(a) * r, 8.0, sin(a) * r), 0.4, 16.0, Color(0.55, 0.8, 1.0), make_material, true)
				count += 1
			_sphere(parent, Vector3(0, 22, 0), 4.5, Color(0.7, 0.5, 1.0), make_material, true)
			count += 1
		"mesa_mirage":
			for i in range(4):
				var p: Vector3 = course_points[mini(2 + i * 2, n - 1)] + Vector3(26 * (1 if i % 2 == 0 else -1), 5, float(i) * 5.0)
				_box(parent, p, Vector3(14, 10 + float(i) * 2, 14), Color(0.72, 0.48, 0.28), make_material)
				_box(parent, p + Vector3(0, 6, 0), Vector3(10, 1.5, 10), Color(0.8, 0.55, 0.32), make_material)
				count += 2
		"ember_fortress":
			for i in range(4):
				var a := float(i) * 1.57
				var p := Vector3(cos(a) * 36.0, 8.0, sin(a) * 36.0)
				_box(parent, p, Vector3(8, 16, 8), Color(0.18, 0.14, 0.16), make_material)
				_box(parent, p + Vector3(0, 9, 0), Vector3(10, 1.2, 10), Color(1.0, 0.35, 0.1), make_material, true)
				count += 2
	return count


static func _signature_elements(
	parent: Node3D, course_points: Array, theme: String, identity: Dictionary, make_material: Callable
) -> int:
	var count := 0
	var n := maxi(course_points.size(), 1)
	match theme:
		"cascade_garden":
			# Water runoff strip cue near boost moment (point ~1-2).
			var p: Vector3 = course_points[mini(1, n - 1)] + Vector3(0, 0.05, 0)
			_box(parent, p, Vector3(5.5, 0.08, 14.0), Color(0.35, 0.85, 1.0), make_material, true)
			count += 1
		"windy_ranch":
			for i in range(3):
				var p: Vector3 = course_points[mini(7, n - 1)] + Vector3(float(i - 1) * 4.0, 3.0, -6.0)
				_box(parent, p, Vector3(0.3, 6.0, 0.3), Color(0.85, 0.8, 0.6), make_material)
				count += 1
		"harbor_glass":
			var p: Vector3 = course_points[mini(2, n - 1)]
			_box(parent, p + Vector3(0, 0.2, 0), Vector3(12, 0.15, 3.5), Color(0.55, 0.85, 0.95), make_material, true)
			count += 1
		"neon_yard":
			for i in range(3):
				var p: Vector3 = course_points[mini(1, n - 1)] + Vector3(0, 0.08, float(i) * 4.0)
				_box(parent, p, Vector3(4.5, 0.1, 3.2), Color(1.0, 0.2, 0.85), make_material, true)
				count += 1
		"ridge_cloud":
			for i in range(2):
				var p: Vector3 = course_points[mini(3 + i, n - 1)] + Vector3(0, 0.15, 0)
				_cyl(parent, p, 2.4, 0.25, Color(0.7, 0.9, 1.0), make_material, true)
				count += 1
		"prism_void":
			for i in range(3):
				var p: Vector3 = course_points[mini(1 + i * 2, n - 1)]
				_box(parent, p + Vector3(0, 3.5, 0), Vector3(8, 0.4, 0.4), Color(0.4, 0.9, 1.0), make_material, true)
				_box(parent, p + Vector3(-4, 2, 0), Vector3(0.4, 4, 0.4), Color(0.9, 0.4, 1.0), make_material, true)
				_box(parent, p + Vector3(4, 2, 0), Vector3(0.4, 4, 0.4), Color(0.9, 0.4, 1.0), make_material, true)
				count += 3
		"mesa_mirage":
			var p: Vector3 = course_points[0]
			_box(parent, p + Vector3(0, 0.06, 0), Vector3(6, 0.08, 22), Color(1.0, 0.75, 0.25), make_material, true)
			count += 1
		"ember_fortress":
			var p: Vector3 = course_points[mini(6, n - 1)]
			_cyl(parent, p + Vector3(0, 2, 0), 1.8, 4.0, Color(1.0, 0.35, 0.08), make_material, true)
			_sphere(parent, p + Vector3(0, 5, 0), 2.0, Color(1.0, 0.55, 0.15), make_material, true)
			count += 2
	return count


static func _cascade_macro(parent: Node3D, course_points: Array, make_material: Callable) -> int:
	var c := 0
	var n := maxi(course_points.size(), 1)
	# River ribbon beside the track.
	for i in range(n):
		var p: Vector3 = course_points[i] + Vector3(-10.0, -0.4, 0.0)
		_box(parent, p, Vector3(6.0, 0.2, 8.0), Color(0.2, 0.55, 0.75), make_material, true)
		c += 1
	# Garden hedges
	for i in range(0, n, 2):
		var p: Vector3 = course_points[i] + Vector3(12.0, 1.0, 0.0)
		_box(parent, p, Vector3(1.2, 2.0, 4.0), Color(0.22, 0.48, 0.2), make_material)
		_sphere(parent, p + Vector3(0, 1.8, 0), 1.6, Color(0.28, 0.58, 0.25), make_material)
		c += 2
	return c


static func _ranch_macro(parent: Node3D, course_points: Array, make_material: Callable) -> int:
	var c := 0
	var n := maxi(course_points.size(), 1)
	for i in range(n):
		var side := 1.0 if i % 2 == 0 else -1.0
		var p: Vector3 = course_points[i] + Vector3(side * 16.0, 0.6, 0.0)
		_cyl(parent, p, 0.35, 1.4, Color(0.5, 0.32, 0.15), make_material)
		_box(parent, p + Vector3(side * 1.5, 0.5, 0), Vector3(3.0, 0.15, 0.15), Color(0.55, 0.38, 0.18), make_material)
		c += 2
	# Hay bales
	for i in range(4):
		var p: Vector3 = course_points[mini(i * 2, n - 1)] + Vector3(-14, 0.8, float(i) * 2.0)
		_cyl(parent, p, 1.4, 1.6, Color(0.85, 0.7, 0.25), make_material, false, Vector3(0, 0, 90))
		c += 1
	return c


static func _harbor_macro(parent: Node3D, course_points: Array, make_material: Callable) -> int:
	var c := 0
	var n := maxi(course_points.size(), 1)
	_box(parent, Vector3(0, -0.5, 0), Vector3(100, 0.15, 100), Color(0.22, 0.5, 0.65), make_material, true)
	c += 1
	for i in range(n):
		var p: Vector3 = course_points[i] + Vector3(14.0, 0.4, 0.0)
		_box(parent, p, Vector3(2.5, 0.8, 6.0), Color(0.55, 0.4, 0.28), make_material)
		c += 1
	# Abstract hulls
	for i in range(3):
		var p: Vector3 = course_points[mini(5 + i, n - 1)] + Vector3(-20, 1.2, float(i) * 6.0)
		_box(parent, p, Vector3(4, 2.5, 12), Color(0.35, 0.38, 0.42), make_material)
		c += 1
	return c


static func _neon_macro(parent: Node3D, course_points: Array, make_material: Callable) -> int:
	var c := 0
	var n := maxi(course_points.size(), 1)
	for i in range(n):
		var p: Vector3 = course_points[i] + Vector3(0, 0.02, 0)
		_box(parent, p + Vector3(0, -0.2, 0), Vector3(3.0, 0.05, 6.0), Color(0.15, 0.9, 1.0), make_material, true)
		c += 1
	return c


static func _ridge_macro(parent: Node3D, course_points: Array, make_material: Callable) -> int:
	var c := 0
	var n := maxi(course_points.size(), 1)
	for i in range(n):
		var elev := float(i) * 0.8
		var p: Vector3 = course_points[i] + Vector3(-14.0, elev * 0.3, 0.0)
		_box(parent, p, Vector3(10, 2.0 + elev * 0.2, 8), Color(0.48, 0.52, 0.56), make_material)
		c += 1
	return c


static func _prism_macro(parent: Node3D, course_points: Array, make_material: Callable) -> int:
	var c := 0
	var n := maxi(course_points.size(), 1)
	for i in range(n):
		var hue := Color.from_hsv(float(i) / float(n), 0.65, 0.95)
		var p: Vector3 = course_points[i] + Vector3(0, -0.15, 0)
		_box(parent, p, Vector3(2.5, 0.12, 5.0), hue, make_material, true)
		c += 1
	return c


static func _mesa_macro(parent: Node3D, course_points: Array, make_material: Callable) -> int:
	var c := 0
	var n := maxi(course_points.size(), 1)
	for i in range(n):
		var p: Vector3 = course_points[i] + Vector3(18.0 * (1.0 if i % 2 == 0 else -1.0), 1.5, 0.0)
		_box(parent, p, Vector3(8, 3, 6), Color(0.7, 0.45, 0.25), make_material)
		c += 1
	return c


static func _ember_macro(parent: Node3D, course_points: Array, make_material: Callable) -> int:
	var c := 0
	var n := maxi(course_points.size(), 1)
	_box(parent, Vector3(0, -2.5, 0), Vector3(140, 0.3, 140), Color(0.75, 0.15, 0.05), make_material, true)
	c += 1
	for i in range(0, n, 2):
		var p: Vector3 = course_points[i] + Vector3(12, 1.5, 0)
		_box(parent, p, Vector3(3, 3, 3), Color(0.2, 0.16, 0.18), make_material)
		_cyl(parent, p + Vector3(0, 3, 0), 0.8, 2.5, Color(1.0, 0.4, 0.1), make_material, true)
		c += 2
	return c


static func _box(
	parent: Node3D, pos: Vector3, size: Vector3, color: Color, make_material: Callable, emissive: bool = false
) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.position = pos
	visual.mesh = mesh
	visual.material_override = make_material.call(color, emissive)
	parent.add_child(visual)


static func _cyl(
	parent: Node3D,
	pos: Vector3,
	radius: float,
	height: float,
	color: Color,
	make_material: Callable,
	emissive: bool = false,
	rotation: Vector3 = Vector3.ZERO
) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var visual := MeshInstance3D.new()
	visual.position = pos
	visual.rotation_degrees = rotation
	visual.mesh = mesh
	visual.material_override = make_material.call(color, emissive)
	parent.add_child(visual)


static func _sphere(
	parent: Node3D, pos: Vector3, radius: float, color: Color, make_material: Callable, emissive: bool = false
) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var visual := MeshInstance3D.new()
	visual.position = pos
	visual.mesh = mesh
	visual.material_override = make_material.call(color, emissive)
	parent.add_child(visual)
