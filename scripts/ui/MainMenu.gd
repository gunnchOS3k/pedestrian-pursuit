extends Control
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _RunnerProfile = preload("res://scripts/data/RunnerProfile.gd")
const _RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")

## Main menu — pick a runner, device role, accessibility, start cup or practice.

var _cup: Dictionary = {}
var _tracks: Array[Dictionary] = []
var _roster: Array = []
var _preview_visual: Node3D

@onready var course_picker: OptionButton = $VBox/CoursePicker
@onready var description_label: Label = $VBox/Description
@onready var runner_picker: OptionButton = $VBox/RunnerPicker
@onready var runner_info_label: Label = $VBox/RunnerInfo
@onready var preview_host: SubViewportContainer = $VBox/PreviewHost
@onready var preview_viewport: SubViewport = $VBox/PreviewHost/SubViewport

var _device_picker: OptionButton
var _device_hint: Label
var _a11y_reduce: CheckButton
var _a11y_larger: CheckButton
var _a11y_auto: CheckButton
var _a11y_colorblind: CheckButton


func _ready() -> void:
	$VBox/StartCupButton.pressed.connect(_on_start_cup)
	$VBox/SingleRaceButton.pressed.connect(_on_start_single)
	$VBox/QuitButton.pressed.connect(_on_quit)
	course_picker.item_selected.connect(_on_course_selected)
	runner_picker.item_selected.connect(_on_runner_selected)
	_setup_preview_viewport()
	_ensure_settings_ui()
	_load_content()
	_populate_device_picker()
	_sync_a11y_toggles()


func _ensure_settings_ui() -> void:
	var vbox: VBoxContainer = $VBox
	if vbox.get_node_or_null("DeviceLabel") != null:
		_device_picker = vbox.get_node("DevicePicker")
		_device_hint = vbox.get_node("DeviceHint")
		_a11y_reduce = vbox.get_node("A11yReduceMotion")
		_a11y_larger = vbox.get_node("A11yLargerUI")
		_a11y_auto = vbox.get_node("A11yAutoAccel")
		_a11y_colorblind = vbox.get_node("A11yColorblind")
		return

	var insert_at: int = vbox.get_node("Hint").get_index()

	var device_label := Label.new()
	device_label.name = "DeviceLabel"
	device_label.text = "Device Role"
	device_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	device_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(device_label)
	vbox.move_child(device_label, insert_at)
	insert_at += 1

	_device_picker = OptionButton.new()
	_device_picker.name = "DevicePicker"
	_device_picker.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_device_picker)
	vbox.move_child(_device_picker, insert_at)
	insert_at += 1
	_device_picker.item_selected.connect(_on_device_selected)

	_device_hint = Label.new()
	_device_hint.name = "DeviceHint"
	_device_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_device_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_device_hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_device_hint)
	vbox.move_child(_device_hint, insert_at)
	insert_at += 1

	var a11y_label := Label.new()
	a11y_label.name = "A11yLabel"
	a11y_label.text = "Accessibility"
	a11y_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a11y_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(a11y_label)
	vbox.move_child(a11y_label, insert_at)
	insert_at += 1

	_a11y_reduce = CheckButton.new()
	_a11y_reduce.name = "A11yReduceMotion"
	_a11y_reduce.text = "Reduce motion"
	vbox.add_child(_a11y_reduce)
	vbox.move_child(_a11y_reduce, insert_at)
	insert_at += 1
	_a11y_reduce.toggled.connect(func(v): AccessibilitySettings.set_reduce_motion(v))

	_a11y_larger = CheckButton.new()
	_a11y_larger.name = "A11yLargerUI"
	_a11y_larger.text = "Larger UI"
	vbox.add_child(_a11y_larger)
	vbox.move_child(_a11y_larger, insert_at)
	insert_at += 1
	_a11y_larger.toggled.connect(func(v): AccessibilitySettings.set_larger_ui(v))

	_a11y_auto = CheckButton.new()
	_a11y_auto.name = "A11yAutoAccel"
	_a11y_auto.text = "Auto-accelerate"
	vbox.add_child(_a11y_auto)
	vbox.move_child(_a11y_auto, insert_at)
	insert_at += 1
	_a11y_auto.toggled.connect(func(v): AccessibilitySettings.set_auto_accelerate(v))

	_a11y_colorblind = CheckButton.new()
	_a11y_colorblind.name = "A11yColorblind"
	_a11y_colorblind.text = "Colorblind-safe HUD markers"
	vbox.add_child(_a11y_colorblind)
	vbox.move_child(_a11y_colorblind, insert_at)
	_a11y_colorblind.toggled.connect(func(v): AccessibilitySettings.set_colorblind_safe_hud(v))


func _populate_device_picker() -> void:
	if _device_picker == null or DeviceRoleRuntime == null:
		return
	_device_picker.clear()
	var select_index := 0
	var ids := DeviceRoleRuntime.get_role_ids()
	for i in ids.size():
		var rid := str(ids[i])
		_device_picker.add_item(DeviceRoleRuntime.get_role_display_name(rid))
		_device_picker.set_item_metadata(i, rid)
		if rid == DeviceRoleRuntime.active_role_id:
			select_index = i
	_device_picker.select(select_index)
	_on_device_selected(select_index)


