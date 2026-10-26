extends SceneTree

## Retired single-process path. The course AI is not a second player.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("GAME_SESSION_COURSE_AI_IS_GUEST=true")
	print("INDEPENDENT_CLIENTS_RACED=false")
	print("GAME_SESSION_RACE_FAIL this script is the retired AI-seat path")
	quit(1)
