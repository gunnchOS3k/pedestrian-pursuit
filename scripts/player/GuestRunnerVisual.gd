extends Node3D

## Skinned GLB presentation for Anime Aggressors guest runners.
## Same public pose API as RacerVisual. Physics stay on PlayerController.

const RunnerProfileScript = preload("res://scripts/data/RunnerProfile.gd")
const RunnerIdsScript = preload("res://scripts/data/RunnerIds.gd")
const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")
const RacerDataScript = preload("res://scripts/data/RacerData.gd")

const WEAPON_EXACT := {
	"1H_Wand": true,
	"2H_Staff": true,
	"Spellbook": true,
	"Spellbook_open": true,
	"1H_Axe": true,
	"1H_Axe_Offhand": true,
	"2H_Axe": true,
	"1H_Sword": true,
	"1H_Sword_Offhand": true,
	"2H_Sword": true,
	"Shield": true,
	"1H_Dagger": true,
	"1H_Dagger_Offhand": true,
	"1H_Crossbow": true,
	"2H_Crossbow": true,
	"1H_Bow": true,
	"2H_Bow": true,
	"Focus": true,
}

const WEAPON_PREFIXES := ["1H_", "2H_"]
const WEAPON_SUBSTR := ["Staff", "Wand", "Axe", "Sword", "Dagger", "Crossbow", "Spellbook", "Blade"]

const FOOT_SOCKETS := ["foot_l", "foot_r", "Foot_L", "Foot_R"]

@export var runner_id: String = "ember_vale"
@export var is_ai: bool = false

var profile: RunnerProfile
var _parent_body: CharacterBody3D
var _model: Node3D
var _anim: AnimationPlayer
var _name_label: Label3D
var _boost_fx: GPUParticles3D
var _afterimage: MeshInstance3D
var _menu_preview: bool = false
var _boosting: bool = false
var _pose_state: String = "idle"
var _pose_timer: float = 0.0
var _hidden_weapons: PackedStringArray = PackedStringArray()
var _shoe_overlays: Array[Node3D] = []
var _current_shoe_id: String = ""
var _emotion_t: float = 0.0
var _last_clip: String = ""


func _ready() -> void:
	_parent_body = get_parent() as CharacterBody3D
	_hide_legacy_meshes()
	if profile == null:
		apply_profile(RunnerProfileScript.by_id(runner_id))


func apply_profile(p: RunnerProfile) -> void:
	profile = p
	runner_id = p.id
	_rebuild()


func set_menu_preview(enabled: bool) -> void:
	_menu_preview = enabled
	_parent_body = null if enabled else (get_parent() as CharacterBody3D)
	if enabled:
		_pose_state = "selection_pose"
		_pose_timer = 0.0
		_boosting = false
		_play_mapped("selection_pose")


func set_pose_state(state: String, duration: float = 0.45) -> void:
	_pose_state = state
	_pose_timer = duration
	_play_mapped(_locomotion_state_from_pose(state))


func set_boosting(active: bool) -> void:
	_boosting = active
	if _boost_fx:
		_boost_fx.emitting = active
	if _afterimage:
		_afterimage.visible = active
	if active:
		_play_mapped("boost")


func play_start_line() -> void:
	set_pose_state(str(profile.start_pose if profile else "idle"), 1.2)
	_play_mapped("selection_pose")


func play_stumble() -> void:
	set_pose_state(str(profile.stumble_style if profile else "stumble"), 0.55)
	_play_mapped("stumble")


func play_recovery() -> void:
	set_pose_state(str(profile.recovery_style if profile else "recovery"), 0.7)
	_play_mapped("recovery")


func play_finish(won: bool) -> void:
	if won:
		set_pose_state(str(profile.finish_style if profile else "finish_victory"), 2.0)
		_play_mapped("finish_victory")
	else:
		set_pose_state("defeat", 2.0)
		_play_mapped("finish_defeat")


func hidden_weapon_names() -> PackedStringArray:
	return _hidden_weapons


func current_animation_name() -> String:
	if _anim == null:
		return ""
	return _anim.current_animation


func footwear_overlay_count() -> int:
	return _shoe_overlays.size()


func _hide_legacy_meshes() -> void:
	if _parent_body == null:
		return
	for name in ["BodyMesh", "ShoeMesh"]:
		var node := _parent_body.get_node_or_null(name)
		if node is MeshInstance3D:
			(node as MeshInstance3D).visible = false


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_model = null
	_anim = null
	_name_label = null
	_boost_fx = null
	_afterimage = null
	_hidden_weapons = PackedStringArray()
	_shoe_overlays.clear()
	if profile == null:
		return
	var path := str(profile.model_asset_path)
	if path.is_empty():
		path = "res://assets/models/guest_runners/%s/%s.glb" % [profile.id, profile.id]
	if not ResourceLoader.exists(path):
		push_warning("GuestRunnerVisual: missing model %s" % path)
		_add_name_label()
		return
	var packed = load(path)
	if packed == null:
		push_warning("GuestRunnerVisual: failed to load %s" % path)
		_add_name_label()
		return
	_model = packed.instantiate() as Node3D
	if _model == null:
		_add_name_label()
		return
	_model.name = "GuestModel"
	_model.rotation_degrees.y = 180.0
	_model.scale = Vector3.ONE * _height_to_scale()
	add_child(_model)
	_anim = _find_anim(_model)
	_hidden_weapons = _hide_combat_props(_model)
	_attach_footwear(_model)
	_build_boost_vfx()
	_add_name_label()
	if _menu_preview:
		_play_mapped("selection_pose")
	else:
		_play_mapped("idle")


