extends SceneTree

const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CUP_PATH := "user://cup_progress.cfg"
const _PROG_PATH := "user://pp_progression.cfg"

## Headless regression: an in-progress cup resumes on the unplayed course.
## Replaying a round that already has a result used to add those points again.
## A finished cup stays loadable and is not offered as another race.

var _cup_backup := ""
var _prog_backup := ""
var _had_cup := false
var _had_prog := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_backup_user_saves()
	var failures := PackedStringArray()
	_exercise_stride_resume(failures)
	_restore_user_saves()
	if failures.is_empty():
		print("Cup resume smoke PASS — stride cup continues without double-counting")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _exercise_stride_resume(failures: PackedStringArray) -> void:
	var cup: Dictionary = _TrackCatalog.load_cup("stride_circuit_cup")
	var track_ids: Array = cup.get("track_ids", [])
	if track_ids.size() != 4:
		failures.append("expected 4 Stride Circuit courses, got %d" % track_ids.size())
		return
	var gm = preload("res://scripts/core/GameManager.gd").new()
	get_root().add_child(gm)
	if not gm.start_cup("stride_circuit_cup", track_ids):
		failures.append("start_cup failed")
		return

	# Pause/quit before any result must resume the same course.
	gm.save_cup_progress()
	var fresh = _new_manager()
	var plan: Dictionary = fresh.describe_saved_cup()
	if not bool(plan.get("resumable", false)) or str(plan.get("track_id", "")) != str(track_ids[0]):
		failures.append("unstarted cup should resume %s, got %s" % [str(track_ids[0]), str(plan)])
	if not fresh.resume_saved_cup():
		failures.append("resume of an unstarted cup failed")
	elif fresh.selected_track_id != str(track_ids[0]) or fresh.cup_round_index != 0:
		failures.append(
			"unstarted resume landed on %s round %d"
			% [fresh.selected_track_id, fresh.cup_round_index]
		)

	_record_player_win(gm, str(track_ids[0]), 0)
	gm.save_cup_progress()
	if int(gm.cup_standings.get("You", 0)) != 10:
		failures.append("first course should award 10 points, got %s" % str(gm.cup_standings))
	var saved := ConfigFile.new()
	if saved.load(_CUP_PATH) != OK:
		failures.append("first finish did not write cup_progress.cfg")
	else:
		if int(saved.get_value("cup", "resume_index", -1)) != 1:
			failures.append(
				"first finish should save resume at the second race, got %s"
				% str(saved.get_value("cup", "resume_index", -1))
			)
		var standing = saved.get_value("cup", "standings", {})
		if typeof(standing) != TYPE_DICTIONARY or int(standing.get("You", 0)) != 10:
			failures.append("saved standing missing after the first finish: %s" % str(standing))

	var resumed = _new_manager()
	plan = resumed.describe_saved_cup()
	if str(plan.get("track_id", "")) != str(track_ids[1]) or int(plan.get("course_number", 0)) != 2:
		failures.append("saved round 1 should point resume at %s, got %s" % [str(track_ids[1]), str(plan)])
	if not resumed.resume_saved_cup():
		failures.append("resume after the first recorded course failed")
		return
	if resumed.selected_track_id != str(track_ids[1]) or resumed.cup_round_index != 1:
		failures.append(
			"resume replayed %s at round %d instead of the next course"
			% [resumed.selected_track_id, resumed.cup_round_index]
		)
	if int(resumed.cup_standings.get("You", 0)) != 10 or resumed.get_cup_total_points() != 10:
		failures.append(
			"resume changed points before the next race (standings=%s total=%d)"
			% [str(resumed.cup_standings), resumed.get_cup_total_points()]
		)
	_record_player_win(resumed, str(track_ids[1]), 1)
	if resumed.cup_results.size() != 2 or resumed.get_cup_total_points() != 20:
		failures.append(
			"second course did not append (results=%d points=%d)"
			% [resumed.cup_results.size(), resumed.get_cup_total_points()]
		)
	if int(resumed.cup_standings.get("You", 0)) != 20:
		failures.append(
			"standings double-counted a resumed course: %s" % str(resumed.cup_standings)
		)

	if not resumed.advance_cup():
		failures.append("advance to course 3 failed")
		return
	_record_player_win(resumed, str(track_ids[2]), 2)
	if not resumed.advance_cup():
		failures.append("advance to the finale failed")
		return
	# Final course is saved before its result (pause/quit). It must stay resumable.
	resumed.save_cup_progress()
	plan = resumed.describe_saved_cup()
	if bool(plan.get("completed", false)) or str(plan.get("track_id", "")) != str(track_ids[3]):
		failures.append("finale without a result was treated as complete: %s" % str(plan))
	var finale = _new_manager()
	if not finale.resume_saved_cup() or finale.selected_track_id != str(track_ids[3]):
		failures.append("finale resume did not start %s" % str(track_ids[3]))
		return
	if int(finale.cup_standings.get("You", 0)) != 30 or finale.get_cup_total_points() != 30:
		failures.append(
			"finale resume altered earlier points (standings=%s total=%d)"
			% [str(finale.cup_standings), finale.get_cup_total_points()]
		)
	_record_player_win(finale, str(track_ids[3]), 3)
	finale.save_cup_progress()
	plan = finale.describe_saved_cup()
	if bool(plan.get("resumable", false)) or not bool(plan.get("completed", false)):
		failures.append("finished cup was still resumable: %s" % str(plan))
	if finale.resume_saved_cup():
		failures.append("finished cup resume started another race")
	var loaded = _new_manager()
	if not loaded.load_cup_progress():
		failures.append("finished cup should still load for standings")
	elif loaded.get_cup_total_points() != 40 or int(loaded.cup_standings.get("You", 0)) != 40:
		failures.append(
			"finished cup points changed (total=%d standings=%s)"
			% [loaded.get_cup_total_points(), str(loaded.cup_standings)]
		)


func _record_player_win(gm, track_id: String, round_index: int) -> void:
	var fake_results: Array = [
		{"racer": null, "time": 80.0 + float(round_index), "is_player": true},
		{"racer": null, "time": 88.0 + float(round_index), "is_player": false},
		{"racer": null, "time": 93.0 + float(round_index), "is_player": false},
		{"racer": null, "time": 99.0 + float(round_index), "is_player": false},
	]
	gm.record_race_result(track_id, 80.0 + float(round_index), 1)
	gm.record_field_results(fake_results)


func _new_manager():
	var gm = preload("res://scripts/core/GameManager.gd").new()
	get_root().add_child(gm)
	return gm


func _backup_user_saves() -> void:
	_had_cup = FileAccess.file_exists(_CUP_PATH)
	_had_prog = FileAccess.file_exists(_PROG_PATH)
	_cup_backup = FileAccess.get_file_as_string(_CUP_PATH) if _had_cup else ""
	_prog_backup = FileAccess.get_file_as_string(_PROG_PATH) if _had_prog else ""


func _restore_user_saves() -> void:
	_restore_file(_CUP_PATH, _cup_backup, _had_cup)
	_restore_file(_PROG_PATH, _prog_backup, _had_prog)


func _restore_file(path: String, contents: String, existed: bool) -> void:
	if not existed:
		if FileAccess.file_exists(path):
			var dir := DirAccess.open("user://")
			if dir != null:
				dir.remove(path.trim_prefix("user://"))
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not restore %s" % path)
		return
	file.store_string(contents)
	file.close()
