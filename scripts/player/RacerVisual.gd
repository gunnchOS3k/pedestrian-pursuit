extends Node3D

## Personality-driven procedural runners — stylized bodies with faces and rear identity.
## Uses RunnerProfile motion fields (cadence/stride/bounce/lean/arm/head_bob)
## and distinct pose overlay branches for start/boost/stumble/recovery/finish.
## Limbs are Node3D joint pivots; meshes hang along the limb axis.

const RunnerProfileScript = preload("res://scripts/data/RunnerProfile.gd")
const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")
const AvatarAppearanceScript = preload("res://scripts/data/AvatarAppearance.gd")
const WardrobeCatalogScript = preload("res://scripts/data/WardrobeCatalog.gd")

@export var body_color: Color = Color(1.0, 0.82, 0.35, 1.0)
@export var accent_color: Color = Color(1.0, 0.35, 0.2, 1.0)
@export var is_ai: bool = false
@export var runner_id: String = "dash_reed"
@export var vehicle_id: String = "reedline_circlers"

var profile: RunnerProfile
## Modular cosmetic layers (do not affect collision/stats). Procedural body remains fallback.
var avatar_appearance: Dictionary = {}
var wardrobe_outfit_slots: Dictionary = {}
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
var _speed_trail: GPUParticles3D
var _wardrobe_root: Node3D
var _phase: float = 0.0
var _parent_body: CharacterBody3D
var _emotion_t: float = 0.0
var _pose_state: String = "idle"
var _pose_timer: float = 0.0
var _boosting: bool = false
var _menu_preview: bool = false
var _rest_torso_y: float = 1.05
var _rest_head_y: float = 1.55
## 0 = full detail (solo/local preview), 1 = reduced wardrobe/VFX, 2 = silhouette-only budget for crowded fields.
var visual_lod: int = 0


func set_visual_lod(level: int) -> void:
	## Eight-racer visual budget hook — reduces particles/wardrobe density; does not claim 8p complete.
	var next := clampi(level, 0, 2)
	if visual_lod == next:
		return
	visual_lod = next
	if profile != null:
		_rebuild()


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


func apply_avatar_appearance(data: Dictionary, rebuild: bool = true) -> void:
	## Cosmetic modular avatar path. Keeps procedural figure as base mesh fallback.
	avatar_appearance = data.duplicate(true)
	if rebuild and profile != null:
		_rebuild()


func apply_wardrobe_outfit(slots: Dictionary, rebuild: bool = true) -> void:
	## Cosmetic wardrobe overlays. Footwear vehicle id still owns handling via set_vehicle_id.
	wardrobe_outfit_slots = slots.duplicate(true)
	var foot := str(slots.get("footwear_vehicle", ""))
	if not foot.is_empty():
		set_vehicle_id(foot, false)
	if rebuild and profile != null:
		_rebuild()


func set_vehicle_id(id: String, rebuild: bool = true) -> void:
	## Set footwear vehicle before/with profile so RaceScene only rebuilds once.
	if vehicle_id == id:
		return
	vehicle_id = id
	if rebuild and profile != null:
		_rebuild()


func _shoe_archetype() -> String:
	if not vehicle_id.is_empty():
		var arch := ShoeDataScript.movement_archetype(vehicle_id)
		if not arch.is_empty():
			return arch
	## Fallback: map runner archetype → street movement archetype.
	var runner_arch := profile.archetype if profile else "all_terrain"
	match runner_arch:
		"all_terrain":
			return "street_balanced"
		"sprinter":
			return "street_sprint"
		"parkour":
			return "street_parkour"
		"endurance":
			return "street_tempo"
		"uphill":
			return "street_power"
		"trick":
			return "street_trick"
		"cornering":
			return "street_rail"
		"kinetic":
			return "street_kinetic"
		_:
			return "street_balanced"


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
	if _speed_trail != null:
		_speed_trail.emitting = active
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
	_speed_trail = null
	_wardrobe_root = null
	_build_figure()
	_apply_modular_cosmetics()


func _build_figure() -> void:
	var hs := profile.height_scale if profile else 1.0
	var ws := profile.width_scale if profile else 1.0
	var ls := profile.leg_scale if profile else 1.0
	## Modular appearance may override presentation scales only (never collision shapes).
	if not avatar_appearance.is_empty():
		hs = clampf(float(avatar_appearance.get("height_scale", hs)), 0.85, 1.2)
		ws = clampf(float(avatar_appearance.get("width_scale", ws)), 0.85, 1.2)
		ls = clampf(float(avatar_appearance.get("leg_scale", ls)), 0.85, 1.2)
	var arch := profile.archetype if profile else "all_terrain"

	var skin := StandardMaterial3D.new()
	if not avatar_appearance.is_empty():
		skin.albedo_color = AvatarAppearanceScript.skin_color(
			str(avatar_appearance.get("skin_tone", "warm_medium")),
			str(avatar_appearance.get("undertone", "neutral"))
		)
	else:
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
	if not avatar_appearance.is_empty() and avatar_appearance.has("hair_color"):
		hair_mat.albedo_color = Color.html(str(avatar_appearance.get("hair_color", "#2A1A12")))
	else:
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

	# Hair / headwear — modular style overrides archetype fallback when present.
	if not avatar_appearance.is_empty() and str(avatar_appearance.get("hair_style", "")) != "":
		_add_modular_hair(str(avatar_appearance.get("hair_style", "short_fade")), head_r, hair_mat, dark, hs)
	else:
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
	## Footwear-forward speed trail — Kinetic Sole boost readability.
	_speed_trail = GPUParticles3D.new()
	_speed_trail.name = "KineticSoleTrail"
	_speed_trail.position = Vector3(0.0, 0.2, 0.35)
	_speed_trail.amount = 28
	_speed_trail.lifetime = 0.45
	_speed_trail.emitting = false
	var trail_mat := ParticleProcessMaterial.new()
	trail_mat.direction = Vector3(0.0, 0.2, 1.0)
	trail_mat.spread = 12.0
	trail_mat.initial_velocity_min = 1.5
	trail_mat.initial_velocity_max = 4.0
	trail_mat.gravity = Vector3(0.0, 0.4, 0.0)
	trail_mat.scale_min = 0.08
	trail_mat.scale_max = 0.22
	trail_mat.color = Color(1.0, 0.42, 0.24, 0.75) if arch == "all_terrain" else accent_color
	_speed_trail.process_material = trail_mat
	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.12
	trail_mesh.height = 0.24
	_speed_trail.draw_pass_1 = trail_mesh
	if visual_lod >= 2:
		_speed_trail.amount = 1
		_speed_trail.emitting = false
		_speed_trail.visible = false
	elif visual_lod == 1:
		_speed_trail.amount = mini(maxi(_speed_trail.amount, 1), 8)
	add_child(_speed_trail)


func _apply_modular_cosmetics() -> void:
	## Wardrobe overlays only. Never changes CharacterBody3D collision or MovementStats.
	if wardrobe_outfit_slots.is_empty() and avatar_appearance.is_empty():
		return
	if _torso == null or _head == null:
		return
	_wardrobe_root = Node3D.new()
	_wardrobe_root.name = "WardrobeRoot"
	add_child(_wardrobe_root)
	var hs := profile.height_scale if profile else 1.0
	var ws := profile.width_scale if profile else 1.0
	if not avatar_appearance.is_empty():
		hs = clampf(float(avatar_appearance.get("height_scale", hs)), 0.85, 1.2)
		ws = clampf(float(avatar_appearance.get("width_scale", ws)), 0.85, 1.2)
	## Face / covering cosmetics (independent of wardrobe slots).
	if not avatar_appearance.is_empty() and visual_lod < 2:
		_apply_face_cosmetics(hs, ws)
	if wardrobe_outfit_slots.is_empty():
		_apply_assistive_visual(hs, ws)
		return
	var slot_budget := 99
	if visual_lod == 1:
		slot_budget = 4
	elif visual_lod >= 2:
		slot_budget = 1
	var attached := 0
	for slot in wardrobe_outfit_slots.keys():
		if attached >= slot_budget:
			break
		var gid := str(wardrobe_outfit_slots.get(slot, ""))
		if gid.is_empty() or slot == "footwear_vehicle":
			continue
		var g := WardrobeCatalogScript.garment_by_id(gid)
		if g.is_empty():
			continue
		if str(g.get("art_status", "")) != "integrated_mesh_v1":
			continue ## art-pending catalog entries stay honest — no fake mesh claim
		_attach_garment_mesh(g, hs, ws)
		attached += 1
	_apply_assistive_visual(hs, ws)


func _apply_assistive_visual(hs: float, ws: float) -> void:
	if avatar_appearance.is_empty() or _wardrobe_root == null or visual_lod >= 2:
		return
	var assist := str(avatar_appearance.get("assistive", "none"))
	if assist == "none" or assist == "":
		return
	var brace_mat := StandardMaterial3D.new()
	brace_mat.albedo_color = Color(0.75, 0.78, 0.82)
	brace_mat.metallic = 0.55
	brace_mat.roughness = 0.35
	match assist:
		"forearm_sleeve_vis":
			var sleeve := _mesh_capsule(0.05 * ws, 0.2 * hs, Vector3.ZERO, brace_mat)
			_wardrobe_root.add_child(sleeve)
			sleeve.position = Vector3(0.24 * ws, _rest_torso_y + 0.05 * hs, 0.0)
		"running_blade_vis":
			var blade := _mesh_box(Vector3(0.06 * ws, 0.28 * hs, 0.04), Vector3.ZERO, brace_mat)
			_wardrobe_root.add_child(blade)
			blade.position = Vector3(0.12 * ws, _rest_torso_y - 0.45 * hs, 0.02)
		_:
			var brace := _mesh_box(Vector3(0.08 * ws, 0.22 * hs, 0.06), Vector3.ZERO, brace_mat)
			_wardrobe_root.add_child(brace)
			brace.position = Vector3(0.16 * ws, _rest_torso_y - 0.15 * hs, 0.02)


