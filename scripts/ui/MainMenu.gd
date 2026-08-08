extends Control
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _RunnerProfile = preload("res://scripts/data/RunnerProfile.gd")
const _RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")

## Main menu — Quick Race, Cup, Time Trial, Local MP entry points (Alpha).

var _cup: Dictionary = {}
var _tracks: Array[Dictionary] = []
var _all_tracks: Array[Dictionary] = []
var _roster: Array = []
var _preview_visual: Node3D
var _cup_picker: OptionButton
var _shoe_picker: OptionButton

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
	$VBox/SingleRaceButton.text = "Quick Race"
	$VBox/QuitButton.pressed.connect(_on_quit)
	course_picker.item_selected.connect(_on_course_selected)
	runner_picker.item_selected.connect(_on_runner_selected)
	_setup_preview_viewport()
	_ensure_settings_ui()
	_ensure_mode_buttons()
	_ensure_howto_button()
	_ensure_cup_and_shoe_pickers()
	_load_content()
	_populate_device_picker()
	_sync_a11y_toggles()
	$VBox/CupLabel.text = "ALPHA  •  8 COURSES  •  2 CUPS"
	$VBox/Subtitle.text = "Wave E Alpha — greybox depth, not content-complete"


func _ensure_howto_button() -> void:
	var vbox: VBoxContainer = $VBox
	if vbox.get_node_or_null("HowToPlayButton") != null:
		var existing := vbox.get_node("HowToPlayButton") as Button
		if existing and not existing.pressed.is_connected(_on_howto_play):
			existing.pressed.connect(_on_howto_play)
		return
	var btn := Button.new()
	btn.name = "HowToPlayButton"
	btn.text = "How to Play"
	btn.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(btn)
	var quit := vbox.get_node_or_null("QuitButton")
	if quit != null:
		vbox.move_child(btn, quit.get_index())
	btn.pressed.connect(_on_howto_play)


func _on_howto_play() -> void:
	var existing := get_node_or_null("HowToPlayOverlay")
	if existing != null:
		existing.visible = true
		return
	var overlay := ColorRect.new()
	overlay.name = "HowToPlayOverlay"
	overlay.color = Color(0.05, 0.07, 0.12, 0.92)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -220
	panel.offset_bottom = 220
	panel.add_theme_constant_override("separation", 10)
	overlay.add_child(panel)
	var title := Label.new()
	title.text = "How to Play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.add_theme_font_size_override("font_size", 15)
	body.text = (
		"Race on foot across greybox championship courses.\n\n"
		+ "Steer A/D · Accelerate W · Brake S\n"
		+ "Jump Space · Drift Shift · Slide Ctrl\n"
		+ "Boost Q · Use Item E · Pause Esc\n\n"
		+ "Modes: Quick Race, Cup (save/resume), Time Trial with ghost, Local 2P shared screen.\n"
		+ "Items warn before hitting — shield, slide, or jump for counterplay.\n"
		+ "Accessibility toggles live on this menu (reduce motion, larger UI, auto-accel, colorblind HUD)."
	)
	panel.add_child(body)
	var close := Button.new()
	close.text = "Got it"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func (): overlay.visible = false)
	panel.add_child(close)


func _ensure_mode_buttons() -> void:
	var vbox: VBoxContainer = $VBox
	if vbox.get_node_or_null("TimeTrialButton") != null:
		_wire_mode_buttons()
		return
	var insert_at := vbox.get_node("SingleRaceButton").get_index() + 1

	var tt := Button.new()
	tt.name = "TimeTrialButton"
	tt.text = "Time Trial / Ghost"
	tt.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(tt)
	vbox.move_child(tt, insert_at)
	insert_at += 1

	var lmp := Button.new()
	lmp.name = "LocalMPButton"
	lmp.text = "Local Multiplayer (2P)"
	lmp.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(lmp)
	vbox.move_child(lmp, insert_at)
	_wire_mode_buttons()


func _wire_mode_buttons() -> void:
	var tt := $VBox.get_node_or_null("TimeTrialButton") as Button
	var lmp := $VBox.get_node_or_null("LocalMPButton") as Button
	if tt and not tt.pressed.is_connected(_on_start_time_trial):
		tt.pressed.connect(_on_start_time_trial)
	if lmp and not lmp.pressed.is_connected(_on_start_local_mp):
		lmp.pressed.connect(_on_start_local_mp)


