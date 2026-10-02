extends Area3D

## Speed lane — increases racer top speed while inside.
## V4: ground-integrated chevrons, emissive flow, clear edges, HUD ack.

@export var speed_bonus: float = 1.25

var _flow_t: float = 0.0
var _chevrons: Array[MeshInstance3D] = []
var _edge_start: MeshInstance3D
var _edge_end: MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	collision_layer = 0
	collision_mask = 2
	call_deferred("_upgrade_visuals")


func _process(delta: float) -> void:
	_flow_t += delta * 4.0
	for i in range(_chevrons.size()):
		var c := _chevrons[i]
		if c == null:
			continue
		var mat := c.material_override as StandardMaterial3D
		if mat:
			var pulse := 0.45 + 0.55 * absf(sin(_flow_t + float(i) * 0.7))
			mat.emission_energy_multiplier = pulse


func _upgrade_visuals() -> void:
	# Keep collision; replace flat pad with chevron language if a box visual exists.
	var size := Vector2(6.0, 12.0)
	for child in get_children():
		if child is MeshInstance3D:
			var mesh_inst := child as MeshInstance3D
			if mesh_inst.mesh is BoxMesh:
				var box := mesh_inst.mesh as BoxMesh
				size = Vector2(box.size.x, box.size.z)
			mesh_inst.visible = false

	var root := Node3D.new()
	root.name = "SpeedLaneVisual_V4"
	add_child(root)

	# Ground pad
	var pad := MeshInstance3D.new()
	pad.name = "LanePad"
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(size.x, 0.06, size.y)
	pad.mesh = pad_mesh
	pad.material_override = _mat(Color(0.1, 0.55, 0.75, 0.65), Color(0.15, 0.8, 1.0))
	root.add_child(pad)

	# Directional chevrons
	var count := maxi(3, int(size.y / 3.0))
	for i in range(count):
		var chevron := MeshInstance3D.new()
		chevron.name = "Chevron%d" % i
		var cmesh := PrismMesh.new()
		cmesh.size = Vector3(size.x * 0.55, 0.18, 1.4)
		chevron.mesh = cmesh
		chevron.rotation_degrees = Vector3(90, 180, 0)
		chevron.position = Vector3(0, 0.12, -size.y * 0.5 + 1.2 + float(i) * (size.y / float(count)))
		chevron.material_override = _mat(Color(1.0, 0.85, 0.2), Color(1.0, 0.7, 0.1))
		root.add_child(chevron)
		_chevrons.append(chevron)

	_edge_start = _edge_bar(root, Vector3(0, 0.1, -size.y * 0.5), size.x, Color(0.2, 1.0, 0.6))
	_edge_end = _edge_bar(root, Vector3(0, 0.1, size.y * 0.5), size.x, Color(1.0, 0.45, 0.2))

	var label := Label3D.new()
	label.name = "SpeedLaneLabel"
	label.text = "SPEED"
	label.font_size = 40
	label.outline_size = 8
	label.modulate = Color(0.6, 0.95, 1.0)
	label.position = Vector3(0, 1.6, 0)
	root.add_child(label)


func _edge_bar(parent: Node3D, pos: Vector3, width: float, color: Color) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width * 1.05, 0.2, 0.35)
	bar.mesh = mesh
	bar.position = pos
	bar.material_override = _mat(color, color)
	parent.add_child(bar)
	return bar


func _mat(albedo: Color, emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	if albedo.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = 1.0
	return mat


func _on_enter(body: Node3D) -> void:
	if body.has_method("set_terrain_modifiers"):
		body.set_terrain_modifiers("speed_lane", speed_bonus, 1.0)
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var fx := tree.current_scene.get_node_or_null("BoostFeedback")
		if fx != null and fx.has_method("acknowledge_speed_lane"):
			fx.acknowledge_speed_lane()
		elif fx != null and fx.has_method("set_active"):
			fx.set_active(true, false)


func _on_exit(body: Node3D) -> void:
	if body.has_method("set_terrain_modifiers"):
		body.set_terrain_modifiers("standard", 1.0, 1.0)
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var fx := tree.current_scene.get_node_or_null("BoostFeedback")
		if fx != null and fx.has_method("set_active"):
			# Only clear if not in an active boost event — acknowledge_speed_lane may keep brief trail.
			if fx.has_method("is_boost_event_active") and fx.is_boost_event_active():
				return
			fx.set_active(false, false)
