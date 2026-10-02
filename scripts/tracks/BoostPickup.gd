extends Area3D

## Boost energy token — distinct mesh, directional streak, vertical marker, pulse.

@export var respawn_time: float = 4.0

var _active: bool = true
var _visual_root: Node3D
var _token: MeshInstance3D
var _streak: MeshInstance3D
var _marker: MeshInstance3D
var _pulse_t: float = 0.0

const FX := preload("res://scripts/items/ItemEffectVisuals.gd")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2
	_build_visuals()


func _process(delta: float) -> void:
	if not _active or _visual_root == null:
		return
	_pulse_t += delta * 3.2
	var pulse := 1.0 + sin(_pulse_t) * 0.12
	if _token != null:
		_token.scale = Vector3(pulse, pulse, pulse)
		_token.rotation.y += delta * 2.5
	if _streak != null:
		_streak.position.z = 0.6 + sin(_pulse_t * 1.4) * 0.15
	if _marker != null:
		_marker.position.y = 2.0 + sin(_pulse_t) * 0.2


func _build_visuals() -> void:
	# Keep/replace any child mesh with a clearer token language.
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false

	_visual_root = Node3D.new()
	_visual_root.name = "BoostTokenVisual"
	add_child(_visual_root)

	_token = MeshInstance3D.new()
	_token.name = "BoostToken"
	var mesh := PrismMesh.new()
	mesh.size = Vector3(1.1, 1.4, 1.1)
	_token.mesh = mesh
	_token.material_override = _emissive(Color(1.0, 0.78, 0.15), Color(1.0, 0.55, 0.05))
	_visual_root.add_child(_token)

	_streak = MeshInstance3D.new()
	_streak.name = "DirectionalStreak"
	var streak_mesh := BoxMesh.new()
	streak_mesh.size = Vector3(0.25, 0.18, 2.4)
	_streak.mesh = streak_mesh
	_streak.position = Vector3(0, 0.2, 0.9)
	_streak.material_override = _emissive(Color(1.0, 0.9, 0.4, 0.7), Color(1.0, 0.7, 0.2))
	_visual_root.add_child(_streak)

	_marker = MeshInstance3D.new()
	_marker.name = "VerticalMarker"
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.07
	pole.height = 2.2
	_marker.mesh = pole
	_marker.position = Vector3(0, 2.0, 0)
	_marker.material_override = _emissive(Color(1.0, 0.85, 0.2), Color(1.0, 0.7, 0.1))
	_visual_root.add_child(_marker)

	var tip := MeshInstance3D.new()
	tip.name = "MarkerTip"
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.28
	tip_mesh.height = 0.56
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 3.2, 0)
	tip.material_override = _emissive(Color(1.0, 0.95, 0.4), Color(1.0, 0.8, 0.15))
	_visual_root.add_child(tip)

	var label := Label3D.new()
	label.name = "BoostLabel"
	label.text = "BOOST"
	label.font_size = 42
	label.outline_size = 8
	label.modulate = Color(1.0, 0.9, 0.35)
	label.position = Vector3(0, 3.8, 0)
	_visual_root.add_child(label)


func _emissive(albedo: Color, emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	if albedo.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = emission
	mat.roughness = 0.4
	return mat


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body.has_method("collect_boost_pickup"):
		body.collect_boost_pickup()
		FX.spawn_boost_acquire_burst(global_position + Vector3(0, 1.0, 0), get_tree())
		# HUD acknowledgement via BoostFeedback if present in race scene.
		var tree := get_tree()
		if tree != null and tree.current_scene != null:
			var fx := tree.current_scene.get_node_or_null("BoostFeedback")
			if fx != null and fx.has_method("acknowledge_pickup"):
				fx.acknowledge_pickup()
			elif fx != null and fx.has_method("set_active"):
				fx.set_active(true, false)
				tree.create_timer(0.35).timeout.connect(func():
					if is_instance_valid(fx) and fx.has_method("set_active"):
						fx.set_active(false, false)
				)
		_active = false
		visible = false
		await get_tree().create_timer(respawn_time).timeout
		_active = true
		visible = true
