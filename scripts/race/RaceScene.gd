extends Node3D

## Wires together track, racers, race manager, HUD, and results.

@onready var race_manager: Node = $RaceManager
@onready var track: Node3D = $SneakerCitySprintway
@onready var player: Node = $PlayerRacer
@onready var ai_racer: Node = $AIRacer
@onready var hud: CanvasLayer = $RaceHUD
@onready var results: CanvasLayer = $ResultsScreen
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var camera_rig: SpringArm3D = $CameraRig


func _ready() -> void:
	race_manager.add_to_group("race_manager")
	camera_rig.set_target(player)
	var checkpoints: Array = track.get_checkpoints()
	var racers: Array = [player, ai_racer]
	var start_xf: Transform3D = track.get_start_transform()
	player.global_transform = start_xf
	player.setup_for_race(start_xf)
	var ai_start := start_xf.translated(Vector3(3, 0, 0))
	ai_racer.global_transform = ai_start
	ai_racer.setup_for_race(ai_start)
	if ai_racer.has_method("setup_ai_path"):
		ai_racer.setup_ai_path(track.get_race_path(), 20.0)
	race_manager.setup_race(racers, player, checkpoints, GameManager.total_laps)
	hud.setup(player, race_manager)
	debug_overlay.setup(player)
	results.hide_results()
	race_manager.race_finished.connect(_on_race_finished)
	race_manager.begin_countdown()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_menu.toggle_pause()


func _on_race_finished(finished_player: Node, _results: Array) -> void:
	var pos := race_manager.position_tracker.get_position_for(finished_player)
	results.show_results(race_manager.race_time, pos, true)
