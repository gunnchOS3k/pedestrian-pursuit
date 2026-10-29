extends SceneTree

## Career cup validation across all 8 cups + save migration honesty (v3 → v4).
## Does not grant commercial art, all footwear, HUMAN_FUN/COURSE, RC2, or V1.

const TrackCatalogScript = preload("res://scripts/data/TrackCatalog.gd")
const _PROG_PATH := "user://pp_progression.cfg"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	_backup_and_clear_prog()
	_exercise_migration(failures)
	_exercise_all_cups(failures)
	_restore_prog()
	if failures.is_empty():
		print(
			"ChampionshipCupCareerTest PASS — 8 cups startable · save v4 migration honest · commercial/HUMAN/RC2/V1 false"
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


func _exercise_all_cups(failures: PackedStringArray) -> void:
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
		## First course must be raceable championship geometry.
		var track := TrackCatalogScript.load_track(str(tids[0]))
		if str(track.get("geometry_status", "")) != "championship_upgraded":
			failures.append("%s opener not championship_upgraded" % cup_id)
		if bool(track.get("human_track_art_approved", false)):
			failures.append("%s opener commercial art leak" % cup_id)
		gm.save_cup_progress()
		var plan: Dictionary = gm.describe_saved_cup()
		if not bool(plan.get("resumable", false)):
			failures.append("%s cup not resumable after save" % cup_id)
		gm.clear_cup()
	gm.queue_free()


var _prog_backup := ""
var _had_prog := false


func _backup_and_clear_prog() -> void:
	if FileAccess.file_exists(_PROG_PATH):
		_had_prog = true
		_prog_backup = FileAccess.get_file_as_string(_PROG_PATH)
	DirAccess.remove_absolute(_PROG_PATH)


func _restore_prog() -> void:
	if _had_prog:
		var f := FileAccess.open(_PROG_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_prog_backup)
			f.close()
	elif FileAccess.file_exists(_PROG_PATH):
		DirAccess.remove_absolute(_PROG_PATH)
