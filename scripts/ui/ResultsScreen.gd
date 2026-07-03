extends CanvasLayer

## Results screen shown after race finish.

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var time_label: Label = $Panel/Margin/VBox/TimeLabel
@onready var position_label: Label = $Panel/Margin/VBox/PositionLabel
@onready var menu_button: Button = $Panel/Margin/VBox/MenuButton
@onready var retry_button: Button = $Panel/Margin/VBox/RetryButton

var _visible_state: bool = false


func _ready() -> void:
	panel.visible = false
	menu_button.pressed.connect(_on_menu)
	retry_button.pressed.connect(_on_retry)


func show_results(time: float, position: int, finished: bool) -> void:
	panel.visible = true
	title_label.text = "Race Complete!" if finished else "Race Over"
	time_label.text = "Time: %02d:%05.2f" % [int(time) / 60, fmod(time, 60.0)]
	position_label.text = "Position: %d" % position
	GameManager.last_race_time = time
	GameManager.last_race_position = position
	GameManager.last_race_finished = finished


func hide_results() -> void:
	panel.visible = false


func _on_menu() -> void:
	SceneLoader.go_to_main_menu()


func _on_retry() -> void:
	SceneLoader.go_to_race()
