extends Node

## Global game state and settings.

enum RaceMode { SINGLE, CUP, TIME_TRIAL, PRACTICE }

var current_race_mode: RaceMode = RaceMode.SINGLE
var selected_racer_id: String = "dash"
var selected_shoe_id: String = "starter_soles"
var selected_track_id: String = "verdant_cascade_circuit"
var total_laps: int = 3

var active_cup_id: String = ""
var cup_track_ids: Array[String] = []
var cup_round_index: int = 0
var cup_results: Array[Dictionary] = []

var camera_shake_enabled: bool = true
var auto_accelerate: bool = false

var last_race_time: float = 0.0
var last_race_position: int = 1
var last_race_finished: bool = false


func reset_race_stats() -> void:
	last_race_time = 0.0
	last_race_position = 1
	last_race_finished = false


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
	var cup := TrackCatalog.load_cup(active_cup_id)
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
	if current_race_mode == RaceMode.CUP:
		current_race_mode = RaceMode.SINGLE


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
