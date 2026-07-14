extends Node3D

## Procedural animated runner — replaces capsule mesh presentation.

@export var body_color: Color = Color(1.0, 0.82, 0.35, 1.0)
@export var accent_color: Color = Color(1.0, 0.35, 0.2, 1.0)
@export var is_ai: bool = false

var _torso: MeshInstance3D
var _head: MeshInstance3D
var _leg_l: MeshInstance3D
var _leg_r: MeshInstance3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _phase: float = 0.0
var _parent_body: CharacterBody3D


func _ready() -> void:
	_parent_body = get_parent() as CharacterBody3D
	_hide_legacy_meshes()
	_build_figure()


func _hide_legacy_meshes() -> void:
	if _parent_body == null:
		return
	for name in ["BodyMesh", "ShoeMesh"]:
		var node := _parent_body.get_node_or_null(name)
		if node is MeshInstance3D:
			(node as MeshInstance3D).visible = false


func _build_figure() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.roughness = 0.55
	var accent := StandardMaterial3D.new()
	accent.albedo_color = accent_color
	accent.roughness = 0.4

	_torso = _mesh_box(Vector3(0.55, 0.7, 0.35), Vector3(0, 1.05, 0), body_mat)
	_head = _mesh_sphere(0.22, Vector3(0, 1.55, 0), body_mat)
	_leg_l = _mesh_box(Vector3(0.18, 0.55, 0.22), Vector3(-0.14, 0.4, 0), accent)
	_leg_r = _mesh_box(Vector3(0.18, 0.55, 0.22), Vector3(0.14, 0.4, 0), accent)
	_arm_l = _mesh_box(Vector3(0.14, 0.5, 0.14), Vector3(-0.4, 1.05, 0), body_mat)
	_arm_r = _mesh_box(Vector3(0.14, 0.5, 0.14), Vector3(0.4, 1.05, 0), body_mat)
	# Shoe soles
	_mesh_box(Vector3(0.28, 0.1, 0.42), Vector3(-0.14, 0.08, 0.06), accent)
	_mesh_box(Vector3(0.28, 0.1, 0.42), Vector3(0.14, 0.08, 0.06), accent)


func _mesh_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _mesh_sphere(radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	if _parent_body == null:
		return
	var speed := _parent_body.velocity.length()
	var grounded := _parent_body.is_on_floor() if _parent_body.has_method("is_on_floor") else true
	var cadence := clampf(speed * 0.35, 0.0, 14.0)
	if grounded and cadence > 0.4:
		_phase += delta * cadence
	else:
		_phase = lerpf(_phase, 0.0, delta * 4.0)
	var swing := sin(_phase) * minf(0.55, cadence * 0.05)
	if _leg_l:
		_leg_l.rotation.x = swing
	if _leg_r:
		_leg_r.rotation.x = -swing
	if _arm_l:
		_arm_l.rotation.x = -swing * 0.8
	if _arm_r:
		_arm_r.rotation.x = swing * 0.8
	if _torso:
		_torso.rotation.z = sin(_phase * 0.5) * 0.04
