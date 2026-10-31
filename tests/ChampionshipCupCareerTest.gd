extends SceneTree

## Career cup validation across all 8 cups + full 4-round playthrough with mid-cup
## save/reload honesty (v3 → v4). Does not grant commercial art, all footwear,
## HUMAN_FUN/COURSE, RC2, or V1.

const TrackCatalogScript = preload("res://scripts/data/TrackCatalog.gd")
const _PROG_PATH := "user://pp_progression.cfg"
const _CUP_PATH := "user://cup_progress.cfg"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_backup_and_clear_saves()
	_exercise_migration(failures)
	_exercise_all_cups_open(failures)
	_exercise_full_cup_save_reload(failures)
	_restore_saves()
	if failures.is_empty():
		print(
			"ChampionshipCupCareerTest PASS — 8 cups startable · full-cup save/reload · v4 migration honest · commercial/HUMAN/RC2/V1 false"
		)
		quit(0)
		return
	print("ChampionshipCupCareerTest FAIL:")
	for f in failures:
		print(" - ", f)
	quit(1)


func _exercise_migration(failures: PackedStringArray) -> void:
	## Seed a pre-v4 save and migrate.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "save_version", 3)
	cfg.set_value("career", "xp", 40)
	cfg.set_value("career", "level", 2)
	cfg.set_value("career", "unlocked", {"mode:quick_race": true, "unlock_mode:starter": true})
	cfg.set_value("career", "challenges", {})
	cfg.set_value("career", "trophies", [])
	cfg.set_value("career", "tt_pbs", {})
	cfg.set_value("career", "tutorial_completed", false)
	cfg.set_value("career", "first_run_complete", false)
	cfg.set_value("career", "unlocked_vehicles", {})
	cfg.save(_PROG_PATH)

	var prog = preload("res://scripts/core/ProgressionSave.gd").new()
	root.add_child(prog)
	prog.load_or_migrate()
	if not prog.is_unlocked("championship_cups:8"):
		failures.append("v4 migration missing championship_cups:8")
	if not prog.is_unlocked("tracks:championship_32"):
		failures.append("v4 migration missing tracks:championship_32")
	if not prog.is_unlocked("mode:cup"):
		failures.append("v4 migration missing mode:cup")
	if not prog.is_unlocked("mode:partylink"):
		failures.append("v4 migration missing mode:partylink")
	## Honesty: migration must not grant all 50 vehicles or commercial flags.
	if prog.unlocked_vehicles.size() != 0:
		failures.append("migration must not auto-grant footwear vehicles")
	if prog.is_unlocked("unlock_mode:all"):
		failures.append("migration must not grant unlock_mode:all")
	var disk := ConfigFile.new()
	if disk.load(_PROG_PATH) != OK:
		failures.append("migrated save missing on disk")
	elif int(disk.get_value("meta", "save_version", 0)) != 4:
		failures.append("save_version not bumped to 4")
	prog.queue_free()


func _exercise_all_cups_open(failures: PackedStringArray) -> void:
	var cups := TrackCatalogScript.list_cup_ids()
	if cups.size() != 8:
		failures.append("cups %d != 8" % cups.size())
		return
	var gm = preload("res://scripts/core/GameManager.gd").new()
	root.add_child(gm)
	for cup_id in cups:
		var cup := TrackCatalogScript.load_cup(str(cup_id))
		var tids: Array = cup.get("track_ids", [])
		if tids.size() != 4:
			failures.append("%s track count %d" % [cup_id, tids.size()])
			continue
		if not gm.start_cup(str(cup_id), tids):
			failures.append("start_cup failed %s" % cup_id)
			continue
		if not gm.is_cup_active():
			failures.append("cup not active %s" % cup_id)
		if str(gm.selected_track_id) != str(tids[0]):
			failures.append("%s selected track mismatch" % cup_id)
		## First course must be raceable championship geometry with chase identity.
		var track := TrackCatalogScript.load_track(str(tids[0]))
		if str(track.get("geometry_status", "")) != "championship_upgraded":
			failures.append("%s opener not championship_upgraded" % cup_id)
		if bool(track.get("human_track_art_approved", false)):
			failures.append("%s opener commercial art leak" % cup_id)
		if str(track.get("camera_identity", "")).is_empty():
			failures.append("%s opener missing camera_identity" % cup_id)
		gm.save_cup_progress()
		var plan: Dictionary = gm.describe_saved_cup()
		if not bool(plan.get("resumable", false)):
			failures.append("%s cup not resumable after save" % cup_id)
		gm.clear_cup()
	gm.queue_free()