func _ensure_cup_and_shoe_pickers() -> void:
	var vbox: VBoxContainer = $VBox
	if vbox.get_node_or_null("CupPicker") == null:
		var cup_label := Label.new()
		cup_label.name = "CupPickerLabel"
		cup_label.text = "Championship Cup"
		cup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(cup_label)
		vbox.move_child(cup_label, vbox.get_node("StartCupButton").get_index())
		_cup_picker = OptionButton.new()
		_cup_picker.name = "CupPicker"
		_cup_picker.custom_minimum_size = Vector2(0, 40)
		vbox.add_child(_cup_picker)
		vbox.move_child(_cup_picker, cup_label.get_index() + 1)
		_cup_picker.item_selected.connect(_on_cup_selected)
	else:
		_cup_picker = vbox.get_node("CupPicker")

	if vbox.get_node_or_null("ShoePicker") == null:
		var shoe_label := Label.new()
		shoe_label.name = "ShoePickerLabel"
		shoe_label.text = "Footwear"
		shoe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(shoe_label)
		vbox.move_child(shoe_label, vbox.get_node("RunnerInfo").get_index() + 1)
		_shoe_picker = OptionButton.new()
		_shoe_picker.name = "ShoePicker"
		_shoe_picker.custom_minimum_size = Vector2(0, 40)
		vbox.add_child(_shoe_picker)
		vbox.move_child(_shoe_picker, shoe_label.get_index() + 1)
		_shoe_picker.item_selected.connect(_on_shoe_selected)
	else:
		_shoe_picker = vbox.get_node("ShoePicker")


func _ensure_settings_ui() -> void:
	var vbox: VBoxContainer = $VBox
	if vbox.get_node_or_null("DeviceLabel") != null:
		_device_picker = vbox.get_node("DevicePicker")
		_device_hint = vbox.get_node("DeviceHint")
		_a11y_reduce = vbox.get_node("A11yReduceMotion")
		_a11y_larger = vbox.get_node("A11yLargerUI")
		_a11y_auto = vbox.get_node("A11yAutoAccel")
		_a11y_colorblind = vbox.get_node("A11yColorblind")
		_ensure_resume_cup_button()
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
	_ensure_resume_cup_button()


func _ensure_resume_cup_button() -> void:
	var vbox: VBoxContainer = $VBox
	var existing := vbox.get_node_or_null("ResumeCupButton") as Button
	if existing != null:
		if not existing.pressed.is_connected(_on_resume_cup):
			existing.pressed.connect(_on_resume_cup)
		_refresh_resume_cup_button()
		return
	var resume := Button.new()
	resume.name = "ResumeCupButton"
	resume.text = "Resume Saved Cup"
	resume.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(resume)
	var start_idx := vbox.get_node("StartCupButton").get_index()
	vbox.move_child(resume, start_idx + 1)
	resume.pressed.connect(_on_resume_cup)
	_refresh_resume_cup_button()


func _refresh_resume_cup_button() -> void:
	var resume := $VBox.get_node_or_null("ResumeCupButton") as Button
	if resume == null:
		return
	var cfg := ConfigFile.new()
	var has_save := cfg.load("user://cup_progress.cfg") == OK and str(cfg.get_value("cup", "active_cup_id", "")) != ""
	resume.visible = has_save
	if has_save:
		var round_i := int(cfg.get_value("cup", "round_index", 0)) + 1
		resume.text = "Resume Saved Cup (course %d)" % round_i


func _on_resume_cup() -> void:
	if GameManager.load_cup_progress():
		SceneLoader.go_to_race()
	else:
		_refresh_resume_cup_button()


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
	_all_tracks = _TrackCatalog.load_all_tracks()
	_populate_cup_picker()
	_populate_shoe_picker()
	_populate_runner_picker()
	_reload_selected_cup_tracks()
	if _all_tracks.is_empty():
		$VBox/StartCupButton.disabled = true
		$VBox/SingleRaceButton.disabled = true
		description_label.text = "Course content could not be loaded. Check the project log."