func _apply_face_cosmetics(hs: float, _ws: float) -> void:
	if _head == null:
		return
	var head_r := 0.15 * hs
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.18, 0.12, 0.1)
	dark.roughness = 0.55
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.75, 0.25, 0.35)
	accent.roughness = 0.4
	var mark := StandardMaterial3D.new()
	mark.albedo_color = Color(0.45, 0.28, 0.22)
	mark.roughness = 0.6
	var covering := str(avatar_appearance.get("head_covering", "none"))
	if covering != "none" and covering != "" and covering != "hijab_wrap":
		var cover_mat := StandardMaterial3D.new()
		cover_mat.albedo_color = Color(0.2, 0.22, 0.28) if covering in ["cap", "beanie", "durag"] else Color(0.85, 0.75, 0.35)
		cover_mat.roughness = 0.5
		var cover := _mesh_capsule(head_r * 1.05, head_r * 0.7, Vector3.ZERO, cover_mat)
		_head.add_child(cover)
		cover.position = Vector3(0, head_r * 1.35, -0.02)
	var facial := str(avatar_appearance.get("facial_hair", "none"))
	if facial != "none":
		match facial:
			"mustache":
				var m := _mesh_box(Vector3(head_r * 0.35, head_r * 0.05, head_r * 0.08), Vector3.ZERO, dark)
				_head.add_child(m)
				m.position = Vector3(0, head_r * 0.62, head_r * 0.85)
			"goatee":
				var g := _mesh_box(Vector3(head_r * 0.18, head_r * 0.16, head_r * 0.08), Vector3.ZERO, dark)
				_head.add_child(g)
				g.position = Vector3(0, head_r * 0.38, head_r * 0.8)
			"full_beard":
				var b := _mesh_capsule(head_r * 0.55, head_r * 0.7, Vector3.ZERO, dark)
				_head.add_child(b)
				b.position = Vector3(0, head_r * 0.35, head_r * 0.55)
			"stubble":
				var s := _mesh_box(Vector3(head_r * 0.55, head_r * 0.12, head_r * 0.12), Vector3.ZERO, dark)
				_head.add_child(s)
				s.position = Vector3(0, head_r * 0.5, head_r * 0.78)
	var makeup := str(avatar_appearance.get("makeup", "none"))
	if makeup == "bold_lip":
		var lip := _mesh_box(Vector3(head_r * 0.28, head_r * 0.07, head_r * 0.06), Vector3.ZERO, accent)
		_head.add_child(lip)
		lip.position = Vector3(0, head_r * 0.55, head_r * 0.86)
	elif makeup == "soft_liner":
		var liner := _mesh_box(Vector3(head_r * 0.55, head_r * 0.03, head_r * 0.04), Vector3.ZERO, dark)
		_head.add_child(liner)
		liner.position = Vector3(0, head_r * 1.05, head_r * 0.78)
	elif makeup == "race_stripe":
		var stripe := _mesh_box(Vector3(head_r * 0.08, head_r * 0.55, head_r * 0.05), Vector3.ZERO, accent)
		_head.add_child(stripe)
		stripe.position = Vector3(0, head_r * 0.95, head_r * 0.9)
	var scar := str(avatar_appearance.get("scar", "none"))
	if scar == "cheek_thin":
		var sc := _mesh_box(Vector3(head_r * 0.18, head_r * 0.03, head_r * 0.03), Vector3.ZERO, mark)
		_head.add_child(sc)
		sc.position = Vector3(head_r * 0.35, head_r * 0.75, head_r * 0.7)
	elif scar == "brow_nick":
		var bn := _mesh_box(Vector3(head_r * 0.12, head_r * 0.03, head_r * 0.03), Vector3.ZERO, mark)
		_head.add_child(bn)
		bn.position = Vector3(-head_r * 0.28, head_r * 1.12, head_r * 0.72)
	var birth := str(avatar_appearance.get("birthmark", "none"))
	if birth == "cheek_dot":
		var dot := _mesh_sphere(head_r * 0.05, Vector3.ZERO, mark)
		_head.add_child(dot)
		dot.position = Vector3(head_r * 0.4, head_r * 0.7, head_r * 0.72)
	elif birth == "temple_patch":
		var patch := _mesh_sphere(head_r * 0.08, Vector3.ZERO, mark)
		_head.add_child(patch)
		patch.position = Vector3(-head_r * 0.55, head_r * 1.05, head_r * 0.35)
	## Expression hooks — subtle mouth/eye offset by idle/start/victory selection.
	var expr := str(avatar_appearance.get("expression_idle", "neutral"))
	if _pose_state in ["arms_up", "finish"] or _pose_state.begins_with("victory"):
		expr = str(avatar_appearance.get("expression_victory", expr))
	elif _pose_state != "idle" and _pose_timer > 0.0:
		expr = str(avatar_appearance.get("expression_start", expr))
	set_meta("expression_hook", expr)


func _attach_garment_mesh(g: Dictionary, hs: float, ws: float) -> void:
	## Body-fit attachment: garments scale with presentation proportions only (no collision change).
	var colors: Dictionary = g.get("colors", {})
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.html(str(colors.get("primary", "#2EC4B6")))
	mat.roughness = 0.45
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color.html(str(colors.get("accent", "#FF6A3D")))
	accent.roughness = 0.4
	var recipe := str(g.get("mesh_recipe", ""))
	var mesh: MeshInstance3D = null
	match recipe:
		"fitted_undersuit":
			mesh = _mesh_capsule(0.175 * ws, 0.5 * hs, Vector3(0, _rest_torso_y, 0.01), mat)
		"cropped_shell":
			mesh = _mesh_capsule(0.19 * ws, 0.28 * hs, Vector3(0, _rest_torso_y + 0.08 * hs, -0.02), mat)
		"tapered_pants":
			mesh = _mesh_capsule(0.16 * ws, 0.34 * hs, Vector3(0, _rest_torso_y - 0.28 * hs, 0.0), mat)
		"wide_soft_pants":
			mesh = _mesh_capsule(0.19 * ws, 0.36 * hs, Vector3(0, _rest_torso_y - 0.3 * hs, 0.0), mat)
		"open_windshell":
			mesh = _mesh_capsule(0.21 * ws, 0.42 * hs, Vector3(0, _rest_torso_y + 0.02 * hs, -0.04), mat)
			var wing := _mesh_box(Vector3(0.08 * ws, 0.28 * hs, 0.04), Vector3.ZERO, accent)
			_wardrobe_root.add_child(wing)
			wing.position = Vector3(0.14 * ws, _rest_torso_y, -0.08)
		"relaxed_overshirt":
			mesh = _mesh_capsule(0.2 * ws, 0.36 * hs, Vector3(0, _rest_torso_y + 0.04 * hs, -0.01), mat)
		"open_drape":
			mesh = _mesh_capsule(0.23 * ws, 0.5 * hs, Vector3(0, _rest_torso_y - 0.02 * hs, -0.06), mat)
		"panel_jacket":
			mesh = _mesh_capsule(0.22 * ws, 0.4 * hs, Vector3(0, _rest_torso_y + 0.02 * hs, -0.03), mat)
			var stripe := _mesh_box(Vector3(0.06 * ws, 0.32 * hs, 0.03), Vector3.ZERO, accent)
			_wardrobe_root.add_child(stripe)
			stripe.position = Vector3(-0.12 * ws, _rest_torso_y, -0.1)
		"formal_lapel":
			mesh = _mesh_capsule(0.2 * ws, 0.32 * hs, Vector3(0, _rest_torso_y + 0.06 * hs, -0.02), mat)
			var lapel := _mesh_box(Vector3(0.1 * ws, 0.18 * hs, 0.03), Vector3.ZERO, accent)
			_wardrobe_root.add_child(lapel)
			lapel.position = Vector3(0.1 * ws, _rest_torso_y + 0.12 * hs, 0.06)
		"formal_coat":
			mesh = _mesh_capsule(0.24 * ws, 0.55 * hs, Vector3(0, _rest_torso_y - 0.05 * hs, -0.05), mat)
		"longline_robe":
			mesh = _mesh_capsule(0.22 * ws, 0.62 * hs, Vector3(0, _rest_torso_y - 0.08 * hs, -0.02), mat)
		"modest_wrap":
			mesh = _mesh_capsule(0.23 * ws, 0.48 * hs, Vector3(0, _rest_torso_y, -0.04), mat)
		"mantle_vest":
			mesh = _mesh_capsule(0.2 * ws, 0.3 * hs, Vector3(0, _rest_torso_y + 0.05 * hs, -0.02), mat)
			var pauldron := _mesh_box(Vector3(0.12 * ws, 0.08 * hs, 0.1), Vector3.ZERO, accent)
			_wardrobe_root.add_child(pauldron)
			pauldron.position = Vector3(0.18 * ws, _rest_torso_y + 0.18 * hs, 0.0)
		"short_capelet":
			mesh = _mesh_box(Vector3(0.36 * ws, 0.08 * hs, 0.28 * ws), Vector3.ZERO, mat)
			_wardrobe_root.add_child(mesh)
			mesh.position = Vector3(0, _rest_torso_y + 0.2 * hs, -0.08)
			return
		"hard_shell_panel":
			mesh = _mesh_box(Vector3(0.34 * ws, 0.28 * hs, 0.12), Vector3.ZERO, mat)
			_wardrobe_root.add_child(mesh)
			mesh.position = Vector3(0, _rest_torso_y + 0.05 * hs, 0.04)
			var glow := _mesh_box(Vector3(0.08 * ws, 0.2 * hs, 0.04), Vector3.ZERO, accent)
			_wardrobe_root.add_child(glow)
			glow.position = Vector3(0.12 * ws, _rest_torso_y + 0.05 * hs, 0.08)
			return
		"headband":
			mesh = _mesh_box(Vector3(0.28 * ws, 0.05 * hs, 0.22 * ws), Vector3.ZERO, mat)
			if _head != null:
				_head.add_child(mesh)
				mesh.position = Vector3(0, 0.22 * hs, 0.02)
				return
		"soft_headwrap":
			mesh = _mesh_capsule(0.17 * ws, 0.2 * hs, Vector3.ZERO, mat)
			if _head != null:
				_head.add_child(mesh)
				mesh.position = Vector3(0, 0.28 * hs, -0.02)
				return
		"hip_pack":
			mesh = _mesh_box(Vector3(0.16 * ws, 0.1 * hs, 0.08), Vector3.ZERO, mat)
			_wardrobe_root.add_child(mesh)
			mesh.position = Vector3(0.14 * ws, _rest_torso_y - 0.2 * hs, -0.06)
			return
		"cross_sling":
			mesh = _mesh_box(Vector3(0.12 * ws, 0.18 * hs, 0.06), Vector3.ZERO, mat)
			_wardrobe_root.add_child(mesh)
			mesh.position = Vector3(-0.14 * ws, _rest_torso_y - 0.05 * hs, -0.05)
			return
		"soft_scarf":
			mesh = _mesh_box(Vector3(0.22 * ws, 0.08 * hs, 0.12), Vector3.ZERO, mat)
			_wardrobe_root.add_child(mesh)
			mesh.position = Vector3(0, _rest_torso_y + 0.22 * hs, 0.06)
			return
		"crest_pin":
			mesh = _mesh_box(Vector3(0.05 * ws, 0.05 * hs, 0.03), Vector3.ZERO, accent)
			_wardrobe_root.add_child(mesh)
			mesh.position = Vector3(0.08 * ws, _rest_torso_y + 0.15 * hs, 0.1)
			return
		"race_visor":
			mesh = _mesh_box(Vector3(0.28 * ws, 0.05 * hs, 0.12), Vector3.ZERO, mat)
			if _head != null:
				_head.add_child(mesh)
				mesh.position = Vector3(0, 0.18 * hs, 0.14)
				var lens := _mesh_box(Vector3(0.22 * ws, 0.03 * hs, 0.02), Vector3.ZERO, accent)
				_head.add_child(lens)
				lens.position = Vector3(0, 0.18 * hs, 0.18)
				return
		"trail_ember", "trail_signal":
			if visual_lod >= 1:
				return
			var trail := GPUParticles3D.new()
			trail.amount = 10
			trail.lifetime = 0.35
			trail.emitting = true
			var pm := ParticleProcessMaterial.new()
			pm.direction = Vector3(0, 0.2, 1)
			pm.spread = 10.0
			pm.initial_velocity_min = 0.8
			pm.initial_velocity_max = 2.2
			pm.color = mat.albedo_color
			trail.process_material = pm
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			trail.draw_pass_1 = sm
			_wardrobe_root.add_child(trail)
			trail.position = Vector3(0, _rest_torso_y - 0.1 * hs, -0.15)
			return
		_:
			return
	if mesh != null:
		_wardrobe_root.add_child(mesh)


