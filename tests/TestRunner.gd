extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CourseTrack = preload("res://scripts/tracks/CourseTrack.gd")

## Headless Godot smoke: builds every Alpha cup course + validates catalog size.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_test_lap_sequence(failures)
	_test_catalog_floor(failures)
	for cup_id in _TrackCatalog.list_cup_ids():
		var cup := _TrackCatalog.load_cup(cup_id)
		if cup.is_empty():
			failures.append("cup '%s' did not load" % cup_id)
			continue
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
			elif course.has_method("get_rail_world_points"):
				var rails: Array = course.get_rail_world_points()
				var expected_rails: Array = data.get("rail_segments", [])
				if rails.size() != expected_rails.size():
					failures.append("course '%s' rail point count mismatch" % track_id)
			course.queue_free()
	if failures.is_empty():
		print("Godot Wave E Alpha course smoke passed for 2 cups / 8 courses.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_catalog_floor(failures: PackedStringArray) -> void:
	var ids := _TrackCatalog.list_all_track_ids()
	if ids.size() < 8:
		failures.append("catalog has %d tracks; Alpha floor is 8" % ids.size())
	if ShoeData.all_ids().size() < 4:
		failures.append("footwear catalog below Alpha floor of 4")
	if ItemData.all_alpha_ids().size() < 6:
		failures.append("item catalog below Alpha floor of 6")


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
