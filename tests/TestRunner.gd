extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CourseTrack = preload("res://scripts/tracks/CourseTrack.gd")

## Headless Godot smoke test: loads and builds every course in cup order.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_test_lap_sequence(failures)
	var cup := _TrackCatalog.load_cup()
	if cup.is_empty():
		failures.append("default cup did not load")
	for track_id in cup.get("track_ids", []):
		var data := _TrackCatalog.load_track(str(track_id))
		if data.is_empty():
			failures.append("course '%s' did not load" % track_id)
			continue
		var course: Node = _CourseTrack.new()
		course.configure(data)
		get_root().add_child(course)
		if not course.build():
			failures.append("course '%s' did not build" % track_id)
		elif course.get_checkpoints().size() != data.get("checkpoint_points", []).size():
			failures.append("course '%s' checkpoint count differed from data" % track_id)
		elif course.get_race_path() == null or course.get_race_path().curve == null:
			failures.append("course '%s' has no AI race path" % track_id)
		course.queue_free()
	if failures.is_empty():
		print("Godot course smoke test passed for all four courses.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_lap_sequence(failures: PackedStringArray) -> void:
	var lap_manager := preload("res://scripts/race/LapManager.gd").new()
	var racer := Node.new()
	get_root().add_child(lap_manager)
	get_root().add_child(racer)
	lap_manager.setup(3, 4)
	lap_manager.register_racer(racer)
	if lap_manager.get_next_checkpoint(racer) != 1:
		failures.append("race must begin by targeting checkpoint 1")
	lap_manager.on_checkpoint(racer, 0)
	if lap_manager.get_lap(racer) != 0:
		failures.append("crossing the start area at spawn must not count a lap")
	for checkpoint_index in [1, 2, 3]:
		lap_manager.on_checkpoint(racer, checkpoint_index)
	if lap_manager.get_lap(racer) != 0 or lap_manager.get_next_checkpoint(racer) != 0:
		failures.append("all intermediate checkpoints must lead to the finish line")
	lap_manager.on_checkpoint(racer, 0)
	if lap_manager.get_lap(racer) != 1 or lap_manager.get_next_checkpoint(racer) != 1:
		failures.append("a lap must complete only when returning to checkpoint 0")
	lap_manager.queue_free()
	racer.queue_free()
