extends Node3D

## Personality-driven procedural runners — rear-readable modular silhouettes.
## Uses RunnerProfile motion fields (cadence/stride/bounce/lean/arm/head_bob)
## and distinct pose overlay branches for start/boost/stumble/recovery/finish.

const RunnerProfileScript = preload("res://scripts/data/RunnerProfile.gd")

@export var body_color: Color = Color(1.0, 0.82, 0.35, 1.0)
@export var accent_color: Color = Color(1.0, 0.35, 0.2, 1.0)
@export var is_ai: bool = false
@export var runner_id: String = "dash_reed"

var profile: RunnerProfile
var _torso: MeshInstance3D
var _head: MeshInstance3D
var _leg_l: MeshInstance3D
var _leg_r: MeshInstance3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _hair: MeshInstance3D
var _shoe_l: MeshInstance3D
var _shoe_r: MeshInstance3D
var _heel_l: MeshInstance3D
var _heel_r: MeshInstance3D
var _jacket: MeshInstance3D
var _scarf: MeshInstance3D
var _backpack: MeshInstance3D
var _accent_fx: MeshInstance3D
var _name_label: Label3D
var _phase: float = 0.0
var _parent_body: CharacterBody3D
var _emotion_t: float = 0.0
var _pose_state: String = "idle"
var _pose_timer: float = 0.0
var _boosting: bool = false
var _menu_preview: bool = false
var _rest_torso_y: float = 1.05
var _rest_head_y: float = 1.55


func _ready() -> void:
	_parent_body = get_parent() as CharacterBody3D
	_hide_legacy_meshes()
	if profile == null:
		apply_profile(RunnerProfileScript.by_id(runner_id))
	else:
		_rebuild()


func apply_profile(p: RunnerProfile) -> void:
	profile = p
	runner_id = p.id
	body_color = p.body_color
	accent_color = p.accent_color
	_rebuild()


func set_menu_preview(enabled: bool) -> void:
	_menu_preview = enabled
	_parent_body = null if enabled else (get_parent() as CharacterBody3D)
	if enabled:
		_pose_state = "idle"
		_pose_timer = 0.0
		_boosting = false


func set_pose_state(state: String, duration: float = 0.45) -> void:
	_pose_state = state
	_pose_timer = duration


func set_boosting(active: bool) -> void:
	_boosting = active
	if active and profile:
		set_pose_state(str(profile.boost_style), 0.35)
	elif active:
		set_pose_state("forward_lean", 0.35)


func play_start_line() -> void:
	set_pose_state(str(profile.start_pose if profile else "lace_check"), 1.2)


func play_stumble() -> void:
	set_pose_state(str(profile.stumble_style if profile else "stutter"), 0.55)


func play_recovery() -> void:
	set_pose_state(str(profile.recovery_style if profile else "jog"), 0.7)


func play_finish(won: bool) -> void:
	set_pose_state(str(profile.finish_style if profile else "arms_up") if won else "defeat", 2.0)


func _hide_legacy_meshes() -> void:
	if _parent_body == null:
		return
	for name in ["BodyMesh", "ShoeMesh"]:
		var node := _parent_body.get_node_or_null(name)
		if node is MeshInstance3D:
			(node as MeshInstance3D).visible = false


func _rebuild() -> void:
	for child in get_children():
		child.free()
	_torso = null
	_head = null
	_leg_l = null
	_leg_r = null
	_arm_l = null
	_arm_r = null
	_hair = null
	_shoe_l = null
	_shoe_r = null
	_heel_l = null
	_heel_r = null
	_jacket = null
	_scarf = null
	_backpack = null
	_accent_fx = null
	_name_label = null
	_build_figure()


