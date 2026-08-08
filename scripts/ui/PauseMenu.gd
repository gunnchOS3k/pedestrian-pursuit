extends CanvasLayer

## Pause menu overlay — resume, restart race, or return to menu.

var _local_mp: bool = false
var _hint: Label


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/Margin/VBox/ResumeButton.pressed.connect(_on_resume)
	$Panel/Margin/VBox/MenuButton.pressed.connect(_on_menu)
	_ensure_restart_button()


func configure_local_mp(enabled: bool) -> void:
	_local_mp = enabled
	var vbox: VBoxContainer = $Panel/Margin/VBox
	if _hint == null:
		_hint = Label.new()
		_hint.name = "LocalMPHint"
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.add_theme_font_size_override("font_size", 14)
		vbox.add_child(_hint)
		vbox.move_child(_hint, 0)
	_hint.visible = enabled
	_hint.text = "Local MP — either player may pause (Esc / Start). Career save unchanged."


func _ensure_restart_button() -> void:
	var vbox: VBoxContainer = $Panel/Margin/VBox
	if vbox.get_node_or_null("RestartButton") != null:
		vbox.get_node("RestartButton").pressed.connect(_on_restart)
		return
	var restart := Button.new()
	restart.name = "RestartButton"
	restart.text = "Restart Race"
	vbox.add_child(restart)
	vbox.move_child(restart, vbox.get_node("MenuButton").get_index())
	restart.pressed.connect(_on_restart)


func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible


func _on_resume() -> void:
	toggle_pause()


func _on_restart() -> void:
	get_tree().paused = false
	visible = false
	SceneLoader.restart_race("pause_restart")


func _on_menu() -> void:
	get_tree().paused = false
	if _local_mp:
		GameManager.clear_cup()
	SceneLoader.go_to_main_menu()
