extends Control

## Labs / Character Review → Anime Aggressors Guest Runners
## Presentation only. No combat buttons.

const _RunnerProfile = preload("res://scripts/data/RunnerProfile.gd")
const RunnerIdsScript = preload("res://scripts/data/RunnerIds.gd")
const RunnerVisualResolver = preload("res://scripts/player/RunnerVisualResolver.gd")
const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")

const REVIEW_STATES := [
	"idle", "walk", "run", "jump", "boost", "stumble", "recovery", "finish_victory", "finish_defeat", "selection_pose"
]

var _guests: Array = []
var _index: int = 0
var _state_index: int = 0
var _yaw: float = 0.0
var _speed_scale: float = 1.0
var _visual: Node3D
var _caption: Label
var _meta: Label
var _shoe_index: int = 0
var _world: Node3D
var _time_scale_button: Button


func _ready() -> void:
	_build_ui()
	for rid in RunnerIdsScript.GUEST_RUNNER_IDS:
		_guests.append(_RunnerProfile.by_id(rid))
	if _guests.is_empty():
		_caption.text = "No guest runners loaded."
		return
	_show_current()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.12, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var host := SubViewportContainer.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.anchor_bottom = 0.72
	host.stretch = true
	add_child(host)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(1280, 520)
	host.add_child(vp)
	_world = Node3D.new()
	vp.add_child(_world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	light.light_energy = 1.15
	_world.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(1.5, 1.4, 2.7)
	cam.look_at(Vector3(0, 0.95, 0))
	cam.current = true
	_world.add_child(cam)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.1, 0.12, 0.12)
	floor_mesh.material_override = floor_mat
	_world.add_child(floor_mesh)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 0.72
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = 8
	panel.offset_bottom = -12
	panel.add_theme_constant_override("separation", 8)
	add_child(panel)

	var title := Label.new()
	title.text = "Labs / Character Review  ·  Anime Aggressors Guest Runners"
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)

	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 18)
	panel.add_child(_caption)

	_meta = Label.new()
	_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meta.add_theme_font_size_override("font_size", 13)
	panel.add_child(_meta)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_btn(row, "Previous Runner", _prev)
	_btn(row, "Next Runner", _next)
	_btn(row, "Front", func(): _set_yaw(0.0))
	_btn(row, "Rear", func(): _set_yaw(180.0))
	_time_scale_button = _btn(row, "1.0x", _toggle_speed)
	_btn(row, "Next State", _next_state)
	_btn(row, "Next Shoe", _next_shoe)
	_btn(row, "Back to Menu", func(): SceneLoader.go_to_main_menu())


func _btn(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _show_current() -> void:
	if _guests.is_empty():
		return
	var profile = _guests[_index]
	if _visual != null:
		_visual.queue_free()
		_visual = null
	_visual = Node3D.new()
	_visual.name = "RacerVisual"
	_world.add_child(_visual)
	_visual = RunnerVisualResolver.attach(_visual, profile)
	if _visual.has_method("set_menu_preview"):
		_visual.set_menu_preview(true)
	_apply_state()
	_apply_yaw()
	_caption.text = "%s  ·  %s" % [profile.display_name, REVIEW_STATES[_state_index]]
	_meta.text = (
		"%s\nArchetype: %s  ·  Footwear preview: %s\n%s"
		% [
			RunnerIdsScript.DEV_REVIEW_LABEL,
			str(profile.archetype).replace("_", " "),
			ShoeDataScript.all_ids()[_shoe_index],
			str(profile.tagline),
		]
	)
	Engine.time_scale = _speed_scale


func _apply_state() -> void:
	if _visual == null:
		return
	var state: String = str(REVIEW_STATES[_state_index])
	match state:
		"boost":
			if _visual.has_method("set_boosting"):
				_visual.set_boosting(true)
		"stumble":
			if _visual.has_method("play_stumble"):
				_visual.play_stumble()
		"recovery":
			if _visual.has_method("play_recovery"):
				_visual.play_recovery()
		"finish_victory":
			if _visual.has_method("play_finish"):
				_visual.play_finish(true)
		"finish_defeat":
			if _visual.has_method("play_finish"):
				_visual.play_finish(false)
		_:
			if _visual.has_method("set_boosting"):
				_visual.set_boosting(false)
			if _visual.has_method("set_pose_state"):
				_visual.set_pose_state(state, 2.4)


func _apply_yaw() -> void:
	if _visual:
		_visual.rotation_degrees.y = _yaw


func _set_yaw(value: float) -> void:
	_yaw = value
	_apply_yaw()


func _prev() -> void:
	_index = (_index - 1 + _guests.size()) % _guests.size()
	_show_current()


func _next() -> void:
	_index = (_index + 1) % _guests.size()
	_show_current()


func _next_state() -> void:
	_state_index = (_state_index + 1) % REVIEW_STATES.size()
	_apply_state()
	if not _guests.is_empty():
		_caption.text = "%s  ·  %s" % [_guests[_index].display_name, REVIEW_STATES[_state_index]]


func _toggle_speed() -> void:
	_speed_scale = 0.5 if is_equal_approx(_speed_scale, 1.0) else 1.0
	Engine.time_scale = _speed_scale
	if _time_scale_button:
		_time_scale_button.text = "0.5x" if _speed_scale < 1.0 else "1.0x"


func _next_shoe() -> void:
	var shoes := ShoeDataScript.all_ids()
	_shoe_index = (_shoe_index + 1) % shoes.size()
	if GameManager != null:
		GameManager.selected_shoe_id = shoes[_shoe_index]
	_show_current()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
