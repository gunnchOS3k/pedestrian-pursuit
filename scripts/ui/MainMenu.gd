extends Control

## Main menu — start race or quit.


func _ready() -> void:
	$VBox/StartButton.pressed.connect(_on_start)
	$VBox/QuitButton.pressed.connect(_on_quit)


func _on_start() -> void:
	GameManager.reset_race_stats()
	SceneLoader.go_to_race()


func _on_quit() -> void:
	get_tree().quit()
