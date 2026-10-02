extends Area3D

## Bounce pad — launches racers upward.
## V4: compression ring, upward arrows, launch charge pulse.

@export var bounce_force: float = 16.0
@export var forward_boost: float = 4.0
@export var cooldown_sec: float = 0.45

var _last_hit: Dictionary = {}
var _pulse_t: float = 0.0
var _ring: MeshInstance3D
var _arrows: Array[MeshInstance3D] = []
var _charge: MeshInstance3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 2
	call_deferred("_upgrade_visuals")


func _process(delta: float) -> void:
	_pulse_t += delta * 3.5
	if _ring != null:
		var s := 1.0 + sin(_pulse_t) * 0.08
		_ring.scale = Vector3(s, 1.0, s)
	if _charge != null:
		_charge.position.y = 0.35 + absf(sin(_pulse_t)) * 0.55
		var mat := _charge.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 0.6 + absf(sin(_pulse_t * 1.5))
	for i in range(_arrows.size()):
		var a := _arrows[i]
		if a:
			a.position.y = 0.6 + float(i) * 0.55 + sin(_pulse_t + float(i)) * 0.1


func _upgrade_visuals() -> void:
	var size := Vector2(5.0, 5.0)
	for child in get_children():
		if child is MeshInstance3D:
			var mesh_inst := child as MeshInstance3D
			if mesh_inst.mesh is BoxMesh:
				var box := mesh_inst.mesh as BoxMesh
				size = Vector2(box.size.x, box.size.z)
			mesh_inst.visible = false

	var root := Node3D.new()
	root.name = "BouncePadVisual_V4"
	add_child(root)

	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = maxf(size.x, size.y) * 0.45
	pad_mesh.bottom_radius = maxf(size.x, size.y) * 0.45
	pad_mesh.height = 0.12
	pad.mesh = pad_mesh
	pad.material_override = _mat(Color(0.95, 0.4, 0.2), Color(1.0, 0.35, 0.1))
	root.add_child(pad)

	_ring = MeshInstance3D.new()
	_ring.name = "CompressionRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = maxf(size.x, size.y) * 0.38
	ring_mesh.outer_radius = maxf(size.x, size.y) * 0.5
	_ring.mesh = ring_mesh
	_ring.position = Vector3(0, 0.15, 0)
	_ring.material_override = _mat(Color(1.0, 0.75, 0.25), Color(1.0, 0.6, 0.1))
	root.add_child(_ring)

	for i in range(3):
		var arrow := MeshInstance3D.new()
		arrow.name = "UpArrow%d" % i
		var amesh := PrismMesh.new()
		amesh.size = Vector3(0.9, 0.7, 0.35)
		arrow.mesh = amesh
		arrow.position = Vector3(0, 0.6 + float(i) * 0.55, 0)
		arrow.material_override = _mat(Color(1.0, 0.9, 0.35), Color(1.0, 0.7, 0.15))
		root.add_child(arrow)
		_arrows.append(arrow)

	_charge = MeshInstance3D.new()
	_charge.name = "LaunchCharge"
	var cmesh := SphereMesh.new()
	cmesh.radius = 0.35
	cmesh.height = 0.7
	_charge.mesh = cmesh
	_charge.position = Vector3(0, 0.4, 0)
	_charge.material_override = _mat(Color(1.0, 0.95, 0.6, 0.7), Color(1.0, 0.8, 0.2))
	root.add_child(_charge)

	var label := Label3D.new()
	label.name = "BounceLabel"
	label.text = "BOUNCE"
	label.font_size = 40
	label.outline_size = 8
	label.modulate = Color(1.0, 0.7, 0.3)
	label.position = Vector3(0, 2.8, 0)
	root.add_child(label)


func _mat(albedo: Color, emission: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	if albedo.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = emission
	return mat


func _on_body_entered(body: Node3D) -> void:
	if not (body is CharacterBody3D):
		return
	var id := body.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	if float(_last_hit.get(id, -999.0)) + cooldown_sec > now:
		return
	_last_hit[id] = now
	var force := bounce_force
	var forward_kick := forward_boost
	# Accessibility: soften launch impulse when reduce-motion is on.
	var a11y := _accessibility()
	if a11y != null and bool(a11y.get("reduce_motion")):
		force *= 0.72
		forward_kick *= 0.72
	if body.has_method("apply_bounce_impulse"):
		body.apply_bounce_impulse(force)
	else:
		body.velocity.y = force
	var forward := -body.global_transform.basis.z
	body.velocity.x += forward.x * forward_kick
	body.velocity.z += forward.z * forward_kick
	# Brief charge flash
	if _charge != null:
		_charge.scale = Vector3(1.8, 1.8, 1.8)


func _accessibility() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("AccessibilitySettings")
