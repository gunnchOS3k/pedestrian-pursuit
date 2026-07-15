extends Node3D

## Personality-driven procedural runners — stylized bodies with faces and rear identity.
## Uses RunnerProfile motion fields (cadence/stride/bounce/lean/arm/head_bob)
## and distinct pose overlay branches for start/boost/stumble/recovery/finish.
## Limbs are Node3D joint pivots; meshes hang along the limb axis.

const RunnerProfileScript = preload("res://scripts/data/RunnerProfile.gd")

@export var body_color: Color = Color(1.0, 0.82, 0.35, 1.0)
@export var accent_color: Color = Color(1.0, 0.35, 0.2, 1.0)
@export var is_ai: bool = false
@export var runner_id: String = "dash_reed"

var profile: RunnerProfile
var _torso: MeshInstance3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
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

	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.92, 0.72, 0.58).lerp(body_color.lightened(0.35), 0.25)
	skin.roughness = 0.65
	var shirt := StandardMaterial3D.new()
	shirt.albedo_color = body_color
	shirt.roughness = 0.55
	var pants := StandardMaterial3D.new()
	pants.albedo_color = accent_color.darkened(0.25)
	pants.roughness = 0.6
	var accent := StandardMaterial3D.new()
	accent.albedo_color = accent_color
	accent.roughness = 0.4
	accent.emission_enabled = arch in ["kinetic", "sprinter", "trick"]
	if accent.emission_enabled:
		accent.emission = accent_color
		accent.emission_energy_multiplier = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = accent_color.darkened(0.4)
	dark.roughness = 0.55
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = body_color.darkened(0.45).lerp(accent_color.darkened(0.2), 0.35)
	hair_mat.roughness = 0.7
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.08, 0.08, 0.1)
	eye_mat.roughness = 0.3
	var mouth_mat := StandardMaterial3D.new()
	mouth_mat.albedo_color = Color(0.55, 0.28, 0.28)
	mouth_mat.roughness = 0.55

	# Archetype proportions (profile scales still apply).
	var torso_r := 0.17 * ws
	var torso_h := 0.52 * hs
	var head_r := 0.15 * hs
	var arm_len := 0.42 * hs
	var arm_r := 0.045 * ws
	var leg_len := 0.5 * ls
	var leg_r := 0.058 * ws
	var hip_spread := 0.12 * ws
	var shoulder_spread := 0.22 * ws
	var shoe_scale := 1.0
	var shorts := false

	match arch:
		"sprinter":
			torso_r = 0.2 * ws
			torso_h = 0.44 * hs
			head_r = 0.14 * hs
			arm_len = 0.4 * hs
			leg_len = 0.46 * ls
			leg_r = 0.07 * ws
			shoe_scale = 1.1
			shorts = true
		"parkour":
			torso_r = 0.14 * ws
			torso_h = 0.55 * hs
			head_r = 0.145 * hs
			arm_len = 0.5 * hs
			arm_r = 0.04 * ws
			leg_len = 0.55 * ls
			leg_r = 0.05 * ws
			hip_spread = 0.1 * ws
		"endurance":
			torso_r = 0.15 * ws
			torso_h = 0.58 * hs
			head_r = 0.155 * hs
			arm_len = 0.4 * hs
			leg_len = 0.58 * ls
			leg_r = 0.05 * ws
			shorts = true
		"uphill":
			torso_r = 0.24 * ws
			torso_h = 0.5 * hs
			head_r = 0.17 * hs
			arm_len = 0.4 * hs
			arm_r = 0.06 * ws
			leg_len = 0.46 * ls
			leg_r = 0.075 * ws
			hip_spread = 0.16 * ws
			shoulder_spread = 0.28 * ws
			shoe_scale = 1.25
		"trick":
			torso_r = 0.16 * ws
			torso_h = 0.48 * hs
			head_r = 0.155 * hs
			arm_len = 0.44 * hs
			leg_len = 0.5 * ls
			shorts = true
		"cornering":
			torso_r = 0.14 * ws
			torso_h = 0.54 * hs
			head_r = 0.14 * hs
			arm_len = 0.4 * hs
			leg_len = 0.52 * ls
			leg_r = 0.05 * ws
			hip_spread = 0.11 * ws
			shoulder_spread = 0.2 * ws
		"kinetic":
			torso_r = 0.17 * ws
			torso_h = 0.52 * hs
			head_r = 0.155 * hs
			arm_len = 0.42 * hs
			leg_len = 0.5 * ls
		_: # all_terrain
			pass

	var hip_y := leg_len + 0.06
	var torso_y := hip_y + torso_h * 0.42
	var shoulder_y := torso_y + torso_h * 0.28
	var neck_y := torso_y + torso_h * 0.45 + head_r * 0.15

	# Capsule torso (shirt read).
	_torso = _mesh_capsule(torso_r, torso_h, Vector3(0, torso_y, 0), shirt)
	add_child(_torso)
	_rest_torso_y = torso_y

	# Jacket / shirt overlay (secondary mesh hanging slightly back / on chest).
	match arch:
		"sprinter", "uphill", "all_terrain", "cornering":
			_jacket = _mesh_capsule(torso_r * 1.08, torso_h * 0.72, Vector3(0, torso_h * 0.05, -0.02), dark)
			_torso.add_child(_jacket)
			# Jacket tails readable from rear.
			var tail_l := _mesh_box(Vector3(0.08 * ws, 0.22 * hs, 0.04), Vector3(-0.06 * ws, -torso_h * 0.32, -torso_r * 0.85), dark)
			var tail_r := _mesh_box(Vector3(0.08 * ws, 0.22 * hs, 0.04), Vector3(0.06 * ws, -torso_h * 0.32, -torso_r * 0.85), dark)
			_torso.add_child(tail_l)
			_torso.add_child(tail_r)
		"endurance":
			_jacket = _mesh_capsule(torso_r * 1.05, torso_h * 0.55, Vector3(0, torso_h * 0.08, -0.015), accent)
			_torso.add_child(_jacket)
		"kinetic":
			_jacket = _mesh_capsule(torso_r * 1.1, torso_h * 0.65, Vector3(0, torso_h * 0.05, -0.02), dark)
			_torso.add_child(_jacket)
		_:
			# light shirt collar band
			_jacket = _mesh_cylinder(torso_r * 1.02, 0.06 * hs, Vector3(0, torso_h * 0.32, 0), shirt)
			_torso.add_child(_jacket)

	# Pants band / shorts lower torso cue.
	var pants_h := (0.22 if shorts else 0.32) * hs
	var pants_mesh := _mesh_capsule(torso_r * 1.02, pants_h, Vector3.ZERO, pants)
	_torso.add_child(pants_mesh)
	pants_mesh.position = Vector3(0, -torso_h * 0.28, 0)

	# Head pivot at neck + sphere skull + face.
	_head = _make_pivot(self, Vector3(0, neck_y, 0.01))
	_rest_head_y = neck_y
	var skull := _mesh_sphere(head_r, Vector3(0, head_r * 0.85, 0), skin)
	_head.add_child(skull)
	skull.position = Vector3(0, head_r * 0.85, 0)
	_add_face(_head, head_r, eye_mat, mouth_mat)

	# Hair / headwear per archetype (parented to head).
	_add_hair_for_archetype(arch, head_r, hair_mat, accent, dark, hs)

	# Arms — shoulder pivots, cylinders hang down, hands at ends.
	_arm_l = _make_limb(self, Vector3(-shoulder_spread, shoulder_y, 0), arm_len, arm_r, skin, true)
	_arm_r = _make_limb(self, Vector3(shoulder_spread, shoulder_y, 0), arm_len, arm_r, skin, true)

	# Legs — hip pivots, cylinders hang down, shoes with toe + heel.
	_leg_l = _make_limb(self, Vector3(-hip_spread, hip_y, 0), leg_len, leg_r, pants, false)
	_leg_r = _make_limb(self, Vector3(hip_spread, hip_y, 0), leg_len, leg_r, pants, false)
	_attach_shoes(_leg_l, true, leg_len, ws, shoe_scale, accent, dark)
	_attach_shoes(_leg_r, false, leg_len, ws, shoe_scale, accent, dark)

	# Rear-readable identity extras.
	_add_rear_identity(arch, torso_r, torso_h, hs, ws, accent, dark, hair_mat)

	_name_label = Label3D.new()
	_name_label.text = profile.display_name if profile else "Runner"
	_name_label.font_size = 28
	_name_label.modulate = Color(1, 1, 1, 0.9)
	_name_label.position = Vector3(0, neck_y + head_r * 2.4, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.outline_modulate = Color(0, 0, 0, 0.8)
	_name_label.outline_size = 4
	add_child(_name_label)


func _add_face(head: Node3D, head_r: float, eye_mat: Material, mouth_mat: Material) -> void:
	var eye_y := head_r * 0.95
	var eye_z := head_r * 0.78
	var eye_x := head_r * 0.38
	var eye_r := head_r * 0.12
	var eye_l := _mesh_sphere(eye_r, Vector3(-eye_x, eye_y, eye_z), eye_mat)
	var eye_r_mi := _mesh_sphere(eye_r, Vector3(eye_x, eye_y, eye_z), eye_mat)
	head.add_child(eye_l)
	head.add_child(eye_r_mi)
	eye_l.position = Vector3(-eye_x, eye_y, eye_z)
	eye_r_mi.position = Vector3(eye_x, eye_y, eye_z)
	var mouth := _mesh_box(Vector3(head_r * 0.28, head_r * 0.06, head_r * 0.08), Vector3.ZERO, mouth_mat)
	head.add_child(mouth)
	mouth.position = Vector3(0, head_r * 0.55, head_r * 0.82)


func _add_hair_for_archetype(
	arch: String, head_r: float, hair_mat: Material, accent: Material, dark: Material, _hs: float
) -> void:
	match arch:
		"sprinter":
			_hair = _mesh_box(Vector3(head_r * 1.5, head_r * 0.35, head_r * 1.2), Vector3.ZERO, dark)
			_head.add_child(_hair)
			_hair.position = Vector3(0, head_r * 1.55, -head_r * 0.1)
		"parkour":
			# Ponytail hanging back — rear-readable.
			_hair = _mesh_sphere(head_r * 0.55, Vector3.ZERO, hair_mat)
			_head.add_child(_hair)
			_hair.position = Vector3(0.04, head_r * 1.5, -0.02)
			var pony := _mesh_capsule(head_r * 0.18, head_r * 1.4, Vector3.ZERO, hair_mat)
			_head.add_child(pony)
			pony.position = Vector3(0.02, head_r * 0.9, -head_r * 1.1)
			pony.rotation.x = 0.55
		"endurance":
			_hair = _mesh_sphere(head_r * 0.7, Vector3.ZERO, hair_mat)
			_head.add_child(_hair)
			_hair.position = Vector3(0, head_r * 1.55, -head_r * 0.15)
		"uphill":
			_hair = _mesh_box(Vector3(head_r * 1.2, head_r * 0.25, head_r * 1.0), Vector3.ZERO, dark)
			_head.add_child(_hair)
			_hair.position = Vector3(0, head_r * 1.6, -0.02)
		"trick":
			_hair = _mesh_box(Vector3(head_r * 1.4, head_r * 0.55, head_r * 1.1), Vector3.ZERO, accent)
			_head.add_child(_hair)
			_hair.position = Vector3(-0.06, head_r * 1.45, 0.02)
		"cornering":
			_hair = _mesh_box(Vector3(head_r * 1.1, head_r * 0.3, head_r * 1.15), Vector3.ZERO, dark)
			_head.add_child(_hair)
			_hair.position = Vector3(0.02, head_r * 1.55, -head_r * 0.08)
		"kinetic":
			# High collar / head band.
			_hair = _mesh_cylinder(head_r * 0.95, head_r * 0.28, Vector3.ZERO, dark)
			_head.add_child(_hair)
			_hair.position = Vector3(0, head_r * 1.15, 0)
		_:
			_hair = _mesh_sphere(head_r * 0.55, Vector3.ZERO, hair_mat)
			_head.add_child(_hair)
			_hair.position = Vector3(0, head_r * 1.55, -head_r * 0.12)


func _add_rear_identity(
	arch: String, torso_r: float, torso_h: float, hs: float, ws: float,
	accent: Material, dark: Material, _hair_mat: Material
) -> void:
	match arch:
		"parkour":
			_backpack = _mesh_box(Vector3(0.28 * ws, 0.32 * hs, 0.16), Vector3.ZERO, dark)
			_torso.add_child(_backpack)
			_backpack.position = Vector3(0, 0.02, -torso_r - 0.1)
			_scarf = _mesh_capsule(0.04, 0.4 * hs, Vector3.ZERO, accent)
			_torso.add_child(_scarf)
			_scarf.position = Vector3(0.12 * ws, torso_h * 0.15, -torso_r * 0.7)
			_scarf.rotation.x = 0.4
		"trick":
			_scarf = _mesh_capsule(0.05, 0.48 * hs, Vector3.ZERO, accent)
			_torso.add_child(_scarf)
			_scarf.position = Vector3(-0.14 * ws, torso_h * 0.1, -torso_r * 0.75)
			_scarf.rotation.x = 0.5
			_scarf.rotation.z = 0.2
		"cornering":
			_scarf = _mesh_box(Vector3(0.06, 0.12 * hs, 0.32 * hs), Vector3.ZERO, accent)
			_torso.add_child(_scarf)
			_scarf.position = Vector3(0, torso_h * 0.2, -torso_r - 0.12)
		"kinetic":
			_backpack = _mesh_box(Vector3(0.3 * ws, 0.26 * hs, 0.14), Vector3.ZERO, dark)
			_torso.add_child(_backpack)
			_backpack.position = Vector3(0, 0.05, -torso_r - 0.1)
			# Energy ring readable from rear/side.
			_accent_fx = _mesh_torus(0.1 * hs, 0.22 * hs, Vector3.ZERO, accent)
			_torso.add_child(_accent_fx)
			_accent_fx.position = Vector3(0, torso_h * 0.15, -torso_r - 0.18)
			_accent_fx.rotation.x = PI * 0.5
		"sprinter":
			# Already has jacket tails; add small rear stripe.
			_accent_fx = _mesh_box(Vector3(0.1 * ws, 0.28 * hs, 0.03), Vector3.ZERO, accent)
			_torso.add_child(_accent_fx)
			_accent_fx.position = Vector3(0, 0.0, -torso_r - 0.04)
		"endurance":
			_scarf = _mesh_cylinder(0.08 * ws, 0.05 * hs, Vector3.ZERO, accent)
			_torso.add_child(_scarf)
			_scarf.position = Vector3(0, torso_h * 0.38, 0)
		"uphill":
			_backpack = _mesh_box(Vector3(0.36 * ws, 0.28 * hs, 0.14), Vector3.ZERO, dark)
			_torso.add_child(_backpack)
			_backpack.position = Vector3(0, 0.0, -torso_r - 0.12)
		_:
			# Soft rear jacket flap cue.
			_scarf = _mesh_box(Vector3(0.2 * ws, 0.14 * hs, 0.05), Vector3.ZERO, dark)
			_torso.add_child(_scarf)
			_scarf.position = Vector3(0, -torso_h * 0.15, -torso_r - 0.05)


func _make_limb(
	parent: Node3D, pivot_pos: Vector3, length: float, radius: float, mat: Material, is_arm: bool
) -> Node3D:
	var pivot := _make_pivot(parent, pivot_pos)
	var limb := _mesh_cylinder(radius, length, Vector3.ZERO, mat)
	pivot.add_child(limb)
	# Mesh centered; shift down so pivot sits at shoulder/hip.
	limb.position = Vector3(0, -length * 0.5, 0)
	if is_arm:
		var hand := _mesh_sphere(radius * 1.35, Vector3.ZERO, mat)
		pivot.add_child(hand)
		hand.position = Vector3(0, -length, 0)
	return pivot


func _attach_shoes(
	leg: Node3D, is_left: bool, leg_len: float, ws: float, shoe_scale: float,
	accent: Material, dark: Material
) -> void:
	var side := -1.0 if is_left else 1.0
	# Toe / sole body (forward +Z).
	var sole := _mesh_box(
		Vector3(0.14 * ws * shoe_scale, 0.07 * shoe_scale, 0.28 * shoe_scale),
		Vector3.ZERO,
		accent
	)
	leg.add_child(sole)
	sole.position = Vector3(0, -leg_len - 0.02, 0.06 * shoe_scale)
	# Rounded toe nub.
	var toe := _mesh_sphere(0.055 * shoe_scale * ws / 0.55, Vector3.ZERO, accent)
	leg.add_child(toe)
	toe.position = Vector3(0, -leg_len - 0.01, 0.18 * shoe_scale)
	toe.scale = Vector3(1.1, 0.7, 1.2)
	# Heel block (rear).
	var heel := _mesh_box(
		Vector3(0.12 * ws * shoe_scale, 0.08 * shoe_scale, 0.1 * shoe_scale),
		Vector3.ZERO,
		dark
	)
	leg.add_child(heel)
	heel.position = Vector3(0, -leg_len - 0.015, -0.1 * shoe_scale)
	if is_left:
		_shoe_l = sole
		_heel_l = heel
	else:
		_shoe_r = sole
		_heel_r = heel
	# Quiet unused warning for side symmetry quirks.
	sole.position.x = side * 0.0


func _make_pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mesh_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	return mi


func _mesh_sphere(radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	return mi


func _mesh_capsule(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0 + 0.01)
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	return mi


func _mesh_cylinder(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = maxf(height, 0.02)
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	return mi


func _mesh_torus(inner: float, outer: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
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
