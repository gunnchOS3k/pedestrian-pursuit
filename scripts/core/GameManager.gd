extends Node

const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")

## Global game state and settings.

enum RaceMode { SINGLE, CUP, TIME_TRIAL, PRACTICE, LOCAL_MP, TUTORIAL, CHALLENGE }

var current_race_mode: RaceMode = RaceMode.SINGLE
var selected_racer_id: String = "dash_reed"
var selected_runner_id: String = "dash_reed"
var selected_shoe_id: String = "starter_soles"
var selected_track_id: String = "verdant_cascade_circuit"
var selected_cup_id: String = "sole_surge_cup"
var selected_challenge_id: String = ""
var total_laps: int = 3
var local_mp_players: int = 2
var ai_field_size: int = 3
var ai_eval_mode: bool = false
var ai_eval_tier: String = "standard"

var active_cup_id: String = ""
var cup_track_ids: Array[String] = []
var cup_round_index: int = 0
var cup_results: Array[Dictionary] = []
var cup_standings: Dictionary = {} # racer_label -> points
var last_field_results: Array = []

var camera_shake_enabled: bool = true
var auto_accelerate: bool = false
## Acceptance-only overrides (default off). accept_force_laps>0 shortens RC races.
## Wave010 gameplay proof MUST NOT rely on accept_force_laps / accept_test_mode.
var accept_test_mode: bool = false
var accept_force_laps: int = 0
var accept_steer: float = 0.0
## Soft racing-line assist for touch/Android (player still holds accelerate). Explicit + disableable.
var mobile_assist_steer: float = 0.0
## Competitive / time-trial: no hidden rubber-band, no place-based speed, assists off.
var competitive_mode: bool = false
var race_mode: String = "single"

var last_race_time: float = 0.0
var last_race_position: int = 1
var last_race_finished: bool = false


func reset_race_stats() -> void:
	last_race_time = 0.0
	last_race_position = 1
	last_race_finished = false
	last_field_results.clear()


func prepare_race_restart(reason: String = "rematch") -> void:
	reset_race_stats()
	mobile_assist_steer = 0.0
	accept_steer = 0.0
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.paused:
		tree.paused = false
	var bus := _telemetry_bus()
	if bus != null and bus.has_method("restart"):
		bus.restart(selected_track_id, reason)


func _telemetry_bus() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("TelemetryBus")


func set_competitive_mode(enabled: bool) -> void:
	competitive_mode = enabled
	if enabled:
		mobile_assist_steer = 0.0
		auto_accelerate = false
		accept_steer = 0.0


func sync_race_mode_string() -> void:
	match current_race_mode:
		RaceMode.TIME_TRIAL:
			race_mode = "time_trial"
			set_competitive_mode(true)
		RaceMode.CHALLENGE:
			race_mode = "competitive"
			set_competitive_mode(true)
		RaceMode.PRACTICE, RaceMode.TUTORIAL:
			race_mode = "practice"
			competitive_mode = false
		RaceMode.LOCAL_MP:
			race_mode = "local_mp"
			competitive_mode = false
		RaceMode.CUP:
			race_mode = "cup"
			competitive_mode = false
		_:
			race_mode = "single"
			competitive_mode = false


func mode_label() -> String:
	match current_race_mode:
		RaceMode.CUP:
			return "Cup"
		RaceMode.TIME_TRIAL:
			return "Time Trial"
		RaceMode.PRACTICE:
			return "Practice"
		RaceMode.LOCAL_MP:
			return "Local Multiplayer"
		RaceMode.TUTORIAL:
			return "Tutorial"
		RaceMode.CHALLENGE:
			return "Challenge"
		_:
			return "Quick Race"


func start_quick_race(track_id: String) -> void:
	start_single_race(track_id)


func start_single_race(track_id: String) -> void:
	clear_cup()
	current_race_mode = RaceMode.SINGLE
	selected_track_id = track_id
	ai_field_size = 3
	reset_race_stats()


func start_time_trial(track_id: String) -> void:
	clear_cup()
	current_race_mode = RaceMode.TIME_TRIAL
	selected_track_id = track_id
	ai_field_size = 0
	total_laps = 1
	reset_race_stats()
	sync_race_mode_string()


func start_local_mp(track_id: String, players: int = 2) -> void:
	clear_cup()
	current_race_mode = RaceMode.LOCAL_MP
	selected_track_id = track_id
	local_mp_players = clampi(players, 2, 2)
	ai_field_size = 2
	reset_race_stats()


func start_tutorial(track_id: String = "verdant_cascade_circuit") -> void:
	clear_cup()
	current_race_mode = RaceMode.TUTORIAL
	selected_track_id = track_id
	ai_field_size = 1
	reset_race_stats()


func start_challenge(challenge_id: String, track_id: String, shoe_id: String = "") -> void:
	clear_cup()
	current_race_mode = RaceMode.CHALLENGE
	selected_challenge_id = challenge_id
	selected_track_id = track_id
	if not shoe_id.is_empty():
		selected_shoe_id = shoe_id
	ai_field_size = 2
	reset_race_stats()


func is_tutorial() -> bool:
	return current_race_mode == RaceMode.TUTORIAL


func is_challenge() -> bool:
	return current_race_mode == RaceMode.CHALLENGE


func start_cup(cup_id: String, track_ids: Array) -> bool:
	if track_ids.is_empty():
		push_error("Cannot start an empty cup")
		return false
	active_cup_id = cup_id
	selected_cup_id = cup_id
	cup_track_ids.clear()
	for track_id in track_ids:
		cup_track_ids.append(str(track_id))
	cup_round_index = 0
	cup_results.clear()
	cup_standings.clear()
	current_race_mode = RaceMode.CUP
	selected_track_id = cup_track_ids[0]
	ai_field_size = 3
	reset_race_stats()
	return true