func cosmetic_fingerprint() -> String:
	## Peer-verifiable cosmetic identity (appearance + outfit + footwear).
	var AppearanceSyncScript = load("res://scripts/data/AppearanceSync.gd")
	return AppearanceSyncScript.fingerprint({
		"schema_version": 1,
		"racer_id": str(get_meta("created_racer_id")) if has_meta("created_racer_id") else "",
		"display_name": profile.display_name if profile else "",
		"appearance": avatar_appearance,
		"outfit_id": str(get_meta("outfit_id")) if has_meta("outfit_id") else "",
		"outfit_slots": wardrobe_outfit_slots,
		"footwear_vehicle_id": vehicle_id,
	})


func _add_modular_hair(style: String, head_r: float, hair_mat: Material, dark: Material, hs: float) -> void:
	## Protective styles and coverings — original procedural meshes only.
	match style:
		"locs_shoulder":
			_hair = _mesh_sphere(head_r * 0.55, Vector3(0, head_r * 1.4, -0.05), hair_mat)
			_head.add_child(_hair)
			for i in range(5):
				var loc := _mesh_capsule(head_r * 0.08, head_r * 1.5, Vector3.ZERO, hair_mat)
				_head.add_child(loc)
				loc.position = Vector3((-0.12 + float(i) * 0.06) * hs, head_r * 0.7, -head_r * 0.9)
				loc.rotation.x = 0.7
		"box_braids":
			_hair = _mesh_sphere(head_r * 0.65, Vector3(0, head_r * 1.45, -0.05), hair_mat)
			_head.add_child(_hair)
			for i in range(6):
				var braid := _mesh_capsule(head_r * 0.06, head_r * 1.7, Vector3.ZERO, hair_mat)
				_head.add_child(braid)
				braid.position = Vector3((-0.14 + float(i) * 0.055), head_r * 0.65, -head_r * 0.85)
				braid.rotation.x = 0.85
		"cornrows":
			_hair = _mesh_box(Vector3(head_r * 1.2, head_r * 0.12, head_r * 1.0), Vector3.ZERO, hair_mat)
			_head.add_child(_hair)
			_hair.position = Vector3(0, head_r * 1.4, -0.05)
			for i in range(4):
				var row := _mesh_box(Vector3(head_r * 0.08, head_r * 0.08, head_r * 1.1), Vector3.ZERO, hair_mat)
				_head.add_child(row)
				row.position = Vector3((-0.12 + float(i) * 0.08), head_r * 1.35, -head_r * 0.1)
		"twists":
			_hair = _mesh_sphere(head_r * 0.5, Vector3(0, head_r * 1.4, -0.04), hair_mat)
			_head.add_child(_hair)
			for i in range(4):
				var tw := _mesh_capsule(head_r * 0.07, head_r * 1.2, Vector3.ZERO, hair_mat)
				_head.add_child(tw)
				tw.position = Vector3((-0.1 + float(i) * 0.07), head_r * 0.8, -head_r * 0.8)
				tw.rotation.x = 0.6
		"protective_bun":
			_hair = _mesh_sphere(head_r * 0.7, Vector3(0, head_r * 1.7, -head_r * 0.2), hair_mat)
			_head.add_child(_hair)
		"afro_crown":
			_hair = _mesh_sphere(head_r * 1.15, Vector3(0, head_r * 1.35, -0.05), hair_mat)
			_head.add_child(_hair)
		"long_waves":
			_hair = _mesh_capsule(head_r * 0.55, head_r * 1.8, Vector3(0, head_r * 0.4, -head_r * 0.7), hair_mat)
			_head.add_child(_hair)
		"buzz", "bald":
			_hair = null
		"hijab_wrap", "durag":
			_hair = _mesh_capsule(head_r * 1.05, head_r * 1.1, Vector3(0, head_r * 0.9, -0.05), dark)
			_head.add_child(_hair)
		_:
			_hair = _mesh_box(Vector3(head_r * 1.3, head_r * 0.35, head_r * 1.1), Vector3.ZERO, hair_mat)
			_head.add_child(_hair)
			_hair.position = Vector3(0, head_r * 1.5, -0.05)


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
	var march := _shoe_archetype()
	## Street + Roller + Hover Couture — distinct silhouettes, shared mesh stack.
	## Hover/space reads are VFX only; race collision stays grounded.
	var balanced := march == "street_balanced"
	var sprint := march == "street_sprint"
	var parkour := march == "street_parkour"
	var tempo := march == "street_tempo"
	var power := march == "street_power"
	var trick := march == "street_trick"
	var rail := march == "street_rail"
	var kinetic := march == "street_kinetic"
	var roller_inline := march == "roller_inline"
	var roller_quad := march == "roller_quad"
	var roller_hover := march == "roller_hoverish"
	var hover_glide := march == "hover_glide"
	var hover_boost := march == "hover_boost"
	var hover_bounce := march == "hover_bounce"
	var hover_precision := march == "hover_precision"
	var elemental_wet := march == "elemental_wet"
	var elemental_dive := march == "elemental_dive"
	var elemental_sand := march == "elemental_sand"
	var elemental_magma := march == "elemental_magma"
	var elemental_frost := march == "elemental_frost"
	var elemental_mud := march == "elemental_mud"
	var ridiculous_boost := march == "ridiculous_boost"
	var ridiculous_stomp := march == "ridiculous_stomp"
	var ridiculous_reach := march == "ridiculous_reach"
	var ridiculous_caffeine := march == "ridiculous_caffeine"
	var ridiculous_drift := march == "ridiculous_drift"
	var ridiculous_trick := march == "ridiculous_trick"
	var crossover_soft := march == "crossover_soft"
	var crossover_heavy := march == "crossover_heavy"
	var crossover_tap := march == "crossover_tap"
	var crossover_bass := march == "crossover_bass"
	var crossover_circuit := march == "crossover_circuit"
	var crossover_portal := march == "crossover_portal"
	var crossover_gyro := march == "crossover_gyro"
	var tribute_ember := march == "tribute_ember"
	var tribute_bastion := march == "tribute_bastion"
	var tribute_volt := march == "tribute_volt"
	var tribute_gale := march == "tribute_gale"
	var tribute_azure := march == "tribute_azure"
	var tribute_orbit := march == "tribute_orbit"
	var tribute_echo := march == "tribute_echo"
	var tribute_null := march == "tribute_null"
	var tribute_radiant := march == "tribute_radiant"
	var native_street := balanced or sprint or parkour or tempo or power or trick or rail or kinetic
	var native_roller := roller_inline or roller_quad or roller_hover
	var native_hover := hover_glide or hover_boost or hover_bounce or hover_precision
	var native_elemental := (
		elemental_wet or elemental_dive or elemental_sand
		or elemental_magma or elemental_frost or elemental_mud
	)
	var native_ridiculous := (
		ridiculous_boost or ridiculous_stomp or ridiculous_reach
		or ridiculous_caffeine or ridiculous_drift or ridiculous_trick
	)
	var native_crossover := (
		crossover_soft or crossover_heavy or crossover_tap or crossover_bass
		or crossover_circuit or crossover_portal or crossover_gyro
	)
	var native_tribute := (
		tribute_ember or tribute_bastion or tribute_volt or tribute_gale or tribute_azure
		or tribute_orbit or tribute_echo or tribute_null or tribute_radiant
	)
	if tempo or rail or power or sprint or trick or kinetic or parkour or native_roller or native_hover or native_elemental or native_ridiculous or native_crossover or native_tribute:
		shoe_scale *= 1.14
	if power:
		shoe_scale *= 1.08 ## Blockier iron silhouette for forge ash.
	if sprint:
		shoe_scale *= 0.96 ## Low spike profile.
	if roller_quad:
		shoe_scale *= 1.06
	if roller_hover:
		shoe_scale *= 1.04
	if hover_bounce:
		shoe_scale *= 1.12
	if hover_boost:
		shoe_scale *= 1.05
	if elemental_mud:
		shoe_scale *= 1.12
	if elemental_magma:
		shoe_scale *= 1.08
	if elemental_frost:
		shoe_scale *= 1.05
	if ridiculous_stomp:
		shoe_scale *= 1.18
	if ridiculous_reach:
		shoe_scale *= 1.2
	if ridiculous_drift:
		shoe_scale *= 1.1
	if ridiculous_boost or ridiculous_caffeine:
		shoe_scale *= 1.04
	if crossover_heavy:
		shoe_scale *= 1.12
	if crossover_bass:
		shoe_scale *= 1.08
	if crossover_portal:
		shoe_scale *= 1.05
	if crossover_gyro:
		shoe_scale *= 1.04
	if tribute_bastion or tribute_azure:
		shoe_scale *= 1.12
	if tribute_volt or tribute_radiant:
		shoe_scale *= 1.06
	if tribute_gale:
		shoe_scale *= 1.04
	if tribute_orbit or tribute_echo:
		shoe_scale *= 1.05
	if vehicle_id == "treadfall_blades":
		shoe_scale *= 0.98
	elif vehicle_id == "iron_derby_blitz":
		shoe_scale *= 1.1
	elif vehicle_id == "anti_gravity_platforms":
		shoe_scale *= 1.15
	elif vehicle_id == "starglass_pointe":
		shoe_scale *= 0.92
	elif vehicle_id == "kelpjet_submariners":
		shoe_scale *= 1.06
	elif vehicle_id == "tidefin_runners":
		shoe_scale *= 0.98
	elif vehicle_id == "bubblegum_stilts":
		shoe_scale *= 1.08
	elif vehicle_id == "banana_boomerang_cleats":
		shoe_scale *= 0.97
	elif vehicle_id == "lifeling_lopers":
		shoe_scale *= 1.02
	elif vehicle_id == "waike_circuit_clogs":
		shoe_scale *= 1.06
	elif vehicle_id == "nullstep":
		shoe_scale *= 0.98
	elif vehicle_id == "cinderstride":
		shoe_scale *= 1.03
	# Kinetic Sole stack: outsole / midsole yellow / kinetic upper / tread bars.
	var midsole := StandardMaterial3D.new()
	midsole.albedo_color = Color(0.96, 0.77, 0.09) # Midsole Yellow
	midsole.roughness = 0.45
	midsole.emission_enabled = native_street or native_roller or native_hover or native_elemental or native_ridiculous or native_crossover or native_tribute
	if midsole.emission_enabled:
		midsole.emission = Color(0.96, 0.77, 0.09)
		midsole.emission_energy_multiplier = (
			0.36 if (hover_boost or hover_bounce or elemental_magma or ridiculous_boost or ridiculous_caffeine or crossover_circuit or crossover_bass or tribute_ember or tribute_volt or tribute_radiant) else (
				0.34 if (power or kinetic or roller_hover or hover_glide or elemental_dive or ridiculous_trick or crossover_portal or crossover_tap or tribute_orbit or tribute_echo) else (
					0.3 if (tempo or rail or roller_inline or hover_precision or elemental_wet or elemental_frost or ridiculous_reach or crossover_gyro or crossover_soft or tribute_gale or tribute_azure) else 0.22
				)
			)
		)
	var upper := StandardMaterial3D.new()
	if balanced:
		upper.albedo_color = Color(1.0, 0.42, 0.24) # Kinetic Orange Circlers
	elif sprint:
		upper.albedo_color = Color(1.0, 0.42, 0.36) # Quillspike coral
	elif parkour:
		upper.albedo_color = Color(0.18, 0.77, 0.71) # Fluxgrip teal
	elif tempo:
		upper.albedo_color = Color(0.45, 0.75, 0.98) # Lanewind sky
	elif rail:
		upper.albedo_color = Color(0.65, 0.45, 0.98) # Ghost Violet
	elif power:
		upper.albedo_color = Color(0.64, 0.44, 0.28) # Clay iron plate
	elif trick:
		upper.albedo_color = Color(0.58, 0.85, 0.18) # Kaleido lime
	elif kinetic:
		upper.albedo_color = Color(0.13, 0.72, 0.81) # Volt cyan
	elif vehicle_id == "slipstream_inlines":
		upper.albedo_color = Color(0.2, 0.78, 0.95) # Slipstream cyan
	elif vehicle_id == "heelspin_quads":
		upper.albedo_color = Color(0.95, 0.35, 0.55) # Heelspin magenta
	elif vehicle_id == "velvet_rollers":
		upper.albedo_color = Color(0.55, 0.28, 0.72) # Velvet plum
	elif vehicle_id == "iron_derby_blitz":
		upper.albedo_color = Color(0.45, 0.48, 0.52) # Derby steel
	elif vehicle_id == "scissorblade_skates":
		upper.albedo_color = Color(0.85, 0.9, 0.95) # Blade silver
	elif vehicle_id == "orbitwheel_heels":
		upper.albedo_color = Color(0.35, 0.85, 0.7) # Orbit mint
	elif vehicle_id == "treadfall_blades":
		upper.albedo_color = Color(0.95, 0.55, 0.15) # Treadfall amber
	elif vehicle_id == "cloudsole_striders":
		upper.albedo_color = Color(0.78, 0.88, 1.0) # Cloud white-blue
	elif vehicle_id == "nebula_skippers":
		upper.albedo_color = Color(0.55, 0.35, 0.95) # Nebula violet
	elif vehicle_id == "ufo_loafers":
		upper.albedo_color = Color(0.7, 0.85, 0.45) # Saucer olive
	elif vehicle_id == "meteor_heeljets":
		upper.albedo_color = Color(1.0, 0.45, 0.2) # Meteor ember
	elif vehicle_id == "anti_gravity_platforms":
		upper.albedo_color = Color(0.55, 0.9, 0.95) # Anti-G cyan
	elif vehicle_id == "moonbounce_booties":
		upper.albedo_color = Color(0.9, 0.9, 0.85) # Moon foam
	elif vehicle_id == "starglass_pointe":
		upper.albedo_color = Color(0.85, 0.75, 1.0) # Starglass lilac
	elif vehicle_id == "tidefin_runners":
		upper.albedo_color = Color(0.15, 0.72, 0.88) # Tidefin aqua
	elif vehicle_id == "kelpjet_submariners":
		upper.albedo_color = Color(0.18, 0.55, 0.42) # Kelp deep green
	elif vehicle_id == "sandstorm_skimmers":
		upper.albedo_color = Color(0.92, 0.72, 0.38) # Sandstorm gold
	elif vehicle_id == "magma_treaders":
		upper.albedo_color = Color(0.95, 0.28, 0.12) # Magma crimson
	elif vehicle_id == "snowglobe_galoshes":
		upper.albedo_color = Color(0.78, 0.92, 0.98) # Frost ice
	elif vehicle_id == "mud_monster_waders":
		upper.albedo_color = Color(0.42, 0.32, 0.18) # Mud ochre
	elif vehicle_id == "slipper_rockets":
		upper.albedo_color = Color(0.95, 0.55, 0.75) # Fuzzy pink slipper
	elif vehicle_id == "pancake_stompers":
		upper.albedo_color = Color(0.92, 0.7, 0.35) # Pancake batter
	elif vehicle_id == "bubblegum_stilts":
		upper.albedo_color = Color(0.98, 0.45, 0.78) # Bubblegum pink
	elif vehicle_id == "espresso_jet_socks":
		upper.albedo_color = Color(0.35, 0.2, 0.12) # Espresso brown
	elif vehicle_id == "sofa_surfers":
		upper.albedo_color = Color(0.55, 0.65, 0.85) # Sofa denim
	elif vehicle_id == "banana_boomerang_cleats":
		upper.albedo_color = Color(0.98, 0.88, 0.2) # Banana yellow
	elif vehicle_id == "lifeling_lopers":
		upper.albedo_color = Color(0.45, 0.82, 0.55) # Lifeling leaf
	elif vehicle_id == "fossil_footsteps":
		upper.albedo_color = Color(0.62, 0.48, 0.32) # Fossil sandstone
	elif vehicle_id == "beatlink_tapstep_oxfords":
		upper.albedo_color = Color(0.2, 0.22, 0.28) # Tap oxford charcoal
	elif vehicle_id == "beatlink_bassline_boots":
		upper.albedo_color = Color(0.55, 0.18, 0.65) # Bassline violet
	elif vehicle_id == "waike_circuit_clogs":
		upper.albedo_color = Color(0.15, 0.75, 0.7) # WAIKE circuit teal
	elif vehicle_id == "mlv_portal_pumps":
		upper.albedo_color = Color(0.75, 0.4, 0.95) # MLV portal violet
	elif vehicle_id == "edge_io_gyrowraps":
		upper.albedo_color = Color(0.25, 0.85, 0.55) # Edge I/O lime
	elif vehicle_id == "cinderstride":
		upper.albedo_color = Color(0.95, 0.35, 0.15) # Cinder ember
	elif vehicle_id == "bastion_stomp":
		upper.albedo_color = Color(0.55, 0.52, 0.48) # Bastion steel
	elif vehicle_id == "voltstep_coils":
		upper.albedo_color = Color(0.95, 0.85, 0.15) # Volt gold
	elif vehicle_id == "galeleaf_gliders":
		upper.albedo_color = Color(0.35, 0.85, 0.45) # Galeleaf green
	elif vehicle_id == "azure_bastions":
		upper.albedo_color = Color(0.25, 0.55, 0.95) # Azure blue
	elif vehicle_id == "orbitwalkers":
		upper.albedo_color = Color(0.65, 0.7, 0.95) # Orbit silver-blue
	elif vehicle_id == "phase_echoes":
		upper.albedo_color = Color(0.55, 0.85, 0.95) # Echo cyan
	elif vehicle_id == "nullstep":
		upper.albedo_color = Color(0.18, 0.18, 0.22) # Null matte
	elif vehicle_id == "radiant_order":
		upper.albedo_color = Color(0.98, 0.92, 0.55) # Radiant gold
	else:
		upper.albedo_color = self.accent_color
	upper.roughness = 0.38 if not (power or elemental_mud or elemental_magma or ridiculous_stomp or ridiculous_drift or crossover_heavy or tribute_bastion or tribute_null) else 0.55
	upper.emission_enabled = true
	upper.emission = Color(1.0, 0.42, 0.24) if power else upper.albedo_color
	upper.emission_energy_multiplier = (
		0.45 if (hover_boost or elemental_magma or ridiculous_caffeine or crossover_bass or tribute_ember or tribute_radiant) else (
			0.42 if (kinetic or roller_hover or hover_bounce or elemental_dive or ridiculous_boost or crossover_circuit or crossover_portal or tribute_volt or tribute_orbit) else (
				0.38 if power else (
					0.4 if (rail or hover_precision or elemental_frost or ridiculous_trick or crossover_tap or crossover_gyro or tribute_echo or tribute_gale) else (
						0.35 if (tempo or roller_inline or hover_glide or elemental_wet or ridiculous_reach or crossover_soft or tribute_azure) else 0.28
					)
				)
			)
		)
	)
	var wheel := StandardMaterial3D.new()
	wheel.albedo_color = Color(0.08, 0.08, 0.1)
	wheel.roughness = 0.7
	wheel.emission_enabled = roller_hover or native_hover
	if wheel.emission_enabled:
		wheel.emission = Color(0.55, 0.85, 1.0) if native_hover else Color(0.35, 0.85, 0.7)
		wheel.emission_energy_multiplier = 0.4 if native_hover else 0.35
	var hover_pad := StandardMaterial3D.new()
	hover_pad.albedo_color = Color(0.65, 0.85, 1.0)
	hover_pad.roughness = 0.25
	hover_pad.emission_enabled = true
	hover_pad.emission = Color(0.45, 0.75, 1.0)
	hover_pad.emission_energy_multiplier = 0.4
	var hydro := StandardMaterial3D.new()
	hydro.albedo_color = Color(0.2, 0.75, 0.95)
	hydro.roughness = 0.28
	hydro.emission_enabled = elemental_wet or elemental_dive
	if hydro.emission_enabled:
		hydro.emission = Color(0.15, 0.65, 0.9)
		hydro.emission_energy_multiplier = 0.42 if elemental_dive else 0.36
	var sand_pad := StandardMaterial3D.new()
	sand_pad.albedo_color = Color(0.88, 0.7, 0.4)
	sand_pad.roughness = 0.65
	sand_pad.emission_enabled = elemental_sand
	if sand_pad.emission_enabled:
		sand_pad.emission = Color(0.95, 0.75, 0.35)
		sand_pad.emission_energy_multiplier = 0.28
	var magma_plate := StandardMaterial3D.new()
	magma_plate.albedo_color = Color(0.95, 0.35, 0.12)
	magma_plate.roughness = 0.4
	magma_plate.metallic = 0.45
	magma_plate.emission_enabled = elemental_magma
	if magma_plate.emission_enabled:
		magma_plate.emission = Color(1.0, 0.4, 0.08)
		magma_plate.emission_energy_multiplier = 0.48
	var frost_pad := StandardMaterial3D.new()
	frost_pad.albedo_color = Color(0.75, 0.9, 1.0)
	frost_pad.roughness = 0.22
	frost_pad.emission_enabled = elemental_frost
	if frost_pad.emission_enabled:
		frost_pad.emission = Color(0.65, 0.85, 1.0)
		frost_pad.emission_energy_multiplier = 0.38
	var mud_pad := StandardMaterial3D.new()
	mud_pad.albedo_color = Color(0.38, 0.28, 0.16)
	mud_pad.roughness = 0.85
	mud_pad.emission_enabled = elemental_mud
	if mud_pad.emission_enabled:
		mud_pad.emission = Color(0.45, 0.32, 0.12)
		mud_pad.emission_energy_multiplier = 0.2
	var joke_jet := StandardMaterial3D.new()
	joke_jet.albedo_color = Color(1.0, 0.55, 0.75)
	joke_jet.roughness = 0.35
	joke_jet.emission_enabled = ridiculous_boost or ridiculous_caffeine
	if joke_jet.emission_enabled:
		joke_jet.emission = Color(1.0, 0.45, 0.2) if ridiculous_caffeine else Color(1.0, 0.6, 0.85)
		joke_jet.emission_energy_multiplier = 0.45 if ridiculous_caffeine else 0.4
	var pancake_mat := StandardMaterial3D.new()
	pancake_mat.albedo_color = Color(0.9, 0.68, 0.32)
	pancake_mat.roughness = 0.7
	pancake_mat.emission_enabled = ridiculous_stomp
	if pancake_mat.emission_enabled:
		pancake_mat.emission = Color(0.95, 0.55, 0.15)
		pancake_mat.emission_energy_multiplier = 0.25
	var gum_mat := StandardMaterial3D.new()
	gum_mat.albedo_color = Color(0.98, 0.5, 0.82)
	gum_mat.roughness = 0.3
	gum_mat.emission_enabled = ridiculous_reach
	if gum_mat.emission_enabled:
		gum_mat.emission = Color(1.0, 0.4, 0.75)
		gum_mat.emission_energy_multiplier = 0.35
	var sofa_mat := StandardMaterial3D.new()
	sofa_mat.albedo_color = Color(0.5, 0.6, 0.8)
	sofa_mat.roughness = 0.75
	sofa_mat.emission_enabled = ridiculous_drift
	if sofa_mat.emission_enabled:
		sofa_mat.emission = Color(0.45, 0.55, 0.85)
		sofa_mat.emission_energy_multiplier = 0.22
	var banana_mat := StandardMaterial3D.new()
	banana_mat.albedo_color = Color(0.98, 0.88, 0.2)
	banana_mat.roughness = 0.4
	banana_mat.emission_enabled = ridiculous_trick
	if banana_mat.emission_enabled:
		banana_mat.emission = Color(1.0, 0.85, 0.15)
		banana_mat.emission_energy_multiplier = 0.32
	var life_mat := StandardMaterial3D.new()
	life_mat.albedo_color = Color(0.4, 0.8, 0.5)
	life_mat.roughness = 0.45
	life_mat.emission_enabled = crossover_soft
	if life_mat.emission_enabled:
		life_mat.emission = Color(0.35, 0.85, 0.45)
		life_mat.emission_energy_multiplier = 0.3
	var fossil_mat := StandardMaterial3D.new()
	fossil_mat.albedo_color = Color(0.58, 0.45, 0.3)
	fossil_mat.roughness = 0.8
	fossil_mat.emission_enabled = crossover_heavy
	if fossil_mat.emission_enabled:
		fossil_mat.emission = Color(0.7, 0.5, 0.25)
		fossil_mat.emission_energy_multiplier = 0.22
	var tap_mat := StandardMaterial3D.new()
	tap_mat.albedo_color = Color(0.85, 0.75, 0.45)
	tap_mat.roughness = 0.35
	tap_mat.metallic = 0.4
	tap_mat.emission_enabled = crossover_tap
	if tap_mat.emission_enabled:
		tap_mat.emission = Color(0.95, 0.8, 0.35)
		tap_mat.emission_energy_multiplier = 0.35
	var bass_mat := StandardMaterial3D.new()
	bass_mat.albedo_color = Color(0.5, 0.15, 0.6)
	bass_mat.roughness = 0.4
	bass_mat.emission_enabled = crossover_bass
	if bass_mat.emission_enabled:
		bass_mat.emission = Color(0.7, 0.25, 0.9)
		bass_mat.emission_energy_multiplier = 0.42
	var circuit_mat := StandardMaterial3D.new()
	circuit_mat.albedo_color = Color(0.12, 0.8, 0.75)
	circuit_mat.roughness = 0.3
	circuit_mat.emission_enabled = crossover_circuit
	if circuit_mat.emission_enabled:
		circuit_mat.emission = Color(0.1, 0.9, 0.85)
		circuit_mat.emission_energy_multiplier = 0.4
	var portal_mat := StandardMaterial3D.new()
	portal_mat.albedo_color = Color(0.7, 0.35, 0.95)
	portal_mat.roughness = 0.25
	portal_mat.emission_enabled = crossover_portal
	if portal_mat.emission_enabled:
		portal_mat.emission = Color(0.8, 0.4, 1.0)
		portal_mat.emission_energy_multiplier = 0.45
	var gyro_mat := StandardMaterial3D.new()
	gyro_mat.albedo_color = Color(0.2, 0.85, 0.5)
	gyro_mat.roughness = 0.35
	gyro_mat.emission_enabled = crossover_gyro
	if gyro_mat.emission_enabled:
		gyro_mat.emission = Color(0.25, 0.95, 0.55)
		gyro_mat.emission_energy_multiplier = 0.38
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color(0.95, 0.4, 0.12)
	ember_mat.roughness = 0.4
	ember_mat.emission_enabled = tribute_ember
	if ember_mat.emission_enabled:
		ember_mat.emission = Color(1.0, 0.35, 0.08)
		ember_mat.emission_energy_multiplier = 0.45
	var bastion_mat := StandardMaterial3D.new()
	bastion_mat.albedo_color = Color(0.5, 0.48, 0.45)
	bastion_mat.roughness = 0.55
	bastion_mat.metallic = 0.5
	bastion_mat.emission_enabled = tribute_bastion
	if bastion_mat.emission_enabled:
		bastion_mat.emission = Color(0.7, 0.65, 0.55)
		bastion_mat.emission_energy_multiplier = 0.25
	var volt_mat := StandardMaterial3D.new()
	volt_mat.albedo_color = Color(0.95, 0.85, 0.15)
	volt_mat.roughness = 0.3
	volt_mat.emission_enabled = tribute_volt
	if volt_mat.emission_enabled:
		volt_mat.emission = Color(1.0, 0.9, 0.2)
		volt_mat.emission_energy_multiplier = 0.48
	var gale_mat := StandardMaterial3D.new()
	gale_mat.albedo_color = Color(0.35, 0.85, 0.45)
	gale_mat.roughness = 0.35
	gale_mat.emission_enabled = tribute_gale
	if gale_mat.emission_enabled:
		gale_mat.emission = Color(0.4, 0.95, 0.5)
		gale_mat.emission_energy_multiplier = 0.35
	var azure_mat := StandardMaterial3D.new()
	azure_mat.albedo_color = Color(0.25, 0.55, 0.95)
	azure_mat.roughness = 0.4
	azure_mat.metallic = 0.45
	azure_mat.emission_enabled = tribute_azure
	if azure_mat.emission_enabled:
		azure_mat.emission = Color(0.3, 0.6, 1.0)
		azure_mat.emission_energy_multiplier = 0.35
	var orbit_mat := StandardMaterial3D.new()
	orbit_mat.albedo_color = Color(0.65, 0.7, 0.95)
	orbit_mat.roughness = 0.28
	orbit_mat.emission_enabled = tribute_orbit
	if orbit_mat.emission_enabled:
		orbit_mat.emission = Color(0.7, 0.75, 1.0)
		orbit_mat.emission_energy_multiplier = 0.4
	var echo_mat := StandardMaterial3D.new()
	echo_mat.albedo_color = Color(0.55, 0.85, 0.95)
	echo_mat.roughness = 0.22
	echo_mat.emission_enabled = tribute_echo
	if echo_mat.emission_enabled:
		echo_mat.emission = Color(0.5, 0.9, 1.0)
		echo_mat.emission_energy_multiplier = 0.42
	var null_mat := StandardMaterial3D.new()
	null_mat.albedo_color = Color(0.12, 0.12, 0.16)
	null_mat.roughness = 0.9
	null_mat.emission_enabled = tribute_null
	if null_mat.emission_enabled:
		null_mat.emission = Color(0.25, 0.25, 0.35)
		null_mat.emission_energy_multiplier = 0.18
	var radiant_mat := StandardMaterial3D.new()
	radiant_mat.albedo_color = Color(0.98, 0.9, 0.45)
	radiant_mat.roughness = 0.3
	radiant_mat.emission_enabled = tribute_radiant
	if radiant_mat.emission_enabled:
		radiant_mat.emission = Color(1.0, 0.95, 0.55)
		radiant_mat.emission_energy_multiplier = 0.45
	var outsole := StandardMaterial3D.new()
	outsole.albedo_color = Color(0.12, 0.12, 0.14)
	outsole.roughness = 0.85
	var grip := StandardMaterial3D.new()
	grip.albedo_color = Color(0.24, 0.86, 0.52) # Grip Green
	grip.roughness = 0.55
	grip.emission_enabled = tempo or parkour
	if grip.emission_enabled:
		grip.emission = Color(0.24, 0.86, 0.52)
		grip.emission_energy_multiplier = 0.4
	var railfin := StandardMaterial3D.new()
	railfin.albedo_color = Color(0.18, 0.9, 0.95) # Boost Cyan
	railfin.roughness = 0.35
	railfin.emission_enabled = rail or kinetic
	if railfin.emission_enabled:
		railfin.emission = Color(0.18, 0.9, 0.95)
		railfin.emission_energy_multiplier = 0.45
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(1.0, 0.42, 0.24) # Kinetic Orange plates
	iron.roughness = 0.4
	iron.metallic = 0.55
	iron.emission_enabled = power
	if iron.emission_enabled:
		iron.emission = Color(1.0, 0.42, 0.24)
		iron.emission_energy_multiplier = 0.42
	var spike := StandardMaterial3D.new()
	spike.albedo_color = Color(0.12, 0.12, 0.14)
	spike.metallic = 0.7
	spike.roughness = 0.3
	# Toe / sole body (forward +Z).
	var sole_len := 0.34 if sprint else (0.28 if parkour else 0.3)
	var sole := _mesh_box(
		Vector3(0.15 * ws * shoe_scale, 0.05 * shoe_scale, sole_len * shoe_scale),
		Vector3.ZERO,
		outsole
	)
	leg.add_child(sole)
	sole.position = Vector3(0, -leg_len - 0.035, 0.06 * shoe_scale)
	var mid := _mesh_box(
		Vector3(0.145 * ws * shoe_scale, 0.045 * shoe_scale, (sole_len - 0.02) * shoe_scale),
		Vector3.ZERO,
		midsole
	)
	leg.add_child(mid)
	mid.position = Vector3(0, -leg_len + 0.005, 0.05 * shoe_scale)
	var vamp := _mesh_box(
		Vector3(0.13 * ws * shoe_scale, 0.08 * shoe_scale, 0.22 * shoe_scale),
		Vector3.ZERO,
		upper
	)
	leg.add_child(vamp)
	vamp.position = Vector3(0, -leg_len + 0.05, 0.04 * shoe_scale)
	# Rounded toe nub.
	var toe := _mesh_sphere(0.055 * shoe_scale * ws / 0.55, Vector3.ZERO, upper)
	leg.add_child(toe)
	toe.position = Vector3(0, -leg_len - 0.01, 0.2 * shoe_scale)
	toe.scale = Vector3(1.1, 0.7, 1.2)
	# Forward chevron (speed symbol) on the tongue.
	var chevron := _mesh_box(
		Vector3(0.06 * ws * shoe_scale, 0.02 * shoe_scale, 0.08 * shoe_scale),
		Vector3.ZERO,
		midsole
	)
	leg.add_child(chevron)
	chevron.position = Vector3(0, -leg_len + 0.09, 0.12 * shoe_scale)
	# Grip tread bars / roller / hover / elemental / ridiculous / crossover / tribute soles under the outsole.
	var tread_count := 5 if (tempo or parkour or roller_quad or hover_bounce or elemental_mud or elemental_sand or ridiculous_stomp or ridiculous_drift or crossover_heavy or crossover_gyro or tribute_bastion or tribute_azure) else (
		4 if (
			rail or power or kinetic or trick or roller_inline or roller_hover
			or hover_glide or hover_boost or hover_precision
			or elemental_wet or elemental_dive or elemental_magma or elemental_frost
			or ridiculous_boost or ridiculous_caffeine or ridiculous_reach or ridiculous_trick
			or crossover_soft or crossover_tap or crossover_bass or crossover_circuit or crossover_portal
			or tribute_ember or tribute_volt or tribute_gale or tribute_orbit or tribute_echo or tribute_null or tribute_radiant
		) else 3
	)
	for i in range(tread_count):
		var tread_mat: Material = dark
		if tempo or parkour:
			tread_mat = grip
		elif rail or kinetic:
			tread_mat = railfin
		elif power:
			tread_mat = iron
		elif sprint:
			tread_mat = spike
		elif trick:
			tread_mat = upper
		elif elemental_wet or elemental_dive:
			tread_mat = hydro
		elif elemental_sand:
			tread_mat = sand_pad
		elif elemental_magma:
			tread_mat = magma_plate
		elif elemental_frost:
			tread_mat = frost_pad
		elif elemental_mud:
			tread_mat = mud_pad
		elif ridiculous_boost or ridiculous_caffeine:
			tread_mat = joke_jet
		elif ridiculous_stomp:
			tread_mat = pancake_mat
		elif ridiculous_reach:
			tread_mat = gum_mat
		elif ridiculous_drift:
			tread_mat = sofa_mat
		elif ridiculous_trick:
			tread_mat = banana_mat
		elif crossover_soft:
			tread_mat = life_mat
		elif crossover_heavy:
			tread_mat = fossil_mat
		elif crossover_tap:
			tread_mat = tap_mat
		elif crossover_bass:
			tread_mat = bass_mat
		elif crossover_circuit:
			tread_mat = circuit_mat
		elif crossover_portal:
			tread_mat = portal_mat
		elif crossover_gyro:
			tread_mat = gyro_mat
		elif tribute_ember:
			tread_mat = ember_mat
		elif tribute_bastion:
			tread_mat = bastion_mat
		elif tribute_volt:
			tread_mat = volt_mat
		elif tribute_gale:
			tread_mat = gale_mat
		elif tribute_azure:
			tread_mat = azure_mat
		elif tribute_orbit:
			tread_mat = orbit_mat
		elif tribute_echo:
			tread_mat = echo_mat
		elif tribute_null:
			tread_mat = null_mat
		elif tribute_radiant:
			tread_mat = radiant_mat
		elif native_hover:
			tread_mat = hover_pad
		elif native_roller:
			tread_mat = wheel
		var use_wheelish := native_roller and not native_hover and not native_elemental and not native_ridiculous and not native_crossover and not native_tribute
		var tread := _mesh_box(
			Vector3(
				0.14 * ws * shoe_scale if (native_hover or native_elemental or native_ridiculous or native_crossover or native_tribute) else (0.05 * ws * shoe_scale if use_wheelish else 0.13 * ws * shoe_scale),
				0.02 * shoe_scale if (native_hover or elemental_wet or elemental_frost or ridiculous_reach or crossover_soft or crossover_portal or tribute_echo or tribute_gale) else (
					0.03 * shoe_scale if (native_elemental or native_ridiculous or native_crossover or native_tribute) else (0.05 * shoe_scale if use_wheelish else 0.025 * shoe_scale)
				),
				0.04 * shoe_scale if (native_hover or native_elemental or native_ridiculous or native_crossover or native_tribute) else (0.05 * shoe_scale if use_wheelish else 0.035 * shoe_scale)
			),
			Vector3.ZERO,
			tread_mat
		)
		leg.add_child(tread)
		var z_spread := 0.055 if (native_street or native_roller or native_hover or native_elemental or native_ridiculous or native_crossover or native_tribute) else 0.07
		tread.position = Vector3(
			side * (0.06 * ws * shoe_scale if use_wheelish else 0.0),
			-leg_len - (0.05 if (native_hover or native_elemental or native_ridiculous or native_crossover or native_tribute) else 0.058),
			(float(i) - float(tread_count - 1) * 0.5) * z_spread * shoe_scale
		)
		if native_roller and roller_quad:
			## Second wheel column for quads.
			var tread2 := _mesh_box(
				Vector3(0.05 * ws * shoe_scale, 0.05 * shoe_scale, 0.05 * shoe_scale),
				Vector3.ZERO,
				wheel
			)
			leg.add_child(tread2)
			tread2.position = Vector3(
				side * (-0.06 * ws * shoe_scale),
				-leg_len - 0.058,
				(float(i) - float(tread_count - 1) * 0.5) * z_spread * shoe_scale
			)
	# Heel block (rear) with family-specific silhouette props.
	var heel := _mesh_box(
		Vector3(0.13 * ws * shoe_scale, 0.1 * shoe_scale, 0.11 * shoe_scale),
		Vector3.ZERO,
		dark
	)
	leg.add_child(heel)
	heel.position = Vector3(0, -leg_len - 0.01, -0.11 * shoe_scale)
	if balanced:
		var flare := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.12 * shoe_scale, 0.05 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(flare)
		flare.position = Vector3(side * 0.08 * ws * shoe_scale, -leg_len + 0.04, -0.12 * shoe_scale)
	elif sprint:
		## Quillspike launch plates — forward spike rake.
		for si in range(3):
			var spike_mesh := _mesh_box(
				Vector3(0.02 * ws * shoe_scale, 0.06 * shoe_scale, 0.04 * shoe_scale),
				Vector3.ZERO,
				spike
			)
			leg.add_child(spike_mesh)
			spike_mesh.position = Vector3(
				side * 0.04 * ws * shoe_scale,
				-leg_len - 0.07,
				(0.02 + float(si) * 0.05) * shoe_scale
			)
	elif parkour:
		## Fluxgrip sticky sidewall cups.
		var cup := _mesh_box(
			Vector3(0.05 * ws * shoe_scale, 0.12 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			grip
		)
		leg.add_child(cup)
		cup.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, 0.02 * shoe_scale)
	elif tempo:
		## Slim wind-cup heel wing — silhouette reads at chase distance.
		var wing := _mesh_box(
			Vector3(0.035 * ws * shoe_scale, 0.1 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			grip
		)
		leg.add_child(wing)
		wing.position = Vector3(side * 0.09 * ws * shoe_scale, -leg_len + 0.03, -0.08 * shoe_scale)
	elif rail:
		## Razor railfin — Boost Cyan blade for Prism Apex cornering read.
		var fin := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.14 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			railfin
		)
		leg.add_child(fin)
		fin.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, -0.02 * shoe_scale)
		var fin2 := _mesh_box(
			Vector3(0.025 * ws * shoe_scale, 0.08 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(fin2)
		fin2.position = Vector3(side * 0.11 * ws * shoe_scale, -leg_len + 0.02, -0.12 * shoe_scale)
	elif power:
		## Blocky Harborclimb iron heel plates — forge ash silhouette.
		var plate := _mesh_box(
			Vector3(0.06 * ws * shoe_scale, 0.14 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			iron
		)
		leg.add_child(plate)
		plate.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, -0.1 * shoe_scale)
		var cuff := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.08 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			iron
		)
		leg.add_child(cuff)
		cuff.position = Vector3(0.0, -leg_len + 0.1, -0.02 * shoe_scale)
	elif trick:
		## Rivenspin kaleido heel wings — loud offset fins.
		var wing_a := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.12 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(wing_a)
		wing_a.position = Vector3(side * 0.11 * ws * shoe_scale, -leg_len + 0.05, -0.06 * shoe_scale)
		var wing_b := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.08 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(wing_b)
		wing_b.position = Vector3(side * -0.05 * ws * shoe_scale, -leg_len + 0.02, -0.1 * shoe_scale)
	elif kinetic:
		## Voltcirc coreloop heel rings (emissive torus approximation).
		var ring := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.03 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			railfin
		)
		leg.add_child(ring)
		ring.position = Vector3(0.0, -leg_len + 0.08, -0.08 * shoe_scale)
		var ring2 := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.025 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(ring2)
		ring2.position = Vector3(0.0, -leg_len + 0.12, -0.08 * shoe_scale)
	elif roller_inline:
		## Inline chassis + ankle cuff; per-ID blade/fin read.
		var chassis := _mesh_box(
			Vector3(0.08 * ws * shoe_scale, 0.04 * shoe_scale, 0.28 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(chassis)
		chassis.position = Vector3(0.0, -leg_len - 0.02, 0.02 * shoe_scale)
		var cuff_i := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.1 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			midsole if vehicle_id != "iron_derby_blitz" else iron
		)
		leg.add_child(cuff_i)
		cuff_i.position = Vector3(0.0, -leg_len + 0.08, -0.06 * shoe_scale)
		if vehicle_id == "scissorblade_skates":
			var blade := _mesh_box(
				Vector3(0.02 * ws * shoe_scale, 0.06 * shoe_scale, 0.22 * shoe_scale),
				Vector3.ZERO,
				spike
			)
			leg.add_child(blade)
			blade.position = Vector3(side * 0.09 * ws * shoe_scale, -leg_len - 0.02, 0.04 * shoe_scale)
		elif vehicle_id == "treadfall_blades":
			var rake := _mesh_box(
				Vector3(0.03 * ws * shoe_scale, 0.05 * shoe_scale, 0.18 * shoe_scale),
				Vector3.ZERO,
				upper
			)
			leg.add_child(rake)
			rake.position = Vector3(side * 0.08 * ws * shoe_scale, -leg_len + 0.02, -0.1 * shoe_scale)
		elif vehicle_id == "slipstream_inlines":
			var stream := _mesh_box(
				Vector3(0.025 * ws * shoe_scale, 0.08 * shoe_scale, 0.14 * shoe_scale),
				Vector3.ZERO,
				railfin
			)
			leg.add_child(stream)
			stream.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, 0.0)
	elif roller_quad:
		## Quad boot block + heel brake pad.
		var boot := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.1 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(boot)
		boot.position = Vector3(0.0, -leg_len + 0.04, -0.02 * shoe_scale)
		var brake := _mesh_box(
			Vector3(0.08 * ws * shoe_scale, 0.05 * shoe_scale, 0.06 * shoe_scale),
			Vector3.ZERO,
			midsole if vehicle_id == "velvet_rollers" else iron
		)
		leg.add_child(brake)
		brake.position = Vector3(0.0, -leg_len - 0.02, -0.14 * shoe_scale)
		if vehicle_id == "heelspin_quads":
			var spin := _mesh_box(
				Vector3(0.04 * ws * shoe_scale, 0.12 * shoe_scale, 0.04 * shoe_scale),
				Vector3.ZERO,
				upper
			)
			leg.add_child(spin)
			spin.position = Vector3(side * 0.11 * ws * shoe_scale, -leg_len + 0.06, -0.08 * shoe_scale)
	elif roller_hover:
		## Mag-orbit heel disc (grounded collision; VFX-only hover read).
		var disc := _mesh_box(
			Vector3(0.18 * ws * shoe_scale, 0.03 * shoe_scale, 0.18 * shoe_scale),
			Vector3.ZERO,
			wheel
		)
		leg.add_child(disc)
		disc.position = Vector3(0.0, -leg_len - 0.01, -0.04 * shoe_scale)
		var orbit := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.04 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(orbit)
		orbit.position = Vector3(0.0, -leg_len + 0.08, -0.04 * shoe_scale)
	elif hover_glide:
		## Glide skirt + ankle ring — grounded pad silhouette (no phase-through).
		var skirt := _mesh_box(
			Vector3(0.2 * ws * shoe_scale, 0.025 * shoe_scale, 0.22 * shoe_scale),
			Vector3.ZERO,
			hover_pad
		)
		leg.add_child(skirt)
		skirt.position = Vector3(0.0, -leg_len - 0.02, 0.02 * shoe_scale)
		var ring_g := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.05 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(ring_g)
		ring_g.position = Vector3(0.0, -leg_len + 0.07, -0.04 * shoe_scale)
		if vehicle_id == "ufo_loafers":
			var dome := _mesh_box(
				Vector3(0.16 * ws * shoe_scale, 0.08 * shoe_scale, 0.16 * shoe_scale),
				Vector3.ZERO,
				midsole
			)
			leg.add_child(dome)
			dome.position = Vector3(0.0, -leg_len + 0.1, 0.0)
		elif vehicle_id == "anti_gravity_platforms":
			var plate_g := _mesh_box(
				Vector3(0.24 * ws * shoe_scale, 0.03 * shoe_scale, 0.18 * shoe_scale),
				Vector3.ZERO,
				hover_pad
			)
			leg.add_child(plate_g)
			plate_g.position = Vector3(0.0, -leg_len - 0.04, 0.0)
		elif vehicle_id == "nebula_skippers":
			var trail := _mesh_box(
				Vector3(0.04 * ws * shoe_scale, 0.1 * shoe_scale, 0.12 * shoe_scale),
				Vector3.ZERO,
				upper
			)
			leg.add_child(trail)
			trail.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, -0.08 * shoe_scale)
	elif hover_boost:
		## Meteor heeljets — dual rear thruster cones (VFX; collision grounded).
		var jet_l := _mesh_box(
			Vector3(0.05 * ws * shoe_scale, 0.08 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(jet_l)
		jet_l.position = Vector3(side * 0.07 * ws * shoe_scale, -leg_len + 0.02, -0.14 * shoe_scale)
		var jet_flame := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.04 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(jet_flame)
		jet_flame.position = Vector3(side * 0.07 * ws * shoe_scale, -leg_len - 0.02, -0.2 * shoe_scale)
		var cuff_j := _mesh_box(
			Vector3(0.13 * ws * shoe_scale, 0.1 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(cuff_j)
		cuff_j.position = Vector3(0.0, -leg_len + 0.1, -0.02 * shoe_scale)
	elif hover_bounce:
		## Moonbounce foam heel bulb.
		var bulb := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.12 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(bulb)
		bulb.position = Vector3(0.0, -leg_len + 0.02, -0.08 * shoe_scale)
		var foam := _mesh_box(
			Vector3(0.18 * ws * shoe_scale, 0.04 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			hover_pad
		)
		leg.add_child(foam)
		foam.position = Vector3(0.0, -leg_len - 0.03, 0.0)
	elif hover_precision:
		## Starglass pointe blade + slim ankle cuff.
		var pointe := _mesh_box(
			Vector3(0.06 * ws * shoe_scale, 0.05 * shoe_scale, 0.26 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(pointe)
		pointe.position = Vector3(0.0, -leg_len - 0.01, 0.06 * shoe_scale)
		var glass := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.12 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			hover_pad
		)
		leg.add_child(glass)
		glass.position = Vector3(side * 0.09 * ws * shoe_scale, -leg_len + 0.05, -0.02 * shoe_scale)
		var cuff_p := _mesh_box(
			Vector3(0.1 * ws * shoe_scale, 0.08 * shoe_scale, 0.07 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(cuff_p)
		cuff_p.position = Vector3(0.0, -leg_len + 0.09, -0.06 * shoe_scale)
	elif elemental_wet:
		## Tidefin side fins — water theme VFX only; collision grounded.
		var fin_w := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.1 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			hydro
		)
		leg.add_child(fin_w)
		fin_w.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, 0.02 * shoe_scale)
		var cuff_w := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.08 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(cuff_w)
		cuff_w.position = Vector3(0.0, -leg_len + 0.09, -0.04 * shoe_scale)
	elif elemental_dive:
		## Kelpjet sub canopy + rear thruster nubs (grounded).
		var canopy := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.09 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(canopy)
		canopy.position = Vector3(0.0, -leg_len + 0.08, 0.0)
		var jet_k := _mesh_box(
			Vector3(0.05 * ws * shoe_scale, 0.06 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			hydro
		)
		leg.add_child(jet_k)
		jet_k.position = Vector3(side * 0.08 * ws * shoe_scale, -leg_len + 0.02, -0.14 * shoe_scale)
		var kelp := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.12 * shoe_scale, 0.05 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(kelp)
		kelp.position = Vector3(side * 0.11 * ws * shoe_scale, -leg_len + 0.05, -0.06 * shoe_scale)
	elif elemental_sand:
		## Sandstorm skim skirt + dune wing.
		var skirt_s := _mesh_box(
			Vector3(0.22 * ws * shoe_scale, 0.03 * shoe_scale, 0.2 * shoe_scale),
			Vector3.ZERO,
			sand_pad
		)
		leg.add_child(skirt_s)
		skirt_s.position = Vector3(0.0, -leg_len - 0.02, 0.02 * shoe_scale)
		var wing_s := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.1 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(wing_s)
		wing_s.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, -0.06 * shoe_scale)
	elif elemental_magma:
		## Magma heat plates + ember heel block (affinity/VFX; never phase colliders).
		var plate_m := _mesh_box(
			Vector3(0.07 * ws * shoe_scale, 0.14 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			magma_plate
		)
		leg.add_child(plate_m)
		plate_m.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, -0.08 * shoe_scale)
		var ember := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.08 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(ember)
		ember.position = Vector3(0.0, -leg_len + 0.02, -0.12 * shoe_scale)
		var cuff_m := _mesh_box(
			Vector3(0.13 * ws * shoe_scale, 0.08 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			iron
		)
		leg.add_child(cuff_m)
		cuff_m.position = Vector3(0.0, -leg_len + 0.1, -0.02 * shoe_scale)
	elif elemental_frost:
		## Snowglobe galosh bulb + ice cuff.
		var bulb_f := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.11 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			frost_pad
		)
		leg.add_child(bulb_f)
		bulb_f.position = Vector3(0.0, -leg_len + 0.02, -0.06 * shoe_scale)
		var cuff_f := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.09 * shoe_scale, 0.09 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(cuff_f)
		cuff_f.position = Vector3(0.0, -leg_len + 0.1, -0.02 * shoe_scale)
		var crystal := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.1 * shoe_scale, 0.03 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(crystal)
		crystal.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.06, 0.02 * shoe_scale)
	elif elemental_mud:
		## Mud Monster tall wader cuff + chunky heel clod.
		var wader := _mesh_box(
			Vector3(0.15 * ws * shoe_scale, 0.16 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(wader)
		wader.position = Vector3(0.0, -leg_len + 0.08, -0.04 * shoe_scale)
		var clod := _mesh_box(
			Vector3(0.18 * ws * shoe_scale, 0.06 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			mud_pad
		)
		leg.add_child(clod)
		clod.position = Vector3(0.0, -leg_len - 0.02, 0.0)
		var strap := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.12 * shoe_scale, 0.04 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(strap)
		strap.position = Vector3(side * 0.09 * ws * shoe_scale, -leg_len + 0.1, -0.02 * shoe_scale)
	elif ridiculous_boost:
		## Slipper Rockets — fuzzy cuff + rear rocket nozzles (VFX; grounded).
		var fuzzy := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.1 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(fuzzy)
		fuzzy.position = Vector3(0.0, -leg_len + 0.06, -0.02 * shoe_scale)
		var nozzle := _mesh_box(
			Vector3(0.05 * ws * shoe_scale, 0.06 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			joke_jet
		)
		leg.add_child(nozzle)
		nozzle.position = Vector3(side * 0.08 * ws * shoe_scale, -leg_len + 0.02, -0.16 * shoe_scale)
		var flame_s := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.04 * shoe_scale, 0.07 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(flame_s)
		flame_s.position = Vector3(side * 0.08 * ws * shoe_scale, -leg_len - 0.01, -0.22 * shoe_scale)
	elif ridiculous_stomp:
		## Pancake stack plates — syrup-heavy stomp silhouette.
		var cake := _mesh_box(
			Vector3(0.2 * ws * shoe_scale, 0.05 * shoe_scale, 0.18 * shoe_scale),
			Vector3.ZERO,
			pancake_mat
		)
		leg.add_child(cake)
		cake.position = Vector3(0.0, -leg_len + 0.02, 0.0)
		var cake2 := _mesh_box(
			Vector3(0.18 * ws * shoe_scale, 0.045 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(cake2)
		cake2.position = Vector3(0.0, -leg_len + 0.07, 0.0)
		var syrup := _mesh_box(
			Vector3(0.08 * ws * shoe_scale, 0.1 * shoe_scale, 0.05 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(syrup)
		syrup.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, -0.1 * shoe_scale)
	elif ridiculous_reach:
		## Bubblegum stilts — tall shaft + gum bubble cuff.
		var shaft := _mesh_box(
			Vector3(0.08 * ws * shoe_scale, 0.22 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			gum_mat
		)
		leg.add_child(shaft)
		shaft.position = Vector3(0.0, -leg_len + 0.12, -0.04 * shoe_scale)
		var bubble := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.1 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(bubble)
		bubble.position = Vector3(0.0, -leg_len + 0.02, 0.02 * shoe_scale)
		var stick := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.08 * shoe_scale, 0.03 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(stick)
		stick.position = Vector3(side * 0.09 * ws * shoe_scale, -leg_len + 0.08, 0.0)
	elif ridiculous_caffeine:
		## Espresso Jet Socks — slim sock shaft + dual espresso thrusters.
		var sock := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.14 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(sock)
		sock.position = Vector3(0.0, -leg_len + 0.08, -0.02 * shoe_scale)
		var jet_e := _mesh_box(
			Vector3(0.045 * ws * shoe_scale, 0.055 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			joke_jet
		)
		leg.add_child(jet_e)
		jet_e.position = Vector3(side * 0.08 * ws * shoe_scale, -leg_len + 0.01, -0.14 * shoe_scale)
		var crema := _mesh_box(
			Vector3(0.1 * ws * shoe_scale, 0.04 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(crema)
		crema.position = Vector3(0.0, -leg_len + 0.14, -0.02 * shoe_scale)
	elif ridiculous_drift:
		## Sofa Surfers — cushion block + armrest wing.
		var cushion := _mesh_box(
			Vector3(0.2 * ws * shoe_scale, 0.1 * shoe_scale, 0.18 * shoe_scale),
			Vector3.ZERO,
			sofa_mat
		)
		leg.add_child(cushion)
		cushion.position = Vector3(0.0, -leg_len + 0.02, 0.0)
		var armrest := _mesh_box(
			Vector3(0.05 * ws * shoe_scale, 0.12 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(armrest)
		armrest.position = Vector3(side * 0.11 * ws * shoe_scale, -leg_len + 0.06, -0.04 * shoe_scale)
		var pillow := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.06 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(pillow)
		pillow.position = Vector3(0.0, -leg_len + 0.1, -0.08 * shoe_scale)
	elif ridiculous_trick:
		## Banana Boomerang Cleats — curved peel wing + cleat nubs.
		var peel := _mesh_box(
			Vector3(0.05 * ws * shoe_scale, 0.08 * shoe_scale, 0.2 * shoe_scale),
			Vector3.ZERO,
			banana_mat
		)
		leg.add_child(peel)
		peel.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, 0.02 * shoe_scale)
		var peel2 := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.06 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(peel2)
		peel2.position = Vector3(side * -0.06 * ws * shoe_scale, -leg_len + 0.02, -0.08 * shoe_scale)
		var cleat := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.05 * shoe_scale, 0.03 * shoe_scale),
			Vector3.ZERO,
			spike
		)
		leg.add_child(cleat)
		cleat.position = Vector3(side * 0.05 * ws * shoe_scale, -leg_len - 0.05, 0.08 * shoe_scale)
	elif crossover_soft:
		## Lifeling Lopers — soft leaf cuff + archive loop (original tribute).
		var leaf := _mesh_box(
			Vector3(0.05 * ws * shoe_scale, 0.12 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			life_mat
		)
		leg.add_child(leaf)
		leaf.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, 0.0)
		var loop_l := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.04 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(loop_l)
		loop_l.position = Vector3(0.0, -leg_len + 0.1, -0.04 * shoe_scale)
	elif crossover_heavy:
		## Fossil Footsteps — sediment plates + chunky heel.
		var plate_f := _mesh_box(
			Vector3(0.08 * ws * shoe_scale, 0.14 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			fossil_mat
		)
		leg.add_child(plate_f)
		plate_f.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, -0.08 * shoe_scale)
		var heel_f := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.1 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(heel_f)
		heel_f.position = Vector3(0.0, -leg_len + 0.02, -0.1 * shoe_scale)
		var ridge := _mesh_box(
			Vector3(0.18 * ws * shoe_scale, 0.03 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(ridge)
		ridge.position = Vector3(0.0, -leg_len + 0.1, -0.04 * shoe_scale)
	elif crossover_tap:
		## BeatLink Tapstep Oxfords — slim oxford cuff + brass tap plate.
		var oxford := _mesh_box(
			Vector3(0.13 * ws * shoe_scale, 0.1 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(oxford)
		oxford.position = Vector3(0.0, -leg_len + 0.06, -0.02 * shoe_scale)
		var tap_plate := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.025 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			tap_mat
		)
		leg.add_child(tap_plate)
		tap_plate.position = Vector3(0.0, -leg_len - 0.02, 0.08 * shoe_scale)
		var lace := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.08 * shoe_scale, 0.03 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(lace)
		lace.position = Vector3(side * 0.08 * ws * shoe_scale, -leg_len + 0.08, 0.02 * shoe_scale)
	elif crossover_bass:
		## BeatLink Bassline Boots — tall boot shaft + bass woofer heel.
		var boot_b := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.16 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(boot_b)
		boot_b.position = Vector3(0.0, -leg_len + 0.08, -0.04 * shoe_scale)
		var woofer := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.05 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			bass_mat
		)
		leg.add_child(woofer)
		woofer.position = Vector3(0.0, -leg_len - 0.01, -0.08 * shoe_scale)
		var cone := _mesh_box(
			Vector3(0.1 * ws * shoe_scale, 0.04 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(cone)
		cone.position = Vector3(0.0, -leg_len + 0.04, -0.08 * shoe_scale)
	elif crossover_circuit:
		## WAIKE Circuit Clogs — clog block + circuit trace fin.
		var clog := _mesh_box(
			Vector3(0.18 * ws * shoe_scale, 0.08 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(clog)
		clog.position = Vector3(0.0, -leg_len + 0.02, 0.0)
		var trace := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.1 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			circuit_mat
		)
		leg.add_child(trace)
		trace.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, -0.02 * shoe_scale)
		var chip := _mesh_box(
			Vector3(0.08 * ws * shoe_scale, 0.04 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(chip)
		chip.position = Vector3(0.0, -leg_len + 0.1, -0.04 * shoe_scale)
	elif crossover_portal:
		## 3k MLV Portal Pumps — portal ring heel (VFX; never phase colliders).
		var ring_p := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.03 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			portal_mat
		)
		leg.add_child(ring_p)
		ring_p.position = Vector3(0.0, -leg_len + 0.08, -0.06 * shoe_scale)
		var ring_p2 := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.025 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(ring_p2)
		ring_p2.position = Vector3(0.0, -leg_len + 0.12, -0.06 * shoe_scale)
		var pump := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.08 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(pump)
		pump.position = Vector3(0.0, -leg_len + 0.02, 0.02 * shoe_scale)
	elif crossover_gyro:
		## Edge I/O Gyrowraps — wrap straps + gyro disc.
		var wrap := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.14 * shoe_scale, 0.18 * shoe_scale),
			Vector3.ZERO,
			gyro_mat
		)
		leg.add_child(wrap)
		wrap.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, 0.0)
		var disc_g := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.03 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(disc_g)
		disc_g.position = Vector3(0.0, -leg_len - 0.01, -0.04 * shoe_scale)
		var hub := _mesh_box(
			Vector3(0.08 * ws * shoe_scale, 0.05 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(hub)
		hub.position = Vector3(0.0, -leg_len + 0.06, -0.04 * shoe_scale)
	elif tribute_ember:
		## Cinderstride — ember fins (original Pedestrian procedural sole).
		var ember_fin := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.12 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			ember_mat
		)
		leg.add_child(ember_fin)
		ember_fin.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, -0.04 * shoe_scale)
		var cuff_e := _mesh_box(
			Vector3(0.13 * ws * shoe_scale, 0.09 * shoe_scale, 0.09 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(cuff_e)
		cuff_e.position = Vector3(0.0, -leg_len + 0.09, -0.02 * shoe_scale)
	elif tribute_bastion:
		## Bastion Stomp — heavy side plates + heel block.
		var plate_b := _mesh_box(
			Vector3(0.07 * ws * shoe_scale, 0.15 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			bastion_mat
		)
		leg.add_child(plate_b)
		plate_b.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.04, -0.08 * shoe_scale)
		var heel_b := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.1 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(heel_b)
		heel_b.position = Vector3(0.0, -leg_len + 0.02, -0.1 * shoe_scale)
	elif tribute_volt:
		## Voltstep Coils — coil rings + spark cuff.
		var coil := _mesh_box(
			Vector3(0.15 * ws * shoe_scale, 0.03 * shoe_scale, 0.15 * shoe_scale),
			Vector3.ZERO,
			volt_mat
		)
		leg.add_child(coil)
		coil.position = Vector3(0.0, -leg_len + 0.08, -0.04 * shoe_scale)
		var coil2 := _mesh_box(
			Vector3(0.11 * ws * shoe_scale, 0.025 * shoe_scale, 0.11 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(coil2)
		coil2.position = Vector3(0.0, -leg_len + 0.12, -0.04 * shoe_scale)
		var spark := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.1 * shoe_scale, 0.04 * shoe_scale),
			Vector3.ZERO,
			volt_mat
		)
		leg.add_child(spark)
		spark.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, 0.02 * shoe_scale)
	elif tribute_gale:
		## Galeleaf Gliders — leaf wing + slim ankle.
		var leaf_g := _mesh_box(
			Vector3(0.05 * ws * shoe_scale, 0.12 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			gale_mat
		)
		leg.add_child(leaf_g)
		leaf_g.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, 0.0)
		var ankle_g := _mesh_box(
			Vector3(0.11 * ws * shoe_scale, 0.08 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(ankle_g)
		ankle_g.position = Vector3(0.0, -leg_len + 0.09, -0.04 * shoe_scale)
	elif tribute_azure:
		## Azure Bastions — blue brace plates (distinct from Bastion Stomp).
		var brace := _mesh_box(
			Vector3(0.06 * ws * shoe_scale, 0.14 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			azure_mat
		)
		leg.add_child(brace)
		brace.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, -0.04 * shoe_scale)
		var cuff_a := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.08 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(cuff_a)
		cuff_a.position = Vector3(0.0, -leg_len + 0.1, -0.02 * shoe_scale)
		var toe_a := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.04 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			azure_mat
		)
		leg.add_child(toe_a)
		toe_a.position = Vector3(0.0, -leg_len - 0.01, 0.12 * shoe_scale)
	elif tribute_orbit:
		## Orbitwalkers — dual heel rings (VFX; grounded collision).
		var ring_o := _mesh_box(
			Vector3(0.16 * ws * shoe_scale, 0.03 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			orbit_mat
		)
		leg.add_child(ring_o)
		ring_o.position = Vector3(0.0, -leg_len + 0.07, -0.06 * shoe_scale)
		var ring_o2 := _mesh_box(
			Vector3(0.12 * ws * shoe_scale, 0.025 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(ring_o2)
		ring_o2.position = Vector3(0.0, -leg_len + 0.11, -0.06 * shoe_scale)
	elif tribute_echo:
		## Phase Echoes — veil fins; NEVER phase-through colliders.
		var veil := _mesh_box(
			Vector3(0.04 * ws * shoe_scale, 0.12 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			echo_mat
		)
		leg.add_child(veil)
		veil.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, -0.06 * shoe_scale)
		var echo_trail := _mesh_box(
			Vector3(0.03 * ws * shoe_scale, 0.08 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(echo_trail)
		echo_trail.position = Vector3(side * -0.05 * ws * shoe_scale, -leg_len + 0.03, -0.12 * shoe_scale)
	elif tribute_null:
		## Nullstep — matte void block + thin rail.
		var void_b := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.1 * shoe_scale, 0.14 * shoe_scale),
			Vector3.ZERO,
			null_mat
		)
		leg.add_child(void_b)
		void_b.position = Vector3(0.0, -leg_len + 0.04, -0.02 * shoe_scale)
		var rail_n := _mesh_box(
			Vector3(0.02 * ws * shoe_scale, 0.08 * shoe_scale, 0.16 * shoe_scale),
			Vector3.ZERO,
			midsole
		)
		leg.add_child(rail_n)
		rail_n.position = Vector3(side * 0.09 * ws * shoe_scale, -leg_len + 0.04, 0.0)
	elif tribute_radiant:
		## Radiant Order — crest plate + radiant heel flare.
		var crest := _mesh_box(
			Vector3(0.08 * ws * shoe_scale, 0.12 * shoe_scale, 0.08 * shoe_scale),
			Vector3.ZERO,
			radiant_mat
		)
		leg.add_child(crest)
		crest.position = Vector3(0.0, -leg_len + 0.1, 0.02 * shoe_scale)
		var flare_r := _mesh_box(
			Vector3(0.05 * ws * shoe_scale, 0.1 * shoe_scale, 0.12 * shoe_scale),
			Vector3.ZERO,
			upper
		)
		leg.add_child(flare_r)
		flare_r.position = Vector3(side * 0.1 * ws * shoe_scale, -leg_len + 0.05, -0.08 * shoe_scale)
		var heel_r := _mesh_box(
			Vector3(0.14 * ws * shoe_scale, 0.08 * shoe_scale, 0.1 * shoe_scale),
			Vector3.ZERO,
			radiant_mat
		)
		leg.add_child(heel_r)
		heel_r.position = Vector3(0.0, -leg_len + 0.02, -0.1 * shoe_scale)
	if is_left:
		_shoe_l = sole
		_heel_l = heel
	else:
		_shoe_r = sole
		_heel_r = heel


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
		"jump":
			if _torso:
				_torso.rotation.x = lerpf(_torso.rotation.x, -0.15, delta * 10.0)
			if _leg_l:
				_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.55, delta * 10.0)
			if _leg_r:
				_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.55, delta * 10.0)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -1.2, delta * 10.0)
			if _arm_r:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.2, delta * 10.0)
		"trick":
			if _torso:
				_torso.rotation.y = sin(_emotion_t * 14.0) * 0.55
				_torso.rotation.x = lerpf(_torso.rotation.x, -0.35, delta * 8.0)
			if _arm_l:
				_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 1.1, delta * 8.0)
			if _arm_r:
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -1.1, delta * 8.0)
		"drift":
			if _torso:
				_torso.rotation.z = lerpf(_torso.rotation.z, -0.42, delta * 9.0)
				_torso.rotation.x = lerpf(_torso.rotation.x, -0.12, delta * 8.0)
			if _leg_l:
				_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.35, delta * 8.0)
			if _arm_r:
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.55, delta * 8.0)
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
