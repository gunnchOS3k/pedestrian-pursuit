extends SceneTree

## S7Y cup deepen: authored cup_index (1–8) must bind at start_cup and round-trip in save/resume.
## Metro Motion Cup is the regression anchor (cup_index 3). COURSE/HUMAN/RC2/V1 false.

const TrackCatalogScript = preload("res://scripts/data/TrackCatalog.gd")
const _CUP_PATH := "user://cup_progress.cfg"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	var backup := ""
	if FileAccess.file_exists(_CUP_PATH):
		backup = FileAccess.get_file_as_string(_CUP_PATH)
	DirAccess.remove_absolute(_CUP_PATH)

	_exercise_all_cup_indices(failures)
	_exercise_metro_save_round_trip(failures)

	if not backup.is_empty():
		var f := FileAccess.open(_CUP_PATH, FileAccess.WRITE)
		if f:
			f.store_string(backup)
	elif FileAccess.file_exists(_CUP_PATH):
		DirAccess.remove_absolute(_CUP_PATH)

	if failures.is_empty():
		print(
			"CupIndexRuntimeWireTest PASS — cup_index runtime + save/resume · Metro Motion cup 3 · COURSE/HUMAN false"
		)
		quit(0)
		return
	print("CupIndexRuntimeWireTest FAIL:")
	for f in failures:
		print(" - ", f)
	quit(1)


func _exercise_all_cup_indices(failures: PackedStringArray) -> void:
	var seen := {}
	var gm = preload("res://scripts/core/GameManager.gd").new()
	root.add_child(gm)
	for cup_id in TrackCatalogScript.list_cup_ids():
		var cup := TrackCatalogScript.load_cup(str(cup_id))
		if cup.is_empty():
			failures.append("load_cup failed %s" % cup_id)
			continue
		var expected := int(cup.get("cup_index", 0))
		if expected < 1 or expected > 8:
			failures.append("%s invalid authored cup_index %d" % [cup_id, expected])
			continue
		if seen.has(expected):
			failures.append("duplicate cup_index %d (%s vs %s)" % [expected, seen[expected], cup_id])
		seen[expected] = str(cup_id)
		var tids: Array = cup.get("track_ids", [])
		if not gm.start_cup(str(cup_id), tids):
			failures.append("start_cup failed %s" % cup_id)
			continue
		if int(gm.active_cup_index) != expected:
			failures.append(
				"%s active_cup_index %d != authored %d"
				% [cup_id, int(gm.active_cup_index), expected]
			)
		gm.clear_cup()
		if int(gm.active_cup_index) != 0:
			failures.append("clear_cup must reset active_cup_index for %s" % cup_id)
	if seen.size() != 8:
		failures.append("expected 8 unique cup_index values, got %d" % seen.size())
	gm.queue_free()


func _exercise_metro_save_round_trip(failures: PackedStringArray) -> void:
	var cup := TrackCatalogScript.load_cup("metro_motion_cup")
	var tids: Array = cup.get("track_ids", [])
	if int(cup.get("cup_index", 0)) != 3:
		failures.append("metro_motion_cup cup_index must be 3")
	var gm = preload("res://scripts/core/GameManager.gd").new()
	root.add_child(gm)
	if not gm.start_cup("metro_motion_cup", tids):
		failures.append("metro start_cup failed")
		gm.queue_free()
		return
	if int(gm.active_cup_index) != 3:
		failures.append("metro active_cup_index != 3 after start")
	gm.save_cup_progress()
	var disk := ConfigFile.new()
	if disk.load(_CUP_PATH) != OK:
		failures.append("metro save did not write cup_progress.cfg")
	else:
		if int(disk.get_value("cup", "cup_index", 0)) != 3:
			failures.append(
				"saved cup_index != 3 (got %s)" % str(disk.get_value("cup", "cup_index", 0))
			)
	var plan: Dictionary = gm.describe_saved_cup()
	if int(plan.get("cup_index", 0)) != 3:
		failures.append("describe_saved_cup cup_index != 3")
	gm.queue_free()

	var reloaded = preload("res://scripts/core/GameManager.gd").new()
	root.add_child(reloaded)
	if not reloaded.load_cup_progress():
		failures.append("load_cup_progress failed for metro save")
	elif int(reloaded.active_cup_index) != 3:
		failures.append("load_cup_progress active_cup_index != 3")
	reloaded.queue_free()