func is_cup_active() -> bool:
	return (
		current_race_mode == RaceMode.CUP
		and not active_cup_id.is_empty()
		and not cup_track_ids.is_empty()
	)


func is_time_trial() -> bool:
	return current_race_mode == RaceMode.TIME_TRIAL


func is_local_mp() -> bool:
	return current_race_mode == RaceMode.LOCAL_MP


func record_race_result(track_id: String, time: float, position: int) -> void:
	last_race_time = time
	last_race_position = position
	last_race_finished = true
	if not is_cup_active():
		return
	if cup_round_index < 0 or cup_round_index >= cup_track_ids.size():
		return
	if track_id != cup_track_ids[cup_round_index]:
		push_warning("Ignoring cup result for unexpected course '%s'" % track_id)
		return
	var cup := _TrackCatalog.load_cup(active_cup_id)
	var points_table: Array = cup.get("points_by_position", [10, 7, 5, 3, 2, 1])
	var points_index := clampi(position - 1, 0, points_table.size() - 1)
	var result := {
		"track_id": track_id,
		"time": maxf(time, 0.0),
		"position": maxi(position, 1),
		"points": int(points_table[points_index]),
	}
	if cup_results.size() == cup_round_index:
		cup_results.append(result)
	elif cup_results.size() > cup_round_index:
		cup_results[cup_round_index] = result


func has_next_cup_race() -> bool:
	return is_cup_active() and cup_round_index + 1 < cup_track_ids.size()


func advance_cup() -> bool:
	if not has_next_cup_race():
		return false
	cup_round_index += 1
	selected_track_id = cup_track_ids[cup_round_index]
	reset_race_stats()
	return true


func restart_cup() -> bool:
	if not is_cup_active():
		return false
	var tracks := cup_track_ids.duplicate()
	return start_cup(active_cup_id, tracks)


func clear_cup() -> void:
	active_cup_id = ""
	cup_track_ids.clear()
	cup_round_index = 0
	cup_results.clear()
	cup_standings.clear()
	if current_race_mode == RaceMode.CUP:
		current_race_mode = RaceMode.SINGLE


func save_cup_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("cup", "active_cup_id", active_cup_id)
	cfg.set_value("cup", "round_index", cup_round_index)
	cfg.set_value("cup", "results", cup_results)
	cfg.set_value("cup", "standings", cup_standings)
	cfg.set_value("cup", "track_ids", cup_track_ids)
	cfg.set_value("cup", "completed", is_cup_active() and not has_next_cup_race() and not cup_results.is_empty())
	cfg.set_value("meta", "saved_at", Time.get_datetime_string_from_system())
	cfg.set_value("meta", "save_version", 2)
	cfg.save("user://cup_progress.cfg")
	# Mirror selection into progression save for RC migration continuity.
	var prog := _progression()
	if prog != null:
		prog.first_run_complete = true
		if prog.has_method("unlock"):
			prog.unlock("mode:cup")
		if prog.has_method("save"):
			prog.save()


func _progression() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("ProgressionSave")


func load_cup_progress() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://cup_progress.cfg") != OK:
		return false
	active_cup_id = str(cfg.get_value("cup", "active_cup_id", ""))
	cup_round_index = int(cfg.get_value("cup", "round_index", 0))
	cup_results = cfg.get_value("cup", "results", [])
	cup_standings = cfg.get_value("cup", "standings", {})
	var tracks = cfg.get_value("cup", "track_ids", [])
	cup_track_ids.clear()
	for tid in tracks:
		cup_track_ids.append(str(tid))
	if not active_cup_id.is_empty() and not cup_track_ids.is_empty():
		current_race_mode = RaceMode.CUP
		selected_cup_id = active_cup_id
		selected_track_id = cup_track_ids[mini(cup_round_index, cup_track_ids.size() - 1)]
		return true
	return false


func get_cup_total_points() -> int:
	var total := 0
	for result in cup_results:
		total += int(result.get("points", 0))
	return total


func get_cup_total_time() -> float:
	var total := 0.0
	for result in cup_results:
		total += float(result.get("time", 0.0))
	return total


func get_cup_round_label() -> String:
	if not is_cup_active():
		return ""
	return "Course %d of %d" % [cup_round_index + 1, cup_track_ids.size()]


func record_field_results(finish_results: Array) -> void:
	last_field_results = finish_results.duplicate()
	if not is_cup_active():
		return
	var cup := _TrackCatalog.load_cup(active_cup_id)
	var points_table: Array = cup.get("points_by_position", [10, 7, 5, 3, 2, 1])
	for i in finish_results.size():
		var entry: Dictionary = finish_results[i]
		var racer: Node = entry.get("racer")
		var label := "You" if bool(entry.get("is_player", false)) else "AI %d" % (i + 1)
		if racer != null and racer.has_method("get") and str(racer.get("display_name")) != "":
			pass
		var points_index := clampi(i, 0, points_table.size() - 1)
		var pts := int(points_table[points_index])
		cup_standings[label] = int(cup_standings.get(label, 0)) + pts


func get_cup_standings_lines() -> PackedStringArray:
	var rows: Array = []
	for key in cup_standings.keys():
		rows.append({"name": str(key), "points": int(cup_standings[key])})
	rows.sort_custom(func(a, b): return int(a.points) > int(b.points))
	var lines: PackedStringArray = []
	for i in rows.size():
		lines.append("%d. %s — %d pts" % [i + 1, rows[i].name, rows[i].points])
	return lines
