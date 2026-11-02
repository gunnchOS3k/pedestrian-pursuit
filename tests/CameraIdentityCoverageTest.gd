extends SceneTree

## Camera deepen: every championship track camera_identity must be a named arm in
## CameraRig.apply_course_identity (no silent `_` default fallthrough).
## Do not preload CameraRig — GameManager autoload is not visible under --script preload
## (same contract as AccessibilityBaselineTest). Does not load RaceScene / wave010.
## Preserves 32-track gates. COURSE/HUMAN false.

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
	if known.size() < 32:
		failures.append("CameraRig apply_course_identity parse found <32 identities (%d)" % known.size())
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
	## Preserve 32-track championship gate (do not weaken to ≥8).
	if ids.size() != 32:
		failures.append("expected championship track set (==32), got %d" % ids.size())

	var seen_identity := {}
	var art_candidate := 0
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
		var track: Dictionary = parsed as Dictionary
		var identity := str(track.get("camera_identity", ""))
		if identity.is_empty():
			failures.append("%s missing camera_identity" % tid)
			continue
		seen_identity[identity] = true
		if not known.has(identity):
			failures.append(
				"%s identity '%s' not in CameraRig.apply_course_identity arms (would fall through default)"
				% [tid, identity]
			)
		if str(track.get("final_track_art_status", "")) == "track_art_candidate":
			art_candidate += 1
		if bool(track.get("human_track_art_approved", false)):
			failures.append("%s human_track_art_approved must stay false" % tid)

	if seen_identity.size() != 32:
		failures.append("expected 32 distinct camera identities, got %d" % seen_identity.size())
	if art_candidate != 32:
		failures.append("expected 32 track_art_candidate statuses, got %d" % art_candidate)

	## Deepen: each resolved identity arm must assign base_fov + max_fov (personality ≠ silent empty arm).
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
		if not window.contains("max_fov"):
			failures.append("%s arm missing max_fov assignment window" % identity)

	## S7O: camera identity + track art cohonesty (procedural ≠ finished).
	var TrackArtAcceptanceScript = load("res://scripts/data/TrackArtAcceptance.gd")
	var coh: Dictionary = TrackArtAcceptanceScript.camera_identity_art_cohonesty()
	if int(coh.get("track_count", -1)) != 32:
		failures.append("camera/art cohonesty track_count != 32")
	if int(coh.get("with_camera_identity", -1)) != 32:
		failures.append("camera/art cohonesty with_camera_identity != 32")
	if int(coh.get("track_art_candidate", -1)) != 32:
		failures.append("camera/art cohonesty track_art_candidate != 32")
	if not bool(coh.get("procedural_neq_finished", false)):
		failures.append(
			"procedural_neq_finished required (no finished track art claim) got=%s"
			% JSON.stringify(coh)
		)
	if bool(coh.get("HUMAN", true)) or bool(coh.get("COURSE_ACCEPTED", true)):
		failures.append("camera/art cohonesty must keep HUMAN/COURSE false")
	if bool(coh.get("RC2", true)) or bool(coh.get("V1", true)):
		failures.append("camera/art cohonesty must keep RC2/V1 false")

	_finish(failures)


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print(
			"CameraIdentityCoverageTest PASS — 32 track camera_identity values resolve · COURSE/HUMAN false"
		)
		quit(0)
	else:
		for f in failures:
			print("FAIL ", f)
		print("CameraIdentityCoverageTest FAIL count=", failures.size())
		quit(1)
