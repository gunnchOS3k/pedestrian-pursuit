extends RefCounted
class_name ItemEffectVisuals

## Visible world consequences for the six launch items. Original shoe-tech language.


static func spawn_turbo_toes(racer: Node3D) -> void:
	if racer == null:
		return
	var streak := MeshInstance3D.new()
	streak.name = "TurboToesStreak"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.2, 3.8)
	streak.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.15, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.1)
	streak.material_override = mat
	streak.position = Vector3(0.0, 0.7, 1.6)
	racer.add_child(streak)
	_fade_free(streak, 2.0)


static func decorate_lace_trap(trap: Node3D) -> void:
	if trap == null:
		return
	# Visible lace strands + warning flash.
	for i in range(5):
		var lace := MeshInstance3D.new()
		lace.name = "LaceStrand%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.08, 2.2)
		lace.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.88, 0.55)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.3) * 0.4
		lace.material_override = mat
		lace.position = Vector3(float(i - 2) * 0.35, 0.12, 0.0)
		lace.rotation_degrees = Vector3(0, float(i - 2) * 12.0, 0)
		trap.add_child(lace)
	var warn := Label3D.new()
	warn.name = "LaceWarning"
	warn.text = "LACES"
	warn.font_size = 48
	warn.outline_size = 8
	warn.modulate = Color(1.0, 0.85, 0.2)
	warn.position = Vector3(0, 1.2, 0)
	trap.add_child(warn)


static func spawn_sole_shield(racer: Node3D) -> void:
	if racer == null:
		return
	_clear_named(racer, "SoleShieldVisual")
	var shield := MeshInstance3D.new()
	shield.name = "SoleShieldVisual"
	var mesh := SphereMesh.new()
	mesh.radius = 1.15
	mesh.height = 1.6
	shield.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.75, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 1.0)
	shield.material_override = mat
	shield.position = Vector3(0, 1.0, 0)
	racer.add_child(shield)
	# Sole plate silhouette underfoot.
	var sole := MeshInstance3D.new()
	sole.name = "SoleShieldPlate"
	var plate := BoxMesh.new()
	plate.size = Vector3(0.9, 0.12, 1.6)
	sole.mesh = plate
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.5, 0.85, 1.0, 0.7)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.emission_enabled = true
	pmat.emission = Color(0.3, 0.7, 1.0)
	sole.material_override = pmat
	sole.position = Vector3(0, 0.15, 0)
	racer.add_child(sole)


static func break_sole_shield(racer: Node3D) -> void:
	if racer == null:
		return
	_burst(racer.global_position + Vector3(0, 1, 0), Color(0.4, 0.8, 1.0), racer.get_tree())
	_clear_named(racer, "SoleShieldVisual")
	_clear_named(racer, "SoleShieldPlate")


static func spawn_pulse_horn(racer: Node3D) -> void:
	if racer == null:
		return
	var cone := MeshInstance3D.new()
	cone.name = "PulseHornWave"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = 4.5
	mesh.height = 8.0
	cone.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	cone.material_override = mat
	cone.rotation_degrees = Vector3(90, 0, 0)
	cone.position = Vector3(0, 1.0, -4.0)
	racer.add_child(cone)
	_fade_free(cone, 1.0)


static func spawn_magnet_lace(racer: Node3D, target: Node3D) -> void:
	if racer == null or target == null:
		return
	var tether := MeshInstance3D.new()
	tether.name = "MagnetLaceTether"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 1.0)
	tether.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.3, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.2, 1.0)
	tether.material_override = mat
	racer.add_child(tether)
	var warn := Label3D.new()
	warn.name = "MagnetLaceWarning"
	warn.text = "MAGNET"
	warn.font_size = 56
	warn.outline_size = 10
	warn.modulate = Color(1.0, 0.4, 1.0)
	warn.position = Vector3(0, 2.4, 0)
	target.add_child(warn)
	var tree := racer.get_tree()
	if tree == null:
		return
	var duration := 1.2
	for i in range(12):
		tree.create_timer(0.1 * float(i + 1)).timeout.connect(func():
			if is_instance_valid(tether) and is_instance_valid(racer) and is_instance_valid(target):
				var a2: Vector3 = racer.global_position + Vector3(0, 1.0, 0)
				var b2: Vector3 = target.global_position + Vector3(0, 1.0, 0)
				tether.global_position = (a2 + b2) * 0.5
				var d2 := a2.distance_to(b2)
				tether.scale = Vector3(1, 1, maxf(d2, 0.5))
				if d2 > 0.01:
					tether.look_at(b2, Vector3.UP)
		)
	tree.create_timer(duration).timeout.connect(func():
		if is_instance_valid(tether):
			tether.queue_free()
		if is_instance_valid(warn):
			warn.queue_free()
	)


static func spawn_bounce_bubble(racer: Node3D, duration: float) -> void:
	if racer == null:
		return
	_clear_named(racer, "BounceBubbleVisual")
	var bubble := MeshInstance3D.new()
	bubble.name = "BounceBubbleVisual"
	var mesh := SphereMesh.new()
	mesh.radius = 1.4
	mesh.height = 2.8
	bubble.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 1.0, 0.75, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.95, 0.55)
	bubble.material_override = mat
	bubble.position = Vector3(0, 1.1, 0)
	racer.add_child(bubble)
	var tree := racer.get_tree()
	if tree:
		tree.create_timer(maxf(duration, 0.5)).timeout.connect(func():
			if is_instance_valid(bubble):
				_burst(racer.global_position + Vector3(0, 1, 0), Color(0.4, 1.0, 0.6), tree)
				bubble.queue_free()
		)


static func spawn_item_acquire_burst(world_pos: Vector3, tree: SceneTree) -> void:
	_burst(world_pos, Color(0.95, 0.4, 1.0), tree)


static func spawn_boost_acquire_burst(world_pos: Vector3, tree: SceneTree) -> void:
	_burst(world_pos, Color(1.0, 0.75, 0.15), tree)


static func _burst(world_pos: Vector3, color: Color, tree: SceneTree) -> void:
	if tree == null or tree.current_scene == null:
		return
	var burst := MeshInstance3D.new()
	burst.name = "PickupBurst"
	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	mesh.height = 1.6
	burst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	burst.material_override = mat
	burst.global_position = world_pos
	tree.current_scene.add_child(burst)
	_fade_free(burst, 0.45)


static func _fade_free(node: Node3D, seconds: float) -> void:
	if node == null:
		return
	var tree := node.get_tree()
	if tree == null:
		node.queue_free()
		return
	tree.create_timer(seconds).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)


static func _clear_named(host: Node, name: String) -> void:
	if host == null:
		return
	var existing := host.get_node_or_null(name)
	if existing != null:
		existing.queue_free()
