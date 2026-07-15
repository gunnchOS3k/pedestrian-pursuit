extends CanvasLayer

## Results screen shown after race finish.

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var time_label: Label = $Panel/Margin/VBox/TimeLabel
@onready var position_label: Label = $Panel/Margin/VBox/PositionLabel
@onready var course_label: Label = $Panel/Margin/VBox/CourseLabel
@onready var cup_summary_label: Label = $Panel/Margin/VBox/CupSummaryLabel
@onready var menu_button: Button = $Panel/Margin/VBox/MenuButton
@onready var retry_button: Button = $Panel/Margin/VBox/RetryButton


func _ready() -> void:
	panel.visible = false
	menu_button.pressed.connect(_on_menu)
	retry_button.pressed.connect(_on_retry)


func show_results(
	time: float,
	position: int,
	finished: bool,
	course_data: Dictionary = {},
	field_lines: PackedStringArray = PackedStringArray()
) -> void:
	panel.visible = true
	title_label.text = "Race Complete!" if finished else "Race Over"
	if position == 1 and finished:
		title_label.text = "Podium Finish!"
	time_label.text = "Time: %02d:%05.2f" % [int(time) / 60, fmod(time, 60.0)]
	position_label.text = "Position: %d" % position
	course_label.text = str(course_data.get("display_name", "Unknown Course"))
	GameManager.last_race_time = time
	GameManager.last_race_position = position
	GameManager.last_race_finished = finished
	var field_block := "\n".join(field_lines) if not field_lines.is_empty() else ""
	if GameManager.is_cup_active():
		var total_time := GameManager.get_cup_total_time()
		var standings := "\n".join(GameManager.get_cup_standings_lines())
		cup_summary_label.text = (
			"%s  •  %d points  •  %02d:%05.2f total\n%s\n%s"
			% [
				GameManager.get_cup_round_label(),
				GameManager.get_cup_total_points(),
				int(total_time) / 60,
				fmod(total_time, 60.0),
				field_block,
				standings if not standings.is_empty() else "Standings pending",
			]
		)
		if GameManager.has_next_cup_race():
			retry_button.text = "Next Course"
		else:
			title_label.text = "Cup Complete!"
			retry_button.text = "Race Cup Again"
			GameManager.save_cup_progress()
	else:
		cup_summary_label.text = (
			("Field:\n%s\n\nSingle-course race" % field_block)
			if not field_block.is_empty()
			else "Single-course race"
		)
		retry_button.text = "Race Again"


func hide_results() -> void:
	panel.visible = false


func _on_menu() -> void:
	GameManager.clear_cup()
	SceneLoader.go_to_main_menu()


func _on_retry() -> void:
	if GameManager.is_cup_active():
		if GameManager.has_next_cup_race():
			GameManager.advance_cup()
		else:
			GameManager.restart_cup()
	SceneLoader.go_to_race()