func _build_figure() -> void:
	var hs := profile.height_scale if profile else 1.0
	var ws := profile.width_scale if profile else 1.0
	var ls := profile.leg_scale if profile else 1.0
	var arch := profile.archetype if profile else "all_terrain"

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.roughness = 0.55
	var accent := StandardMaterial3D.new()
	accent.albedo_color = accent_color
	accent.roughness = 0.4
	accent.emission_enabled = arch in ["kinetic", "sprinter", "trick"]
	if accent.emission_enabled:
		accent.emission = accent_color
		accent.emission_energy_multiplier = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = accent_color.darkened(0.35)
	dark.roughness = 0.6

	# Distinct body topology per archetype (not only color).
	match arch:
		"sprinter":
			_torso = _mesh_box(Vector3(0.62 * ws, 0.58 * hs, 0.32 * ws), Vector3(0, 1.0 * hs, 0.02), body_mat)
			_head = _mesh_sphere(0.2 * hs, Vector3(0, 1.48 * hs, 0.04), body_mat)
			_leg_l = _mesh_box(Vector3(0.2 * ws, 0.5 * ls, 0.24), Vector3(-0.15 * ws, 0.38 * ls, 0), accent)
			_leg_r = _mesh_box(Vector3(0.2 * ws, 0.5 * ls, 0.24), Vector3(0.15 * ws, 0.38 * ls, 0), accent)
			_arm_l = _mesh_box(Vector3(0.13 * ws, 0.55 * hs, 0.13), Vector3(-0.42 * ws, 1.0 * hs, 0.04), body_mat)
			_arm_r = _mesh_box(Vector3(0.13 * ws, 0.55 * hs, 0.13), Vector3(0.42 * ws, 1.0 * hs, 0.04), body_mat)
			_jacket = _mesh_box(Vector3(0.58 * ws, 0.42 * hs, 0.08), Vector3(0, 1.05 * hs, -0.18), dark)
			_hair = _mesh_box(Vector3(0.28 * hs, 0.14, 0.22), Vector3(0, 1.62 * hs, -0.06), accent)
			_heel_l = _mesh_box(Vector3(0.18, 0.1, 0.22), Vector3(-0.15 * ws, 0.1, -0.22), accent)
			_heel_r = _mesh_box(Vector3(0.18, 0.1, 0.22), Vector3(0.15 * ws, 0.1, -0.22), accent)
		"parkour":
			_torso = _mesh_box(Vector3(0.48 * ws, 0.72 * hs, 0.3 * ws), Vector3(0, 1.08 * hs, 0), body_mat)
			_head = _mesh_sphere(0.2 * hs, Vector3(0, 1.58 * hs, 0), body_mat)
			_leg_l = _mesh_box(Vector3(0.16 * ws, 0.62 * ls, 0.2), Vector3(-0.13 * ws, 0.42 * ls, 0), accent)
			_leg_r = _mesh_box(Vector3(0.16 * ws, 0.62 * ls, 0.2), Vector3(0.13 * ws, 0.42 * ls, 0), accent)
			_arm_l = _mesh_box(Vector3(0.12 * ws, 0.58 * hs, 0.12), Vector3(-0.38 * ws, 1.1 * hs, 0), body_mat)
			_arm_r = _mesh_box(Vector3(0.12 * ws, 0.58 * hs, 0.12), Vector3(0.38 * ws, 1.1 * hs, 0), body_mat)
			_backpack = _mesh_box(Vector3(0.34 * ws, 0.38 * hs, 0.2), Vector3(0, 1.15 * hs, -0.26), dark)
			_scarf = _mesh_box(Vector3(0.1, 0.45 * hs, 0.08), Vector3(0.18 * ws, 1.0 * hs, -0.14), accent)
			_hair = _mesh_box(Vector3(0.14, 0.32, 0.12), Vector3(0.06, 1.72 * hs, -0.02), accent)
			_heel_l = _mesh_box(Vector3(0.14, 0.08, 0.16), Vector3(-0.13 * ws, 0.08, -0.18), accent)
			_heel_r = _mesh_box(Vector3(0.14, 0.08, 0.16), Vector3(0.13 * ws, 0.08, -0.18), accent)
		"endurance":
			_torso = _mesh_box(Vector3(0.5 * ws, 0.78 * hs, 0.28 * ws), Vector3(0, 1.12 * hs, 0), body_mat)
			_head = _mesh_sphere(0.21 * hs, Vector3(0, 1.66 * hs, 0), body_mat)
			_leg_l = _mesh_box(Vector3(0.15 * ws, 0.68 * ls, 0.18), Vector3(-0.12 * ws, 0.45 * ls, 0), accent)
			_leg_r = _mesh_box(Vector3(0.15 * ws, 0.68 * ls, 0.18), Vector3(0.12 * ws, 0.45 * ls, 0), accent)
			_arm_l = _mesh_box(Vector3(0.12 * ws, 0.52 * hs, 0.12), Vector3(-0.36 * ws, 1.12 * hs, 0), body_mat)
			_arm_r = _mesh_box(Vector3(0.12 * ws, 0.52 * hs, 0.12), Vector3(0.36 * ws, 1.12 * hs, 0), body_mat)
			_jacket = _mesh_box(Vector3(0.48 * ws, 0.55 * hs, 0.06), Vector3(0, 1.15 * hs, -0.16), accent)
			_hair = _mesh_sphere(0.16 * hs, Vector3(0, 1.78 * hs, -0.04), body_mat)
			_heel_l = _mesh_box(Vector3(0.12, 0.07, 0.12), Vector3(-0.12 * ws, 0.07, -0.16), dark)
			_heel_r = _mesh_box(Vector3(0.12, 0.07, 0.12), Vector3(0.12 * ws, 0.07, -0.16), dark)
		"uphill":
			_torso = _mesh_box(Vector3(0.72 * ws, 0.68 * hs, 0.42 * ws), Vector3(0, 1.05 * hs, 0), body_mat)
			_head = _mesh_sphere(0.24 * hs, Vector3(0, 1.55 * hs, 0), body_mat)
			_leg_l = _mesh_box(Vector3(0.22 * ws, 0.5 * ls, 0.26), Vector3(-0.18 * ws, 0.38 * ls, 0), accent)
			_leg_r = _mesh_box(Vector3(0.22 * ws, 0.5 * ls, 0.26), Vector3(0.18 * ws, 0.38 * ls, 0), accent)
			_arm_l = _mesh_box(Vector3(0.18 * ws, 0.48 * hs, 0.18), Vector3(-0.48 * ws, 1.05 * hs, 0), body_mat)
			_arm_r = _mesh_box(Vector3(0.18 * ws, 0.48 * hs, 0.18), Vector3(0.48 * ws, 1.05 * hs, 0), body_mat)
			_jacket = _mesh_box(Vector3(0.78 * ws, 0.5 * hs, 0.12), Vector3(0, 1.1 * hs, -0.24), dark)
			_hair = _mesh_box(Vector3(0.2, 0.1, 0.16), Vector3(0, 1.7 * hs, -0.02), dark)
			_heel_l = _mesh_box(Vector3(0.24, 0.14, 0.2), Vector3(-0.18 * ws, 0.1, -0.2), accent)
			_heel_r = _mesh_box(Vector3(0.24, 0.14, 0.2), Vector3(0.18 * ws, 0.1, -0.2), accent)
		"trick":
			_torso = _mesh_box(Vector3(0.52 * ws, 0.62 * hs, 0.34 * ws), Vector3(0, 1.02 * hs, 0), body_mat)
			_head = _mesh_sphere(0.21 * hs, Vector3(0, 1.5 * hs, 0), body_mat)
			_leg_l = _mesh_box(Vector3(0.17 * ws, 0.55 * ls, 0.2), Vector3(-0.14 * ws, 0.4 * ls, 0), accent)
			_leg_r = _mesh_box(Vector3(0.17 * ws, 0.55 * ls, 0.2), Vector3(0.14 * ws, 0.4 * ls, 0), accent)
			_arm_l = _mesh_box(Vector3(0.13 * ws, 0.52 * hs, 0.13), Vector3(-0.4 * ws, 1.02 * hs, 0), body_mat)
			_arm_r = _mesh_box(Vector3(0.13 * ws, 0.52 * hs, 0.13), Vector3(0.4 * ws, 1.02 * hs, 0), body_mat)
			_scarf = _mesh_box(Vector3(0.12, 0.55 * hs, 0.1), Vector3(-0.22 * ws, 0.95 * hs, -0.12), accent)
			_hair = _mesh_box(Vector3(0.26, 0.18, 0.2), Vector3(-0.1, 1.64 * hs, 0.02), accent)
			_heel_l = _mesh_box(Vector3(0.2, 0.1, 0.28), Vector3(-0.14 * ws, 0.1, -0.24), accent)
			_heel_r = _mesh_box(Vector3(0.2, 0.1, 0.28), Vector3(0.14 * ws, 0.1, -0.24), accent)
		"cornering":
			_torso = _mesh_box(Vector3(0.46 * ws, 0.7 * hs, 0.36 * ws), Vector3(0.02, 1.06 * hs, 0), body_mat)
			_head = _mesh_sphere(0.2 * hs, Vector3(0.02, 1.56 * hs, 0), body_mat)
			_leg_l = _mesh_box(Vector3(0.15 * ws, 0.58 * ls, 0.22), Vector3(-0.12 * ws, 0.4 * ls, 0), accent)
			_leg_r = _mesh_box(Vector3(0.15 * ws, 0.58 * ls, 0.22), Vector3(0.16 * ws, 0.4 * ls, 0), accent)
			_arm_l = _mesh_box(Vector3(0.11 * ws, 0.48 * hs, 0.11), Vector3(-0.34 * ws, 1.08 * hs, 0), body_mat)
			_arm_r = _mesh_box(Vector3(0.11 * ws, 0.48 * hs, 0.11), Vector3(0.42 * ws, 1.08 * hs, 0), body_mat)
			_scarf = _mesh_box(Vector3(0.08, 0.4 * hs, 0.28), Vector3(0, 1.2 * hs, -0.2), accent)
			_jacket = _mesh_box(Vector3(0.42 * ws, 0.45 * hs, 0.07), Vector3(0.04, 1.1 * hs, -0.2), dark)
			_hair = _mesh_box(Vector3(0.16, 0.12, 0.2), Vector3(0.04, 1.7 * hs, -0.04), dark)
			_heel_l = _mesh_box(Vector3(0.1, 0.08, 0.26), Vector3(-0.12 * ws, 0.08, -0.22), accent)
			_heel_r = _mesh_box(Vector3(0.1, 0.08, 0.26), Vector3(0.16 * ws, 0.08, -0.22), accent)
		"kinetic":
			_torso = _mesh_box(Vector3(0.54 * ws, 0.68 * hs, 0.34 * ws), Vector3(0, 1.08 * hs, 0), body_mat)
			_head = _mesh_sphere(0.22 * hs, Vector3(0, 1.58 * hs, 0), body_mat)
			_leg_l = _mesh_box(Vector3(0.17 * ws, 0.56 * ls, 0.2), Vector3(-0.14 * ws, 0.4 * ls, 0), accent)
			_leg_r = _mesh_box(Vector3(0.17 * ws, 0.56 * ls, 0.2), Vector3(0.14 * ws, 0.4 * ls, 0), accent)
			_arm_l = _mesh_box(Vector3(0.13 * ws, 0.5 * hs, 0.13), Vector3(-0.4 * ws, 1.08 * hs, 0), body_mat)
			_arm_r = _mesh_box(Vector3(0.13 * ws, 0.5 * hs, 0.13), Vector3(0.4 * ws, 1.08 * hs, 0), body_mat)
			_backpack = _mesh_box(Vector3(0.4 * ws, 0.32 * hs, 0.22), Vector3(0, 1.2 * hs, -0.28), dark)
			_accent_fx = _mesh_sphere(0.1, Vector3(0, 1.35 * hs, 0.22), accent)
			_hair = _mesh_box(Vector3(0.18, 0.1, 0.14), Vector3(0, 1.72 * hs, 0), dark)
			_heel_l = _mesh_sphere(0.09, Vector3(-0.14 * ws, 0.1, -0.18), accent)
			_heel_r = _mesh_sphere(0.09, Vector3(0.14 * ws, 0.1, -0.18), accent)
		_: # all_terrain
			_torso = _mesh_box(Vector3(0.55 * ws, 0.7 * hs, 0.35 * ws), Vector3(0, 1.05 * hs, 0), body_mat)
			_head = _mesh_sphere(0.22 * hs, Vector3(0, 1.55 * hs, 0), body_mat)
			_leg_l = _mesh_box(Vector3(0.18 * ws, 0.55 * ls, 0.22), Vector3(-0.14 * ws, 0.4 * ls, 0), accent)
			_leg_r = _mesh_box(Vector3(0.18 * ws, 0.55 * ls, 0.22), Vector3(0.14 * ws, 0.4 * ls, 0), accent)
			_arm_l = _mesh_box(Vector3(0.14 * ws, 0.5 * hs, 0.14), Vector3(-0.4 * ws, 1.05 * hs, 0), body_mat)
			_arm_r = _mesh_box(Vector3(0.14 * ws, 0.5 * hs, 0.14), Vector3(0.4 * ws, 1.05 * hs, 0), body_mat)
			_jacket = _mesh_box(Vector3(0.52 * ws, 0.48 * hs, 0.08), Vector3(0, 1.08 * hs, -0.2), dark)
			_hair = _mesh_box(Vector3(0.18, 0.12, 0.14), Vector3(0, 1.7 * hs, -0.02), body_mat)
			_heel_l = _mesh_box(Vector3(0.16, 0.09, 0.18), Vector3(-0.14 * ws, 0.09, -0.2), accent)
			_heel_r = _mesh_box(Vector3(0.16, 0.09, 0.18), Vector3(0.14 * ws, 0.09, -0.2), accent)

	_shoe_l = _mesh_box(Vector3(0.3 * ws, 0.12, 0.46), Vector3(-0.14 * ws, 0.08, 0.08), accent)
	_shoe_r = _mesh_box(Vector3(0.3 * ws, 0.12, 0.46), Vector3(0.14 * ws, 0.08, 0.08), accent)

	_rest_torso_y = _torso.position.y if _torso else 1.05 * hs
	_rest_head_y = _head.position.y if _head else 1.55 * hs

	_name_label = Label3D.new()
	_name_label.text = profile.display_name if profile else "Runner"
	_name_label.font_size = 28
	_name_label.modulate = Color(1, 1, 1, 0.9)
	_name_label.position = Vector3(0, 1.95 * hs, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.outline_modulate = Color(0, 0, 0, 0.8)
	_name_label.outline_size = 4
	add_child(_name_label)


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
	_emotion_t += delta
	if _pose_timer > 0.0:
		_pose_timer -= delta
		_apply_pose_overlay(delta)
		if _pose_timer <= 0.0 and _pose_state != "idle":
			_pose_state = "idle"

	var cadence_scale := profile.cadence_scale if profile else 1.0
	var stride_scale := profile.stride_scale if profile else 1.0
	var bounce_scale := profile.bounce_scale if profile else 1.0
	var lean_scale := profile.lean_scale if profile else 1.0
	var arm_scale := profile.arm_scale if profile else 1.0
	var head_bob := profile.head_bob if profile else 1.0

	var speed := 0.0
	var grounded := true
	if _menu_preview:
		# Idle personality without a CharacterBody3D parent.
		_phase += delta * (1.1 + bounce_scale * 0.6)
		speed = 0.0
	elif _parent_body != null:
		speed = _parent_body.velocity.length()
		grounded = _parent_body.is_on_floor() if _parent_body.has_method("is_on_floor") else true
		var cadence := clampf(speed * 0.35 * cadence_scale, 0.0, 16.0)
		if grounded and cadence > 0.35 and (_pose_state == "idle" or _boosting or _is_boost_style(_pose_state)):
			_phase += delta * cadence
		elif _pose_state == "idle":
			_phase += delta * (1.2 + bounce_scale)
		else:
			_phase = lerpf(_phase, 0.0, delta * 3.0)
	else:
		return

	if _pose_timer > 0.0 and not _is_boost_style(_pose_state) and _pose_state != "idle":
		_animate_silhouette_props(delta, bounce_scale)
		return

	var swing := sin(_phase) * minf(0.62, (speed * 0.35 * cadence_scale) * 0.05 + 0.08) * stride_scale
	if _menu_preview:
		swing = sin(_phase) * 0.12 * stride_scale

	if _boosting or _is_boost_style(_pose_state):
		swing *= 1.15
		_apply_boost_style(delta, lean_scale)
	elif _torso:
		_torso.rotation.x = lerpf(_torso.rotation.x, -0.04 * lean_scale * (speed / 20.0), delta * 6.0)

	if _leg_l:
		_leg_l.rotation.x = swing
	if _leg_r:
		_leg_r.rotation.x = -swing
	if _arm_l:
		_arm_l.rotation.x = -swing * 0.8 * arm_scale
	if _arm_r:
		_arm_r.rotation.x = swing * 0.8 * arm_scale
	if _torso:
		_torso.rotation.z = sin(_phase * 0.5) * 0.045 * bounce_scale
		_torso.position.y = _rest_torso_y + sin(_phase * 2.0) * 0.02 * bounce_scale
	if _head:
		_head.position.y = _rest_head_y + sin(_phase * 2.0) * 0.015 * head_bob
		_head.rotation.y = sin(_emotion_t * 0.7) * 0.08
	_animate_silhouette_props(delta, bounce_scale)


func _animate_silhouette_props(delta: float, bounce_scale: float) -> void:
	if _hair:
		_hair.rotation.z = sin(_phase * 1.5) * 0.12 * bounce_scale
		_hair.rotation.x = sin(_phase) * 0.06
	if _scarf:
		_scarf.rotation.z = sin(_emotion_t * 2.2) * 0.18
		_scarf.rotation.x = sin(_emotion_t * 1.4) * 0.1
	if _jacket:
		_jacket.rotation.x = sin(_phase * 0.8) * 0.03
	if _backpack:
		_backpack.rotation.x = sin(_phase) * 0.04
	if _heel_l:
		_heel_l.rotation.x = sin(_phase) * 0.08
	if _heel_r:
		_heel_r.rotation.x = -sin(_phase) * 0.08
	if _accent_fx and profile and profile.archetype == "kinetic":
		_accent_fx.rotate_y(delta * 3.0)
		_accent_fx.scale = Vector3.ONE * (1.0 + 0.08 * sin(_emotion_t * 6.0))


func _is_boost_style(state: String) -> bool:
	return state in [
		"forward_lean", "snap_lean", "wall_lean", "float_lean",
		"shoulder_drive", "spin_lean", "banked_lean", "kinetic_flare", "boost",
	]


func _apply_boost_style(delta: float, lean_scale: float) -> void:
	var style := _pose_state if _is_boost_style(_pose_state) else (profile.boost_style if profile else "forward_lean")
	if _torso == null:
		return
	match style:
		"snap_lean":
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.42 * lean_scale, delta * 14.0)
			if _arm_l:
				_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.35, delta * 10.0)
			if _arm_r:
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.35, delta * 10.0)
		"wall_lean":
			_torso.rotation.z = lerpf(_torso.rotation.z, 0.28 * lean_scale, delta * 10.0)
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.12, delta * 8.0)
		"float_lean":
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.1 * lean_scale, delta * 4.0)
			_torso.position.y = _rest_torso_y + 0.06
		"shoulder_drive":
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.22 * lean_scale, delta * 7.0)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -1.1, delta * 8.0)
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -0.3, delta * 8.0)
		"spin_lean":
			_torso.rotation.y = sin(_emotion_t * 10.0) * 0.35
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.2 * lean_scale, delta * 8.0)
		"banked_lean":
			_torso.rotation.z = lerpf(_torso.rotation.z, -0.35 * lean_scale, delta * 10.0)
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.16, delta * 8.0)
		"kinetic_flare":
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.18 * lean_scale, delta * 9.0)
			if _accent_fx:
				_accent_fx.scale = Vector3.ONE * (1.25 + 0.15 * sin(_emotion_t * 12.0))
		_: # forward_lean / boost
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.28 * lean_scale, delta * 8.0)


