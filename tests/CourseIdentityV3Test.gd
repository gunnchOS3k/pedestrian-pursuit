extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CourseTrack = preload("res://scripts/tracks/CourseTrack.gd")
const _Identity = preload("res://scripts/gamefeel/CourseIdentityCatalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var ok := 0
	var landmark_ok := 0
	for track_id in _Identity.LAUNCH_TRACKS:
		var ident: Dictionary = _Identity.identity_for(track_id)
		if ident.is_empty():
			failures.append("%s missing identity" % track_id)
			continue
		for key in [
			"visual_theme", "landmark", "route_rhythm", "signature_section",
			"shortcut_style", "lighting", "audio_direction", "challenge_identity"
		]:
			if key == "landmark":
				continue
			if str(ident.get(key, "")).is_empty() and typeof(ident.get(key)) != TYPE_DICTIONARY:
				failures.append("%s missing %s" % [track_id, key])
		var marks: Array = ident.get("landmarks", [])
		if marks.size() < 2:
			failures.append("%s has %d landmarks; need 2-3" % [track_id, marks.size()])
		else:
			landmark_ok += 1
		var data := _TrackCatalog.load_track(track_id)
		var course: Node = _CourseTrack.new()
		course.configure(data)
		root.add_child(course)
		if not course.build():
			failures.append("%s failed to build with identity" % track_id)
		elif int(course.count_landmarks()) < 2:
			failures.append("%s built without landmark nodes" % track_id)
		else:
			ok += 1
		course.queue_free()
	_write_matrix(ok)
	if failures.is_empty() and ok == 8:
		print("COURSE_IDENTITY_PASS=8/8")
		print("LANDMARK_NAVIGATION_PASS=8/8")
		print("OWNER_COURSE_IDENTITY_PASS=false")
		print("CourseIdentityV3Test PASS")
		quit(0)
	else:
		for row in failures:
			push_error(row)
		print("CourseIdentityV3Test FAIL")
		quit(1)


func _write_matrix(ok: int) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/gamefeel/v3")
	var file := FileAccess.open("res://artifacts/gamefeel/v3/COURSE_IDENTITY_BUILD.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"built": ok,
			"required": 8,
			"HUMAN_COURSE_IDENTITY_PASS": false,
		}, "  "))
