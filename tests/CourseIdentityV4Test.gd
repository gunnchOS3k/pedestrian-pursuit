extends SceneTree
const _TrackCatalog = preload("res://scripts/data/TrackCatalog.gd")
const _CourseTrack = preload("res://scripts/tracks/CourseTrack.gd")
const _Identity = preload("res://scripts/gamefeel/CourseIdentityCatalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	var identity_ok := 0
	var world_ok := 0
	var feature_ok := 0
	var silhouettes: Dictionary = {}
	var topologies: Dictionary = {}
	var mechanics: Dictionary = {}
	var boosts: Dictionary = {}

	for track_id in _Identity.LAUNCH_TRACKS:
		if not _Identity.has_v4_fields(track_id):
			failures.append("%s missing V4 identity fields" % track_id)
			continue
		var ident: Dictionary = _Identity.identity_for(track_id)
		silhouettes[str(ident.get("silhouette_grammar", ""))] = true
		topologies[str(ident.get("route_topology", ""))] = true
		mechanics[str(ident.get("signature_mechanic", ""))] = true
		boosts[str(ident.get("boost_moment", ""))] = true
		if int(ident.get("landmarks", []).size()) < 3:
			failures.append("%s needs >=3 landmarks" % track_id)
		identity_ok += 1

		var data := _TrackCatalog.load_track(track_id)
		var course: Node = _CourseTrack.new()
		course.configure(data)
		root.add_child(course)
		if not course.build():
			failures.append("%s failed to build" % track_id)
		else:
			if int(course.count_landmarks()) < 3:
				failures.append("%s landmark nodes < 3" % track_id)
			var stats: Dictionary = {}
			if course.has_method("get_world_assembly_stats"):
				stats = course.get_world_assembly_stats()
			if int(stats.get("macro_props", 0)) < 1 and int(stats.get("skyline_props", 0)) < 1:
				failures.append("%s world assembly empty" % track_id)
			else:
				world_ok += 1
			var boxes := int(course.count_feature_nodes("ItemBox")) if course.has_method("count_feature_nodes") else 0
			var pickups := int(course.count_feature_nodes("BoostPickup")) if course.has_method("count_feature_nodes") else 0
			var lanes := int(course.count_feature_nodes("SpeedLane")) if course.has_method("count_feature_nodes") else 0
			if boxes < 1 or pickups < 1 or lanes < 1:
				failures.append("%s features incomplete boxes=%d boosts=%d lanes=%d" % [track_id, boxes, pickups, lanes])
			else:
				feature_ok += 1
			if course.get_node_or_null("WorldAssembly_V4") == null:
				failures.append("%s missing WorldAssembly_V4" % track_id)
		course.queue_free()

	if silhouettes.size() < 8:
		failures.append("silhouette uniqueness %d/8" % silhouettes.size())
	if topologies.size() < 8:
		failures.append("topology uniqueness %d/8" % topologies.size())
	if mechanics.size() < 8:
		failures.append("mechanic uniqueness %d/8" % mechanics.size())
	if boosts.size() < 8:
		failures.append("boost moment uniqueness %d/8" % boosts.size())

	_write_gates(identity_ok, world_ok, feature_ok, failures)

	if failures.is_empty() and identity_ok == 8 and world_ok == 8 and feature_ok == 8:
		print("EIGHT_UNIQUE_ROUTE_TOPOLOGIES_PASS=true")
		print("EIGHT_UNIQUE_COURSE_SILHOUETTES_PASS=true")
		print("EIGHT_SIGNATURE_MECHANICS_PASS=true")
		print("EIGHT_SIGNATURE_BOOST_MOMENTS_PASS=true")
		print("ITEM_BOX_VISUAL_PRESENCE_PASS=true")
		print("BOOST_PICKUP_VISUAL_PRESENCE_PASS=true")
		print("SPEED_LANE_VISUAL_PRESENCE_PASS=true")
		print("HUMAN_COURSE_IDENTITY_PASS=false")
		print("HUMAN_POWERUP_READABILITY_PASS=false")
		print("NEXT_PEDESTRIAN_ACTION=OWNER_PIXEL_REVIEW_ALL_EIGHT_V4_COURSES")
		print("CourseIdentityV4Test PASS")
		quit(0)
	else:
		for row in failures:
			push_error(row)
		print("CourseIdentityV4Test FAIL")
		quit(1)


func _write_gates(identity_ok: int, world_ok: int, feature_ok: int, failures: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/v4")
	var file := FileAccess.open("res://artifacts/v4/COURSE_IDENTITY_V4_BUILD.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"identity_ok": identity_ok,
			"world_ok": world_ok,
			"feature_ok": feature_ok,
			"required": 8,
			"failures": Array(failures),
			"HUMAN_COURSE_IDENTITY_PASS": false,
			"HUMAN_POWERUP_READABILITY_PASS": false,
			"NEXT_PEDESTRIAN_ACTION": "OWNER_PIXEL_REVIEW_ALL_EIGHT_V4_COURSES",
		}, "  "))