func _apply_pose_overlay(delta: float) -> void:
	# Distinct branches — styles no longer collapse into one shared pose.
	match _pose_state:
		"lace_check":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, 0.45, delta * 6.0)
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 1.1, delta * 6.0)
			if _leg_l:
				_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.5, delta * 6.0)
		"coiled":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, 0.55, delta * 8.0)
			if _leg_l:
				_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.7, delta * 8.0)
			if _leg_r:
				_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.35, delta * 8.0)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.8, delta * 8.0)
		"scan":
			if _head:
				_head.rotation.y = sin(_emotion_t * 3.0) * 0.55
			if _arm_l:
				_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.5, delta * 5.0)
		"breathe":
			if _torso:
				_torso.position.y = _rest_torso_y + sin(_emotion_t * 2.5) * 0.04
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.2, delta * 3.0)
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.2, delta * 3.0)
		"stamp":
			if _leg_r:
				_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.55, delta * 10.0)
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, 0.2, delta * 6.0)
		"showboat":
			if _arm_l:
				_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 1.2, delta * 6.0)
			if _arm_r:
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -1.2, delta * 6.0)
			if _torso:
				_torso.rotation.y = sin(_emotion_t * 4.0) * 0.25
		"visualize":
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.4, delta * 5.0)
			if _head:
				_head.rotation.x = lerpf(_head.rotation.x, -0.15, delta * 4.0)
		"charge":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, 0.35, delta * 9.0)
			if _arm_l and _arm_r:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -1.2, delta * 9.0)
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.2, delta * 9.0)
		"stutter":
			if _torso:
				_torso.rotation.z = sin(_emotion_t * 22.0) * 0.2
			if _leg_l:
				_leg_l.rotation.x = sin(_emotion_t * 18.0) * 0.35
		"catch":
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.6, delta * 10.0)
			if _arm_r:
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.8, delta * 10.0)
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, 0.15, delta * 8.0)
		"roll":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, 1.2, delta * 8.0)
			if _head:
				_head.rotation.x = lerpf(_head.rotation.x, 0.6, delta * 8.0)
		"soft":
			if _torso:
				_torso.rotation.z = sin(_emotion_t * 8.0) * 0.08
			if _head:
				_head.rotation.x = lerpf(_head.rotation.x, -0.1, delta * 4.0)
		"rock":
			if _torso:
				_torso.rotation.z = sin(_emotion_t * 6.0) * 0.3
		"comic_spin":
			if _torso:
				_torso.rotation.y += delta * 10.0
			if _arm_l:
				_arm_l.rotation.z = sin(_emotion_t * 12.0) * 0.8
		"foot_box":
			if _leg_l:
				_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.9, delta * 8.0)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.8, delta * 8.0)
		"stutter_lock":
			if _torso:
				_torso.rotation.z = sin(_emotion_t * 28.0) * 0.12
			if _accent_fx:
				_accent_fx.scale = Vector3.ONE * 0.7
		"jog":
			if _leg_l:
				_leg_l.rotation.x = sin(_emotion_t * 8.0) * 0.35
			if _leg_r:
				_leg_r.rotation.x = -sin(_emotion_t * 8.0) * 0.35
		"reaccel":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, -0.25, delta * 10.0)
			if _arm_l:
				_arm_l.rotation.x = -sin(_emotion_t * 14.0) * 0.8
			if _arm_r:
				_arm_r.rotation.x = sin(_emotion_t * 14.0) * 0.8
		"flip_up":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, -0.8, delta * 9.0)
			if _arm_l:
				_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 1.0, delta * 9.0)
		"tempo":
			if _torso:
				_torso.position.y = _rest_torso_y + sin(_emotion_t * 5.0) * 0.03
			if _leg_l:
				_leg_l.rotation.x = sin(_emotion_t * 5.0) * 0.25
			if _leg_r:
				_leg_r.rotation.x = -sin(_emotion_t * 5.0) * 0.25
		"drive":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, -0.2, delta * 7.0)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -1.0, delta * 7.0)
		"laugh_jog":
			if _torso:
				_torso.rotation.z = sin(_emotion_t * 9.0) * 0.15
			if _head:
				_head.rotation.x = sin(_emotion_t * 10.0) * 0.12
			if _leg_l:
				_leg_l.rotation.x = sin(_emotion_t * 9.0) * 0.3
		"line_rejoin":
			if _torso:
				_torso.rotation.z = lerpf(_torso.rotation.z, -0.2, delta * 8.0)
			if _leg_r:
				_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.4, delta * 8.0)
		"assisted":
			if _backpack:
				_backpack.scale = Vector3.ONE * (1.0 + 0.1 * sin(_emotion_t * 8.0))
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, -0.12, delta * 6.0)
		"arms_up":
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.2, delta * 5.0)
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.2, delta * 5.0)
		"spike_cheer":
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.5, delta * 8.0)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.4, delta * 5.0)
			if _leg_r:
				_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.4, delta * 5.0)
		"open_arms":
			if _arm_l:
				_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 1.4, delta * 5.0)
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.3, delta * 5.0)
			if _arm_r:
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -1.4, delta * 5.0)
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -0.3, delta * 5.0)
		"fist_chest":
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.1, delta * 6.0)
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.6, delta * 6.0)
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, -0.1, delta * 5.0)
		"dance":
			if _torso:
				_torso.rotation.y = sin(_emotion_t * 8.0) * 0.4
				_torso.rotation.z = cos(_emotion_t * 6.0) * 0.2
			if _arm_l:
				_arm_l.rotation.x = -1.5 + sin(_emotion_t * 8.0) * 0.5
			if _arm_r:
				_arm_r.rotation.x = -1.5 - sin(_emotion_t * 8.0) * 0.5
		"salute":
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.0, delta * 6.0)
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.35, delta * 6.0)
			if _head:
				_head.rotation.x = lerpf(_head.rotation.x, 0.1, delta * 4.0)
		"ring_expand":
			if _accent_fx:
				_accent_fx.scale = Vector3.ONE * (1.4 + 0.3 * sin(_emotion_t * 6.0))
			if _arm_l:
				_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.9, delta * 5.0)
			if _arm_r:
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.9, delta * 5.0)
		"backflip_flash":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, -2.8, delta * 4.0)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.0, delta * 5.0)
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.0, delta * 5.0)
		"defeat":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, 0.4, delta * 4.0)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.6, delta * 4.0)
			if _head:
				_head.rotation.x = lerpf(_head.rotation.x, 0.25, delta * 4.0)
		_:
			if _is_boost_style(_pose_state):
				_apply_boost_style(delta, profile.lean_scale if profile else 1.0)
