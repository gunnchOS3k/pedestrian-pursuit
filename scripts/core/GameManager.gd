extends Node

const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")

## Global game state and settings.

enum RaceMode { SINGLE, CUP, TIME_TRIAL, PRACTICE }

var current_race_mode: RaceMode = RaceMode.SINGLE
var selected_racer_id: String = "dash"
var selected_runner_id: String = "dash_reed"
var selected_shoe_id: String = "starter_soles"
var selected_track_id: String = "verdant_cascade_circuit"
var total_laps: int = 3

var active_cup_id: String = ""
var cup_track_ids: Array[String] = []
var cup_round_index: int = 0
var cup_results: Array[Dictionary] = []
var cup_standings: Dictionary = {} # racer_label -> points
var last_field_results: Array = []

var camera_shake_enabled: bool = true
var auto_accelerate: bool = false
## Acceptance-only overrides (default off). accept_force_laps>0 shortens RC races.
var accept_test_mode: bool = false
var accept_force_laps: int = 0
var accept_steer: float = 0.0

var last_race_time: float = 0.0
var last_race_position: int = 1
var last_race_finished: bool = false


func reset_race_stats() -> void:
	last_race_time = 0.0
	last_race_position = 1
	last_race_finished = false
	last_field_results.clear()


func start_single_race(track_id: String) -> void:
	clear_cup()
	current_race_mode = RaceMode.SINGLE
	selected_track_id = track_id
	reset_race_stats()


func start_cup(cup_id: String, track_ids: Array) -> bool:
	if track_ids.is_empty():
		push_error("Cannot start an empty cup")
		return false
	active_cup_id = cup_id
	cup_track_ids.clear()
	for track_id in track_ids:
		cup_track_ids.append(str(track_id))
	cup_round_index = 0
	cup_results.clear()
	cup_standings.clear()
	current_race_mode = RaceMode.CUP
	selected_track_id = cup_track_ids[0]
	reset_race_stats()
	return true


func is_cup_active() -> bool:
	return (
		current_race_mode == RaceMode.CUP
		and not active_cup_id.is_empty()
		and not cup_track_ids.is_empty()
	)


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
	cfg.save("user://cup_progress.cfg")


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
	# Assign provisional places by finish order in results, then fill non-finishers by live rank later.
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
