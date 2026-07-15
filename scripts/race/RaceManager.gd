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
var _results: Array = []
var _finished_count: int = 0

@onready var lap_manager: Node = $LapManager
@onready var position_tracker: Node = $PositionTracker


func _ready() -> void:
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
	state = RaceState.COUNTDOWN
	_countdown_timer = float(countdown_seconds) + 1.0
	_player_pressed_early = false
	_go_time = -1.0
	countdown_tick.emit(str(countdown_seconds))


func _process(delta: float) -> void:
	match state:
		RaceState.COUNTDOWN:
			_process_countdown(delta)
		RaceState.RACING:
			race_time += delta
			timer_updated.emit(race_time)
			position_tracker.update_positions()
		_:
			pass


func _process_countdown(delta: float) -> void:
	_countdown_timer -= delta
	var display_val := ceili(_countdown_timer)
	if display_val <= countdown_seconds and display_val > 0:
		countdown_tick.emit(str(display_val))
	if _countdown_timer <= 1.0 and _countdown_timer > 0.0:
		player_start_boost_window = true
		if InputManager.is_accelerating():
			_go_time = _countdown_timer
	if InputManager.is_accelerating() and _countdown_timer > 1.05:
		_player_pressed_early = true
	if _countdown_timer <= 0.0:
		countdown_tick.emit("GO!")
		_start_race()


func _start_race() -> void:
	if state != RaceState.COUNTDOWN:
		return
	state = RaceState.RACING
	player_start_boost_window = false
	race_started.emit()
	for racer in _racers:
		if racer.has_method("enable_movement"):
			racer.enable_movement()
	if _player != null and _player.has_method("apply_perfect_start"):
		var mult := 1.0
		if not _player_pressed_early and _go_time >= 0.0 and _go_time <= 1.05:
			mult = 1.25
		elif _player_pressed_early:
			mult = 0.85
		_player.apply_perfect_start(mult)


func _on_checkpoint_passed(racer: Node, index: int) -> void:
	lap_manager.on_checkpoint(racer, index)


func _on_racer_finished(racer: Node, _finish_time: float) -> void:
	lap_manager.set_finish_time(racer, race_time)
	_finished_count += 1
	var is_player := racer == _player
	_results.append({"racer": racer, "time": race_time, "is_player": is_player})
	if is_player:
		_finish_race()


func _finish_race() -> void:
	if state == RaceState.FINISHED:
		return
	state = RaceState.FINISHED
	for racer in _racers:
		racer.movement_enabled = false
	position_tracker.update_positions()
	race_finished.emit(_player, _results)