func _populate_cup_picker() -> void:
	if _cup_picker == null:
		return
	_cup_picker.clear()
	var preferred := str(GameManager.selected_cup_id)
	var select_index := 0
	for i in _TrackCatalog.list_cup_ids().size():
		var cup_id := str(_TrackCatalog.list_cup_ids()[i])
		var cup := _TrackCatalog.load_cup(cup_id)
		_cup_picker.add_item(str(cup.get("display_name", cup_id)))
		_cup_picker.set_item_metadata(i, cup_id)
		if cup_id == preferred:
			select_index = i
	if _cup_picker.item_count > 0:
		_cup_picker.select(select_index)
		_on_cup_selected(select_index)


func _populate_shoe_picker() -> void:
	if _shoe_picker == null:
		return
	_shoe_picker.clear()
	var preferred := str(GameManager.selected_shoe_id)
	var select_index := 0
	for i in ShoeData.all_ids().size():
		var shoe_id := str(ShoeData.all_ids()[i])
		var shoe := ShoeData.load_by_id(shoe_id)
		_shoe_picker.add_item(str(shoe.get("display_name", shoe_id)))
		_shoe_picker.set_item_metadata(i, shoe_id)
		if shoe_id == preferred:
			select_index = i
	if _shoe_picker.item_count > 0:
		_shoe_picker.select(select_index)
		_on_shoe_selected(select_index)


func _reload_selected_cup_tracks() -> void:
	var cup_id := str(GameManager.selected_cup_id)
	if cup_id.is_empty():
		cup_id = _TrackCatalog.DEFAULT_CUP_ID
	_cup = _TrackCatalog.load_cup(cup_id)
	_tracks = _TrackCatalog.load_tracks_for_cup(cup_id)
	# Quick Race / TT / Local MP use the full 8-course catalog.
	course_picker.clear()
	for track in _all_tracks:
		var label := str(track.get("display_name", "Unknown Course"))
		if str(track.get("art_status", "")) == "REQUIRES_ART_PRODUCTION":
			label += " [greybox]"
		course_picker.add_item(label)
		course_picker.set_item_metadata(course_picker.item_count - 1, str(track.get("id", "")))
	var expected_track_count: int = _cup.get("track_ids", []).size()
	$VBox/StartCupButton.disabled = _cup.is_empty() or _tracks.size() != expected_track_count
	$VBox/StartCupButton.text = "Start Cup: %s" % str(_cup.get("display_name", "Cup"))
	if course_picker.item_count > 0:
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


func _on_cup_selected(index: int) -> void:
	if _cup_picker == null or index < 0:
		return
	GameManager.selected_cup_id = str(_cup_picker.get_item_metadata(index))
	_reload_selected_cup_tracks()


func _on_shoe_selected(index: int) -> void:
	if _shoe_picker == null or index < 0:
		return
	GameManager.selected_shoe_id = str(_shoe_picker.get_item_metadata(index))


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


func _selected_track_id() -> String:
	if course_picker.item_count == 0:
		return ""
	return str(course_picker.get_item_metadata(course_picker.selected))


func _on_start_cup() -> void:
	if _cup.is_empty():
		return
	if GameManager.start_cup(str(_cup.get("id", "")), _cup.get("track_ids", [])):
		SceneLoader.go_to_race()


func _on_start_single() -> void:
	var track_id := _selected_track_id()
	if track_id.is_empty():
		return
	GameManager.start_quick_race(track_id)
	SceneLoader.go_to_race()


func _on_start_time_trial() -> void:
	var track_id := _selected_track_id()
	if track_id.is_empty():
		return
	GameManager.start_time_trial(track_id)
	SceneLoader.go_to_race()


func _on_start_local_mp() -> void:
	var track_id := _selected_track_id()
	if track_id.is_empty():
		return
	GameManager.start_local_mp(track_id, 2)
	SceneLoader.go_to_race()


func _on_course_selected(index: int) -> void:
	if index < 0 or index >= _all_tracks.size():
		return
	var track := _all_tracks[index]
	var art := str(track.get("art_status", ""))
	var art_note := "\nREQUIRES_ART_PRODUCTION" if art == "REQUIRES_ART_PRODUCTION" else ""
	description_label.text = (
		"%s  •  %s\n%s%s"
		% [
			str(track.get("difficulty", "")).capitalize(),
			"%d laps" % int(track.get("lap_count", 3)),
			str(track.get("description", "")),
			art_note,
		]
	)


func _on_quit() -> void:
	get_tree().quit()