func _height_to_scale() -> float:
	var hs := profile.height_scale if profile else 1.0
	return clampf(0.92 * hs, 0.78, 1.15)


func _find_anim(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_anim(child)
		if found != null:
			return found
	return null


func _is_weapon_node(node: Node) -> bool:
	var nm := str(node.name)
	if WEAPON_EXACT.has(nm):
		return true
	for prefix in WEAPON_PREFIXES:
		if nm.begins_with(prefix):
			return true
	for token in WEAPON_SUBSTR:
		if nm.findn(token) >= 0:
			return true
	return false


func _hide_combat_props(root: Node) -> PackedStringArray:
	var hidden := PackedStringArray()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node == root:
			continue
		if _is_weapon_node(node):
			if node is Node3D:
				(node as Node3D).visible = false
			hidden.append(str(node.name))
	return hidden


func _attach_footwear(root: Node) -> void:
	_shoe_overlays.clear()
	var shoe_id := _resolve_shoe_id()
	_current_shoe_id = shoe_id
	var shoe := ShoeDataScript.load_by_id(shoe_id)
	var accent := profile.accent_color if profile else Color(1.0, 0.35, 0.2)
	var feet: Array[Node3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if str(node.name) in FOOT_SOCKETS and node is Node3D:
			feet.append(node)
	if feet.is_empty():
		_attach_fallback_sole_layer(accent, shoe)
		return
	for foot in feet:
		var overlay := _make_shoe_overlay(accent, shoe)
		foot.add_child(overlay)
		_shoe_overlays.append(overlay)


func _attach_fallback_sole_layer(accent: Color, shoe: Dictionary) -> void:
	var layer := Node3D.new()
	layer.name = "FootwearEffectLayer"
	layer.position = Vector3(0.0, 0.04, 0.0)
	add_child(layer)
	var left := _make_shoe_overlay(accent, shoe)
	left.position = Vector3(-0.1, 0.0, 0.08)
	layer.add_child(left)
	var right := _make_shoe_overlay(accent, shoe)
	right.position = Vector3(0.1, 0.0, 0.08)
	layer.add_child(right)
	_shoe_overlays.append(left)
	_shoe_overlays.append(right)


func _make_shoe_overlay(accent: Color, shoe: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = "ShoeOverlay"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = accent
	mat.emission_energy_multiplier = 0.35
	var sole := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.05, 0.28)
	sole.mesh = box
	sole.material_override = mat
	sole.position = Vector3(0.0, -0.02, 0.06)
	holder.add_child(sole)
	var heel := MeshInstance3D.new()
	var heel_box := BoxMesh.new()
	heel_box.size = Vector3(0.13, 0.07, 0.1)
	heel.mesh = heel_box
	var heel_mat := StandardMaterial3D.new()
	heel_mat.albedo_color = accent.darkened(0.35)
	heel.material_override = heel_mat
	heel.position = Vector3(0.0, -0.01, -0.08)
	holder.add_child(heel)
	var tag := Label3D.new()
	tag.text = str(shoe.get("display_name", _current_shoe_id))
	tag.font_size = 10
	tag.position = Vector3(0.0, 0.12, 0.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1, 1, 1, 0.0)
	holder.add_child(tag)
	return holder


func _resolve_shoe_id() -> String:
	if _parent_body != null and "shoe_id" in _parent_body:
		var sid := str(_parent_body.get("shoe_id"))
		if not sid.is_empty():
			return sid
	var gm := _game_manager()
	if gm != null and "selected_shoe_id" in gm:
		var selected := str(gm.get("selected_shoe_id"))
		if not selected.is_empty():
			return selected
	var stats := RacerDataScript.load_by_id(runner_id)
	return str(stats.get("default_shoe_id", "starter_soles"))


func _game_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameManager")


func _build_boost_vfx() -> void:
	var style := str(profile.boost_vfx if profile else "warm_sole_glow")
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, -1)
	mat.spread = 18.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.8
	mat.gravity = Vector3(0, -1.2, 0)
	mat.scale_min = 0.04
	mat.scale_max = 0.12
	match style:
		"warm_sole_glow":
			mat.color = Color(1.0, 0.45, 0.12, 0.85)
		"ground_pressure_dust":
			mat.color = Color(0.55, 0.42, 0.28, 0.7)
			mat.direction = Vector3(0, 0.35, 0)
		"electric_heel_trace":
			mat.color = Color(0.85, 0.95, 0.2, 0.9)
		"wind_ribbon":
			mat.color = Color(0.55, 0.95, 0.75, 0.65)
			mat.direction = Vector3(0, 0.2, -1)
		"frost_sole_trace":
			mat.color = Color(0.7, 0.9, 1.0, 0.8)
		"constellation_orbit":
			mat.color = Color(0.75, 0.65, 1.0, 0.8)
		"ghost_afterimage":
			mat.color = Color(0.7, 0.55, 0.95, 0.45)
		_:
			mat.color = Color(1.0, 0.8, 0.3, 0.7)
	_boost_fx = GPUParticles3D.new()
	_boost_fx.name = "BoostSoleVfx"
	_boost_fx.emitting = false
	_boost_fx.amount = 18
	_boost_fx.lifetime = 0.35
	_boost_fx.position = Vector3(0.0, 0.08, -0.15)
	_boost_fx.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.04
	draw.height = 0.08
	_boost_fx.draw_pass_1 = draw
	add_child(_boost_fx)
	if style == "ghost_afterimage":
		_afterimage = MeshInstance3D.new()
		var ghost := CapsuleMesh.new()
		ghost.radius = 0.18
		ghost.height = 1.2
		_afterimage.mesh = ghost
		var gmat := StandardMaterial3D.new()
		gmat.albedo_color = Color(0.55, 0.4, 0.8, 0.22)
		gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_afterimage.material_override = gmat
		_afterimage.position = Vector3(0.0, 0.8, 0.35)
		_afterimage.visible = false
		add_child(_afterimage)


func _add_name_label() -> void:
	_name_label = Label3D.new()
	_name_label.text = profile.display_name if profile else "Guest"
	_name_label.font_size = 26
	_name_label.modulate = Color(1, 1, 1, 0.9)
	_name_label.position = Vector3(0, 2.15, 0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.outline_modulate = Color(0, 0, 0, 0.8)
	_name_label.outline_size = 4
	add_child(_name_label)


func _clip_for_state(state: String) -> String:
	match state:
		"walk":
			return "walk"
		"run", "jump", "boost":
			return "run"
		"stumble", "finish_defeat":
			return "hurt_heavy"
		"recovery":
			return "walk"
		"finish_victory", "selection_pose", "idle":
			return "idle"
		_:
			return "idle"


func _locomotion_state_from_pose(pose: String) -> String:
	if pose in ["stutter", "catch", "roll", "soft", "rock", "comic_spin", "foot_box", "stutter_lock"]:
		return "stumble"
	if pose in ["jog", "reaccel", "flip_up", "tempo", "drive", "laugh_jog", "line_rejoin", "assisted"]:
		return "recovery"
	if pose in ["arms_up", "spike_cheer", "open_arms", "fist_chest", "dance", "salute", "ring_expand", "backflip_flash"]:
		return "finish_victory"
	if pose == "defeat":
		return "finish_defeat"
	if pose in ["lace_check", "coiled", "scan", "breathe", "stamp", "showboat", "visualize", "charge"]:
		return "selection_pose"
	if pose in ["forward_lean", "snap_lean", "wall_lean", "float_lean", "shoulder_drive", "spin_lean", "banked_lean", "kinetic_flare", "heat_trail", "ground_pulse", "electric_trace", "wind_ribbon", "frost_trace", "constellation_trail", "ghost_afterimage", "boost"]:
		return "boost"
	return "idle"


func _play_mapped(state: String) -> void:
	if _anim == null:
		return
	var clip := _clip_for_state(state)
	if not _anim.has_animation(clip):
		if _anim.has_animation("idle"):
			clip = "idle"
		else:
			return
	if _last_clip == clip and _anim.is_playing():
		if state == "boost":
			_anim.speed_scale = 1.35
		return
	_last_clip = clip
	_anim.speed_scale = 1.35 if state == "boost" else 1.0
	_anim.play(clip)


func _process(delta: float) -> void:
	_emotion_t += delta
	if _pose_timer > 0.0:
		_pose_timer -= delta
		if _pose_timer <= 0.0 and _pose_state not in ["idle", "selection_pose"]:
			_pose_state = "idle"
	if _afterimage and _afterimage.visible:
		_afterimage.position.z = 0.28 + 0.08 * sin(_emotion_t * 8.0)
		_afterimage.modulate.a = 0.18 + 0.08 * sin(_emotion_t * 10.0)
	if _menu_preview:
		if _pose_state == "idle" or _pose_state == "selection_pose":
			_play_mapped("selection_pose")
		return
	var speed := 0.0
	var grounded := true
	if _parent_body != null:
		speed = _parent_body.velocity.length()
		if _parent_body.has_method("is_on_floor"):
			grounded = _parent_body.is_on_floor()
	if _pose_timer > 0.0 and _pose_state not in ["idle", "boost"] and not _boosting:
		return
	if _boosting:
		_play_mapped("boost")
		return
	if not grounded:
		_play_mapped("jump")
		return
	if speed > 4.0:
		_play_mapped("run")
	elif speed > 0.45:
		_play_mapped("walk")
	else:
		_play_mapped("idle")
