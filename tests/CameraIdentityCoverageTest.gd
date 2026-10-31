extends SceneTree

## Camera deepen: every championship track camera_identity must be a named arm in
## CameraRig.apply_course_identity (no silent `_` default fallthrough).
## Do not preload CameraRig — GameManager autoload is not visible under --script preload
## (same contract as AccessibilityBaselineTest). Does not load RaceScene / wave010.
## COURSE/HUMAN false.

const TrackCatalogScript = preload("res://scripts/data/TrackCatalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _known_identities_from_camera_rig_source() -> Dictionary:
	## Parse match-arm string literals from apply_course_identity in CameraRig.gd.
	var known := {}
	var src := FileAccess.get_file_as_string("res://scripts/player/CameraRig.gd")
	if src.is_empty():
		return known
	var in_fn := false
	for line in src.split("\n"):
		if line.contains("func apply_course_identity"):
			in_fn = true
			continue
		if in_fn and line.begins_with("func "):
			break
		if not in_fn:
			continue
		## Match arms look like: \t\t"harbor_chase": or \t\t"a", "b":
		var stripped := line.strip_edges()
		if not stripped.begins_with("\""):
			continue
		if stripped == "_:" or stripped.begins_with("_:"):
			continue
		var i := 0
		while i < stripped.length():
			if stripped[i] != "\"":
				i += 1
				continue
			var j := i + 1
			while j < stripped.length() and stripped[j] != "\"":
				j += 1
			if j >= stripped.length():
				break
			var token := stripped.substr(i + 1, j - i - 1)
			if not token.is_empty() and token != "_":
				known[token] = true
			i = j + 1
	return known


func _run() -> void:
	var failures: PackedStringArray = []
	var known := _known_identities_from_camera_rig_source()
	if known.size() < 8:
		failures.append("CameraRig apply_course_identity parse found <8 identities (%d)" % known.size())
		_finish(failures)
		return

	var ids: PackedStringArray = TrackCatalogScript.list_all_track_ids()
	if ids.is_empty():
		var dir := DirAccess.open("res://data/tracks")
		if dir != null:
			dir.list_dir_begin()
			var fname := dir.get_next()
			while fname != "":
				if fname.ends_with(".json"):
					ids.append(fname.trim_suffix(".json"))
				fname = dir.get_next()
	if ids.size() < 8:
		failures.append("expected championship track set (≥8), got %d" % ids.size())

	var seen_identity := {}
	for tid in ids:
		var path := "res://data/tracks/%s.json" % tid
		if not FileAccess.file_exists(path):
			failures.append("missing track json %s" % tid)
			continue
		var raw := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(raw)
		if typeof(parsed) != TYPE_DICTIONARY:
			failures.append("bad track json %s" % tid)
			continue
		var identity := str((parsed as Dictionary).get("camera_identity", ""))
		if identity.is_empty():
			failures.append("%s missing camera_identity" % tid)
			continue
		seen_identity[identity] = true
		if not known.has(identity):
			failures.append(
				"%s identity '%s' not in CameraRig.apply_course_identity arms (would fall through default)"
				% [tid, identity]
			)

	if seen_identity.size() < 8:
		failures.append("too few distinct camera identities: %d" % seen_identity.size())

	## Deepen: each resolved identity arm must assign base_fov (personality ≠ silent empty arm).
	var src := FileAccess.get_file_as_string("res://scripts/player/CameraRig.gd")
	for identity in seen_identity.keys():
		var needle := "\"%s\"" % identity
		var idx := src.find(needle)
		if idx < 0:
			failures.append("CameraRig source missing arm literal for %s" % identity)
			continue
		var window := src.substr(idx, mini(420, src.length() - idx))
		if not window.contains("base_fov"):
			failures.append("%s arm missing base_fov assignment window" % identity)

	_finish(failures)


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print(
			"CameraIdentityCoverageTest PASS — all track camera_identity values resolve · COURSE/HUMAN false"
		)
		quit(0)
	else:
		for f in failures:
			print("FAIL ", f)
		print("CameraIdentityCoverageTest FAIL count=", failures.size())
		quit(1)
