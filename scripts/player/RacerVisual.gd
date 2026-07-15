extends Node3D

## Personality-driven procedural runners — readable silhouettes and gait identities.
## Replaces capsule mannequins; keeps mobile-friendly geometry.

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
var _accent_fx: MeshInstance3D
var _name_label: Label3D
var _phase: float = 0.0
var _parent_body: CharacterBody3D
var _emotion_t: float = 0.0
var _pose_state: String = "idle"
var _pose_timer: float = 0.0
var _boosting: bool = false


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


func set_pose_state(state: String, duration: float = 0.45) -> void:
	_pose_state = state
	_pose_timer = duration


func set_boosting(active: bool) -> void:
	_boosting = active
	if active:
		set_pose_state("boost", 0.25)


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


func _clear_figure() -> void:
	for child in get_children():
		child.queue_free()
	_torso = null
	_head = null
	_leg_l = null
	_leg_r = null
	_arm_l = null
	_arm_r = null
	_hair = null
	_shoe_l = null
	_shoe_r = null
	_accent_fx = null
	_name_label = null


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
	_accent_fx = null
	_name_label = null
	_build_figure()


func _build_figure() -> void:
	var hs := profile.height_scale if profile else 1.0
	var ws := profile.width_scale if profile else 1.0
	var ls := profile.leg_scale if profile else 1.0

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.roughness = 0.55
	var accent := StandardMaterial3D.new()
	accent.albedo_color = accent_color
	accent.roughness = 0.4
	accent.emission_enabled = profile != null and profile.archetype in ["kinetic", "sprinter", "trick"]
	if accent.emission_enabled:
		accent.emission = accent_color
		accent.emission_energy_multiplier = 0.35

	_torso = _mesh_box(Vector3(0.55 * ws, 0.7 * hs, 0.35 * ws), Vector3(0, 1.05 * hs, 0), body_mat)
	_head = _mesh_sphere(0.22 * hs, Vector3(0, 1.55 * hs, 0), body_mat)
	_leg_l = _mesh_box(Vector3(0.18 * ws, 0.55 * ls, 0.22), Vector3(-0.14 * ws, 0.4 * ls, 0), accent)
	_leg_r = _mesh_box(Vector3(0.18 * ws, 0.55 * ls, 0.22), Vector3(0.14 * ws, 0.4 * ls, 0), accent)
	_arm_l = _mesh_box(Vector3(0.14 * ws, 0.5 * hs, 0.14), Vector3(-0.4 * ws, 1.05 * hs, 0), body_mat)
	_arm_r = _mesh_box(Vector3(0.14 * ws, 0.5 * hs, 0.14), Vector3(0.4 * ws, 1.05 * hs, 0), body_mat)
	_shoe_l = _mesh_box(Vector3(0.3 * ws, 0.12, 0.46), Vector3(-0.14 * ws, 0.08, 0.08), accent)
	_shoe_r = _mesh_box(Vector3(0.3 * ws, 0.12, 0.46), Vector3(0.14 * ws, 0.08, 0.08), accent)

	# Archetype silhouette accents (secondary motion proxies)
	match profile.archetype if profile else "all_terrain":
		"sprinter":
			_hair = _mesh_box(Vector3(0.2, 0.18, 0.12), Vector3(0, 1.72 * hs, -0.05), accent)
		"parkour":
			_hair = _mesh_box(Vector3(0.16, 0.28, 0.1), Vector3(0.05, 1.7 * hs, 0), accent)
		"endurance":
			_hair = _mesh_sphere(0.12 * hs, Vector3(0, 1.72 * hs, -0.02), body_mat)
		"uphill":
			_accent_fx = _mesh_box(Vector3(0.7 * ws, 0.2, 0.2), Vector3(0, 1.25 * hs, -0.12), accent)
		"trick":
			_hair = _mesh_box(Vector3(0.22, 0.14, 0.18), Vector3(-0.08, 1.68 * hs, 0.02), accent)
		"cornering":
			_accent_fx = _mesh_box(Vector3(0.12, 0.35 * hs, 0.08), Vector3(0.28 * ws, 1.15 * hs, 0), accent)
		"kinetic":
			_accent_fx = _mesh_sphere(0.1, Vector3(0, 1.35 * hs, 0.22), accent)
		_:
			_hair = _mesh_box(Vector3(0.18, 0.12, 0.14), Vector3(0, 1.7 * hs, 0), body_mat)

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
	if _parent_body == null:
		return
	_emotion_t += delta
	if _pose_timer > 0.0:
		_pose_timer -= delta
		_apply_pose_overlay(delta)
		if _pose_timer <= 0.0 and _pose_state != "idle":
			_pose_state = "idle"

	var speed := _parent_body.velocity.length()
	var grounded := _parent_body.is_on_floor() if _parent_body.has_method("is_on_floor") else true
	var cadence_scale := profile.cadence_scale if profile else 1.0
	var stride_scale := profile.stride_scale if profile else 1.0
	var bounce_scale := profile.bounce_scale if profile else 1.0
	var lean_scale := profile.lean_scale if profile else 1.0
	var arm_scale := profile.arm_scale if profile else 1.0
	var head_bob := profile.head_bob if profile else 1.0

	var cadence := clampf(speed * 0.35 * cadence_scale, 0.0, 16.0)
	if grounded and cadence > 0.35 and _pose_state in ["idle", "boost"]:
		_phase += delta * cadence
	elif _pose_state == "idle":
		# Distinct idle personality when standing
		_phase += delta * (1.2 + bounce_scale)
	else:
		_phase = lerpf(_phase, 0.0, delta * 3.0)

	var swing := sin(_phase) * minf(0.62, cadence * 0.05 + 0.08) * stride_scale
	if _boosting:
		swing *= 1.15
		if _torso:
			_torso.rotation.x = lerpf(_torso.rotation.x, -0.18 * lean_scale, delta * 8.0)
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
		_torso.position.y = (1.05 * (profile.height_scale if profile else 1.0)) + sin(_phase * 2.0) * 0.02 * bounce_scale
	if _head:
		_head.position.y = (1.55 * (profile.height_scale if profile else 1.0)) + sin(_phase * 2.0) * 0.015 * head_bob
		_head.rotation.y = sin(_emotion_t * 0.7) * 0.08
	if _hair:
		_hair.rotation.z = sin(_phase * 1.5) * 0.12
	if _accent_fx and profile and profile.archetype == "kinetic":
		_accent_fx.rotate_y(delta * 3.0)
		_accent_fx.scale = Vector3.ONE * (1.0 + 0.08 * sin(_emotion_t * 6.0))


func _apply_pose_overlay(delta: float) -> void:
	# Short-lived readable poses for start/stumble/finish without AnimationPlayer.
	var t := 1.0 - clampf(_pose_timer, 0.0, 1.0)
	match _pose_state:
		"coiled", "charge", "lace_check", "breathe", "stamp", "scan", "showboat", "visualize":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, 0.25, delta * 6.0)
			if _leg_l:
				_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.35, delta * 6.0)
			if _leg_r:
				_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.15, delta * 6.0)
		"stutter", "soft", "catch", "rock", "foot_box", "stutter_lock", "comic_spin", "roll":
			if _torso:
				_torso.rotation.z = sin(_emotion_t * 18.0) * 0.25
			if _head:
				_head.rotation.x = -0.2
		"arms_up", "spike_cheer", "open_arms", "fist_chest", "dance", "salute", "ring_expand", "backflip_flash":
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.2, delta * 5.0)
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.2, delta * 5.0)
		"defeat":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, 0.35, delta * 4.0)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.6, delta * 4.0)
		_:
			pass
	# Suppress unused warning for t when overlay is short
	if t < 0.0:
		pass
