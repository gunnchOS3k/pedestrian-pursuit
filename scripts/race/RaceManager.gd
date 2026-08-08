extends Node

## Race flow: countdown, timer, finish detection.

signal countdown_tick(value: String)
signal race_started
signal race_finished(player: Node, results: Array)
signal timer_updated(elapsed: float)

enum RaceState { WAITING, COUNTDOWN, RACING, FINISHED }

@export var countdown_seconds: int = 3

var state: RaceState = RaceState.WAITING
var race_time: float = 0.0
var player_start_boost_window: bool = false

var _racers: Array = []
var _player: Node = null
var _countdown_timer: float = 0.0
var _go_time: float = 0.0
var _player_pressed_early: bool = false
var _perfect_window: float = 0.0
var _perfect_latched: bool = false
var _results: Array = []
var _finished_count: int = 0

@onready var lap_manager: Node = $LapManager
@onready var position_tracker: Node = $PositionTracker


func _ready() -> void:
	# Keep countdown/race clocks running even if a pause overlay toggles incorrectly.
	process_mode = Node.PROCESS_MODE_ALWAYS
	lap_manager.racer_finished.connect(_on_racer_finished)


func setup_race(racers: Array, player: Node, checkpoints: Array, laps: int) -> void:
	_racers = racers
	_player = player
	state = RaceState.WAITING
	race_time = 0.0
	_results.clear()
	_finished_count = 0
	lap_manager.setup(laps, checkpoints.size())
	for racer in racers:
		lap_manager.register_racer(racer)
	var cp_nodes: Array[Node3D] = []
	for cp in checkpoints:
		cp_nodes.append(cp as Node3D)
	position_tracker.setup(lap_manager, cp_nodes)
	for cp in checkpoints:
		cp.racer_passed.connect(_on_checkpoint_passed)


func begin_countdown() -> void:
	var tree := get_tree()
	if tree != null and tree.paused:
		tree.paused = false
	state = RaceState.COUNTDOWN
	_countdown_timer = float(countdown_seconds) + 1.0
	_player_pressed_early = false
	_go_time = -1.0
	_perfect_window = 0.0
	_perfect_latched = false
	countdown_tick.emit(str(countdown_seconds))
	call_deferred("_countdown_sequence")


func _countdown_sequence() -> void:
	if state != RaceState.COUNTDOWN:
		return
	var tree := get_tree()
	if tree == null:
		return
	for value in range(countdown_seconds, 0, -1):
		if state != RaceState.COUNTDOWN:
			return
		countdown_tick.emit(str(value))
		await tree.create_timer(1.0, true, false, true).timeout
	if state != RaceState.COUNTDOWN:
		return
	countdown_tick.emit("GO!")
	_start_race()


func _process(delta: float) -> void:
	match state:
		RaceState.COUNTDOWN:
			_process_countdown(delta)
			_sample_perfect_step_countdown()
		RaceState.RACING:
			race_time += delta
			timer_updated.emit(race_time)
			position_tracker.update_positions()
			_stamp_place_estimates()
			_sample_perfect_step_racing(delta)
		_:
			pass


func _process_countdown(delta: float) -> void:
	_countdown_timer -= delta
	var display_val := ceili(_countdown_timer) - 1
	if display_val <= countdown_seconds and display_val >= 1:
		countdown_tick.emit(str(display_val))
	if _countdown_timer <= 0.0 and state == RaceState.COUNTDOWN:
		countdown_tick.emit("GO!")
		_start_race()


func _is_accel_pressed() -> bool:
	if InputManager != null and InputManager.has_method("is_accelerating"):
		if GameManager != null and GameManager.auto_accelerate and not GameManager.accept_test_mode:
			return Input.is_action_pressed("accelerate")
		return InputManager.is_accelerating()
	return Input.is_action_pressed("accelerate")


func _sample_perfect_step_countdown() -> void:
	if state != RaceState.COUNTDOWN:
		return
	if _countdown_timer > 0.2 and _is_accel_pressed():
		_player_pressed_early = true


func _sample_perfect_step_racing(delta: float) -> void:
	if _perfect_window <= 0.0 or _perfect_latched:
		return
	_perfect_window = maxf(0.0, _perfect_window - delta)
	_go_time = maxf(0.0, _go_time) + delta
	if _is_accel_pressed() and not _player_pressed_early:
		_perfect_latched = true
		if _player != null and _player.has_method("apply_perfect_start"):
			_player.apply_perfect_start(1.28)


func _stamp_place_estimates() -> void:
	if position_tracker == null:
		return
	for racer in _racers:
		if racer == null:
			continue
		var place: int = int(position_tracker.get_position_for(racer))
		racer.set_meta("race_place_estimate", place)


func _start_race() -> void:
	if state != RaceState.COUNTDOWN:
		return
	state = RaceState.RACING
	player_start_boost_window = true
	_go_time = 0.0
	_perfect_window = 0.4
	race_started.emit()
	for racer in _racers:
		if racer.has_method("enable_movement"):
			racer.enable_movement()
	if _player != null and _player.has_method("apply_perfect_start"):
		var mult := 1.0
		if _player_pressed_early:
			mult = 0.85
		_player.apply_perfect_start(mult)


func _on_checkpoint_passed(racer: Node, index: int) -> void:
	lap_manager.on_checkpoint(racer, index)


func _on_racer_finished(racer: Node, _finish_time: float) -> void:
	lap_manager.set_finish_time(racer, race_time)
	_finished_count += 1
	var human := _is_local_human(racer)
	var local_idx := 0
	if racer != null and "local_player_index" in racer:
		local_idx = int(racer.local_player_index)
	_results.append({
		"racer": racer,
		"time": race_time,
		"is_player": human,
		"local_player_index": local_idx,
	})
	# End when primary player finishes, or (Local MP) when any human finishes.
	if human and (racer == _player or GameManager.is_local_mp()):
		_finish_race()


func _is_local_human(racer: Node) -> bool:
	if racer == null:
		return false
	if racer == _player:
		return true
	if GameManager.is_local_mp() and bool(racer.get("is_player")):
		return true
	return false


func _finish_race() -> void:
	if state == RaceState.FINISHED:
		return
	state = RaceState.FINISHED
	for racer in _racers:
		racer.movement_enabled = false
	position_tracker.update_positions()
	race_finished.emit(_player, _results)
