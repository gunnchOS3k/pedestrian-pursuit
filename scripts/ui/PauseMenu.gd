extends CanvasLayer

## Pause menu overlay.


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/Margin/VBox/ResumeButton.pressed.connect(_on_resume)
	$Panel/Margin/VBox/MenuButton.pressed.connect(_on_menu)


func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible


func _on_resume() -> void:
	toggle_pause()


func _on_menu() -> void:
	get_tree().paused = false
	SceneLoader.go_to_main_menu()