func _exercise_full_cup_save_reload(failures: PackedStringArray) -> void:
	## Full 4-round career path on every cup with mid-cup save/reload + final reload.
	var cups := TrackCatalogScript.list_cup_ids()
	for cup_id in cups:
		DirAccess.remove_absolute(_CUP_PATH)
		var cup := TrackCatalogScript.load_cup(str(cup_id))
		var tids: Array = cup.get("track_ids", [])
		if tids.size() != 4:
			failures.append("full-cup %s size" % cup_id)
			continue
		var gm = preload("res://scripts/core/GameManager.gd").new()
		root.add_child(gm)
		if not gm.start_cup(str(cup_id), tids):
			failures.append("full-cup start %s" % cup_id)
			gm.queue_free()
			continue
		## Round 0 win → save → reload into round 1.
		_record_player_win(gm, str(tids[0]), 0)
		gm.save_cup_progress()
		gm.queue_free()
		var mid = preload("res://scripts/core/GameManager.gd").new()
		root.add_child(mid)
		if not mid.resume_saved_cup():
			failures.append("full-cup mid resume %s" % cup_id)
			mid.queue_free()
			continue
		if str(mid.selected_track_id) != str(tids[1]) or int(mid.cup_round_index) != 1:
			failures.append(
				"full-cup %s mid land %s/%d" % [cup_id, mid.selected_track_id, mid.cup_round_index]
			)
		if int(mid.cup_standings.get("You", 0)) != 10:
			failures.append("full-cup %s mid standings %s" % [cup_id, str(mid.cup_standings)])
		## Finish remaining three rounds without double-count.
		_record_player_win(mid, str(tids[1]), 1)
		if not mid.advance_cup():
			failures.append("full-cup %s advance to 3" % cup_id)
		_record_player_win(mid, str(tids[2]), 2)
		if not mid.advance_cup():
			failures.append("full-cup %s advance to finale" % cup_id)
		_record_player_win(mid, str(tids[3]), 3)
		mid.save_cup_progress()
		if mid.get_cup_total_points() != 40:
			failures.append("full-cup %s total %d" % [cup_id, mid.get_cup_total_points()])
		var plan: Dictionary = mid.describe_saved_cup()
		if bool(plan.get("resumable", false)) or not bool(plan.get("completed", false)):
			failures.append("full-cup %s finished state %s" % [cup_id, str(plan)])
		mid.queue_free()
		## Reload completed cup for standings honesty.
		var done = preload("res://scripts/core/GameManager.gd").new()
		root.add_child(done)
		if not done.load_cup_progress():
			failures.append("full-cup %s completed load" % cup_id)
		elif done.get_cup_total_points() != 40:
			failures.append("full-cup %s reload total %d" % [cup_id, done.get_cup_total_points()])
		if done.resume_saved_cup():
			failures.append("full-cup %s must not resume after complete" % cup_id)
		done.queue_free()


func _record_player_win(gm, track_id: String, round_index: int) -> void:
	var fake_results: Array = [
		{"racer": null, "time": 80.0 + float(round_index), "is_player": true},
		{"racer": null, "time": 88.0 + float(round_index), "is_player": false},
		{"racer": null, "time": 93.0 + float(round_index), "is_player": false},
		{"racer": null, "time": 99.0 + float(round_index), "is_player": false},
	]
	gm.record_race_result(track_id, 80.0 + float(round_index), 1)
	gm.record_field_results(fake_results)


var _prog_backup := ""
var _cup_backup := ""
var _had_prog := false
var _had_cup := false


func _backup_and_clear_saves() -> void:
	if FileAccess.file_exists(_PROG_PATH):
		_had_prog = true
		_prog_backup = FileAccess.get_file_as_string(_PROG_PATH)
	if FileAccess.file_exists(_CUP_PATH):
		_had_cup = true
		_cup_backup = FileAccess.get_file_as_string(_CUP_PATH)
	DirAccess.remove_absolute(_PROG_PATH)
	DirAccess.remove_absolute(_CUP_PATH)


func _restore_saves() -> void:
	_restore_file(_PROG_PATH, _prog_backup, _had_prog)
	_restore_file(_CUP_PATH, _cup_backup, _had_cup)


func _restore_file(path: String, contents: String, existed: bool) -> void:
	if existed:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(contents)
			f.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