func _on_device_selected(index: int) -> void:
	if _device_picker == null or index < 0:
		return
	var rid := str(_device_picker.get_item_metadata(index))
	DeviceRoleRuntime.set_role(rid)
	if _device_hint:
		var map_id := DeviceRoleRuntime.get_map_profile_id()
		_device_hint.text = (
			"%s\nMap: %s  •  GPS: %s (simulated only)"
			% [DeviceRoleRuntime.get_input_hints(), map_id, DeviceRoleRuntime.get_gps_mode()]
		)
	var hint_node := $VBox/Hint
	if hint_node:
		hint_node.text = (
			"Active input default: %s  •  keyboard / gamepad / touch coexist"
			% DeviceRoleRuntime.get_input_default()
		)


func _sync_a11y_toggles() -> void:
	if AccessibilitySettings == null:
		return
	if _a11y_reduce:
		_a11y_reduce.set_pressed_no_signal(AccessibilitySettings.reduce_motion)
	if _a11y_larger:
		_a11y_larger.set_pressed_no_signal(AccessibilitySettings.larger_ui)
	if _a11y_auto:
		_a11y_auto.set_pressed_no_signal(AccessibilitySettings.auto_accelerate)
	if _a11y_colorblind:
		_a11y_colorblind.set_pressed_no_signal(AccessibilitySettings.colorblind_safe_hud)


func _setup_preview_viewport() -> void:
	preview_viewport.own_world_3d = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_viewport.transparent_bg = true
	var world := Node3D.new()
	world.name = "PreviewWorld"
	preview_viewport.add_child(world)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.1, 0.18, 1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	environment.ambient_light_energy = 0.85
	env.environment = environment
	world.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	light.light_energy = 1.1
	world.add_child(light)

	var cam := Camera3D.new()
	cam.position = Vector3(1.35, 1.35, -2.15)
	world.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true

	_preview_visual = Node3D.new()
	_preview_visual.set_script(_RacerVisualScript)
	_preview_visual.name = "RacerVisual"
	world.add_child(_preview_visual)
	if _preview_visual.has_method("set_menu_preview"):
		_preview_visual.set_menu_preview(true)


func _load_content() -> void:
	_roster = _RunnerProfile.load_roster()
	_cup = _TrackCatalog.load_cup()
	_tracks = _TrackCatalog.load_tracks_for_cup()
	_populate_runner_picker()
	course_picker.clear()
	for track in _tracks:
		course_picker.add_item(str(track.get("display_name", "Unknown Course")))
		course_picker.set_item_metadata(course_picker.item_count - 1, str(track.get("id", "")))
	var expected_track_count: int = _cup.get("track_ids", []).size()
	if _cup.is_empty() or _tracks.size() != expected_track_count:
		$VBox/StartCupButton.disabled = true
	if _tracks.is_empty():
		$VBox/StartCupButton.disabled = true
		$VBox/SingleRaceButton.disabled = true
		description_label.text = "Course content could not be loaded. Check the project log."
		return
	course_picker.select(0)
	_on_course_selected(0)


func _populate_runner_picker() -> void:
	runner_picker.clear()
	var preferred := str(GameManager.selected_runner_id)
	if preferred.is_empty():
		preferred = "dash_reed"
	var select_index := 0
	for i in _roster.size():
		var p = _roster[i]
		runner_picker.add_item(str(p.display_name))
		runner_picker.set_item_metadata(i, str(p.id))
		if str(p.id) == preferred:
			select_index = i
	if runner_picker.item_count == 0:
		runner_info_label.text = "No runners loaded."
		return
	runner_picker.select(select_index)
	_on_runner_selected(select_index)


func _on_runner_selected(index: int) -> void:
	if index < 0 or index >= _roster.size():
		return
	var p = _roster[index]
	GameManager.selected_runner_id = str(p.id)
	runner_info_label.text = (
		"%s  •  %s\nShoes: %s\n%s"
		% [
			str(p.archetype).capitalize().replace("_", " "),
			str(p.pronouns),
			str(p.shoes),
			str(p.tagline),
		]
	)
	if _preview_visual != null and _preview_visual.has_method("apply_profile"):
		_preview_visual.apply_profile(p)
		if _preview_visual.has_method("set_menu_preview"):
			_preview_visual.set_menu_preview(true)


func _on_start_cup() -> void:
	if _cup.is_empty():
		return
	if GameManager.start_cup(str(_cup.get("id", "")), _cup.get("track_ids", [])):
		SceneLoader.go_to_race()


func _on_start_single() -> void:
	if course_picker.item_count == 0:
		return
	var track_id := str(course_picker.get_item_metadata(course_picker.selected))
	GameManager.start_single_race(track_id)
	SceneLoader.go_to_race()


func _on_course_selected(index: int) -> void:
	if index < 0 or index >= _tracks.size():
		return
	var track := _tracks[index]
	description_label.text = (
		"%s  •  %s\n%s"
		% [
			str(track.get("difficulty", "")).capitalize(),
			"%d laps" % int(track.get("lap_count", 3)),
			str(track.get("description", "")),
		]
	)


func _on_quit() -> void:
	get_tree().quit()
