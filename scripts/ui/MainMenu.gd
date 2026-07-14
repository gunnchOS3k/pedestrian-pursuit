extends Control
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")

## Main menu — start the four-course cup or practice a selected course.

var _cup: Dictionary = {}
var _tracks: Array[Dictionary] = []

@onready var course_picker: OptionButton = $VBox/CoursePicker
@onready var description_label: Label = $VBox/Description


func _ready() -> void:
	$VBox/StartCupButton.pressed.connect(_on_start_cup)
	$VBox/SingleRaceButton.pressed.connect(_on_start_single)
	$VBox/QuitButton.pressed.connect(_on_quit)
	course_picker.item_selected.connect(_on_course_selected)
	_load_content()


func _load_content() -> void:
	_cup = _TrackCatalog.load_cup()
	_tracks = _TrackCatalog.load_tracks_for_cup()
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
