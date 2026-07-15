extends Control
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _RunnerProfile = preload("res://scripts/data/RunnerProfile.gd")
const _RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")

## Main menu — pick a runner, start the four-course cup, or practice a course.

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


func _ready() -> void:
	$VBox/StartCupButton.pressed.connect(_on_start_cup)
	$VBox/SingleRaceButton.pressed.connect(_on_start_single)
	$VBox/QuitButton.pressed.connect(_on_quit)
	course_picker.item_selected.connect(_on_course_selected)
	runner_picker.item_selected.connect(_on_runner_selected)
	_setup_preview_viewport()
	_load_content()


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
	# Rear-quarter view so jacket/scarf/backpack/heel flares read clearly.
	cam.position = Vector3(1.35, 1.35, -2.15)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true
	world.add_child(cam)

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
