extends SceneTree

## 8 cups × 4 = 32 raceable championship tracks; track-art acceptance separate.

const TrackCatalogScript = preload("res://scripts/data/TrackCatalog.gd")
const TrackArtAcceptanceScript = preload("res://scripts/data/TrackArtAcceptance.gd")
const CourseTrackScript = preload("res://scripts/tracks/CourseTrack.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	var cups := TrackCatalogScript.list_cup_ids()
	if cups.size() != 8:
		failures.append("cups %d != 8" % cups.size())
	var ids := TrackCatalogScript.list_all_track_ids()
	if ids.size() != 32:
		failures.append("tracks %d != 32" % ids.size())
	## Preserve original eight names/IDs.
	for tid in [
		"verdant_cascade_circuit",
		"cloverwind_ranch",
		"prism_apex",
		"emberkeep_gauntlet",
		"tideglass_harbor",
		"neon_switchyard",
		"cloudstep_ridge",
		"mirage_mesa",
		"sneaker_city_sprintway",
	]:
		if tid not in ids:
			failures.append("missing preserved/upgraded track %s" % tid)
	## Metro Motion includes Sneaker City.
	var metro := TrackCatalogScript.load_cup("metro_motion_cup")
	var metro_ids: Array = metro.get("track_ids", [])
	if "sneaker_city_sprintway" not in metro_ids:
		failures.append("metro_motion missing sneaker_city_sprintway")
	if metro_ids.size() != 4:
		failures.append("metro_motion size")
	## Build sample from each production batch tier.
	for sample in [
		"verdant_cascade_circuit",
		"metro_pulse_loop",
		"saltline_boardwalk",
		"lantern_corridor",
		"horizon_crown_finale",
	]:
		var data := TrackCatalogScript.load_track(sample)
		if data.is_empty():
			failures.append("load %s" % sample)
			continue
		var course: Node = CourseTrackScript.new()
		root.add_child(course)
		course.configure(data)
		if not course.build():
			failures.append("build %s" % sample)
		elif course.get_race_path() == null:
			failures.append("path %s" % sample)
		elif course.get_checkpoints().size() < 4:
			failures.append("checkpoints %s" % sample)
		course.queue_free()
	## Cups 1–2: championship_upgraded with landmarks; collision stays lap-safe.
	var prism := TrackCatalogScript.load_track("prism_apex")
	if str(prism.get("geometry_status", "")) != "championship_upgraded":
		failures.append("prism_apex not championship_upgraded")
	if (prism.get("landmarks", []) as Array).is_empty():
		failures.append("prism_apex missing landmarks")
	if absf(float(prism.get("bank_bias", 0.0))) < 0.05:
		failures.append("prism_apex missing bank metadata")
	## Cup 3 Metro Motion: authored path elevation on raceable geometry.
	for tid in ["transit_spiral", "sneaker_city_sprintway"]:
		var d := TrackCatalogScript.load_track(tid)
		var has_y := false
		for p in d.get("path_points", []):
			if typeof(p) == TYPE_ARRAY and p.size() == 3 and absf(float(p[1])) > 0.1:
				has_y = true
				break
		if not has_y:
			failures.append("%s missing elevation" % tid)
	## Cup 4 Kinetic Coast: four distinct championship_raceable courses.
	var coast := TrackCatalogScript.load_cup("kinetic_coast_cup")
	var coast_ids: Array = coast.get("track_ids", [])
	if coast_ids.size() != 4:
		failures.append("kinetic_coast size")
	for tid in ["saltline_boardwalk", "cliffside_draft", "tidal_bridge_run", "seaglass_switchback"]:
		if tid not in coast_ids:
			failures.append("kinetic_coast missing %s" % tid)
		var cd := TrackCatalogScript.load_track(tid)
		if str(cd.get("geometry_status", "")) != "championship_raceable":
			failures.append("%s not championship_raceable" % tid)
		if str(cd.get("final_track_art_status", "")) != "track_art_pending":
			failures.append("%s art must stay pending" % tid)
		var coast_has_y := false
		for p in cd.get("path_points", []):
			if typeof(p) == TYPE_ARRAY and p.size() == 3 and absf(float(p[1])) > 0.1:
				coast_has_y = true
				break
		if not coast_has_y:
			failures.append("%s missing elevation" % tid)
		if (cd.get("landmarks", []) as Array).size() < 2:
			failures.append("%s needs distinct landmarks" % tid)
		var coast_course: Node = CourseTrackScript.new()
		root.add_child(coast_course)
		coast_course.configure(cd)
		if not coast_course.build():
			failures.append("build coast %s" % tid)
		else:
			var scenery := coast_course.get_node_or_null("Scenery")
			if scenery == null:
				failures.append("%s missing Scenery" % tid)
			elif tid == "saltline_boardwalk" and scenery.get_node_or_null("PierArch") == null:
				failures.append("saltline missing PierArch")
			elif tid == "cliffside_draft" and scenery.get_node_or_null("CliffCairn") == null:
				failures.append("cliffside missing CliffCairn")
			elif tid == "tidal_bridge_run" and scenery.get_node_or_null("NorthBridge") == null:
				failures.append("tidal missing NorthBridge")
			elif tid == "seaglass_switchback" and scenery.get_node_or_null("SeaglassSpire") == null:
				failures.append("seaglass missing SeaglassSpire")
		coast_course.queue_free()
	## Cup 5 Neon Night: four distinct championship_raceable courses.
	var neon := TrackCatalogScript.load_cup("neon_night_cup")
	var neon_ids: Array = neon.get("track_ids", [])
	if neon_ids.size() != 4:
		failures.append("neon_night size")
	for tid in ["lantern_corridor", "mirror_boulevard", "afterglow_overpass", "signal_storm_yard"]:
		if tid not in neon_ids:
			failures.append("neon_night missing %s" % tid)
		var nd := TrackCatalogScript.load_track(tid)
		if str(nd.get("geometry_status", "")) != "championship_raceable":
			failures.append("%s not championship_raceable" % tid)
		if str(nd.get("final_track_art_status", "")) != "track_art_pending":
			failures.append("%s art must stay pending" % tid)
		var neon_has_y := false
		for p in nd.get("path_points", []):
			if typeof(p) == TYPE_ARRAY and p.size() == 3 and absf(float(p[1])) > 0.1:
				neon_has_y = true
				break
		if not neon_has_y:
			failures.append("%s missing elevation" % tid)
		if (nd.get("landmarks", []) as Array).size() < 2:
			failures.append("%s needs distinct landmarks" % tid)
		var neon_course: Node = CourseTrackScript.new()
		root.add_child(neon_course)
		neon_course.configure(nd)
		if not neon_course.build():
			failures.append("build neon %s" % tid)
		else:
			var neon_scenery := neon_course.get_node_or_null("Scenery")
			if neon_scenery == null:
				failures.append("%s missing Scenery" % tid)
			elif tid == "lantern_corridor" and neon_scenery.get_node_or_null("LanternCanopy") == null:
				failures.append("lantern missing LanternCanopy")
			elif tid == "mirror_boulevard" and neon_scenery.get_node_or_null("MirrorGateA") == null:
				failures.append("mirror missing MirrorGateA")
			elif tid == "afterglow_overpass" and neon_scenery.get_node_or_null("OverpassNorth") == null:
				failures.append("afterglow missing OverpassNorth")
			elif tid == "signal_storm_yard" and neon_scenery.get_node_or_null("SignalGantry") == null:
				failures.append("signal missing SignalGantry")
		neon_course.queue_free()
	var art := TrackArtAcceptanceScript.counts()
	if int(art.get("raceable", 0)) != 32:
		failures.append("track art raceable %s" % str(art.get("raceable")))
	if int(art.get("final_track_art_approved", 0)) != 0:
		failures.append("track commercial approved must be 0")
	if not TrackArtAcceptanceScript.procedural_never_satisfies_commercial():
		failures.append("track art commercial leak")
	## Cup flow still starts all eight.
	var gm = preload("res://scripts/core/GameManager.gd").new()
	root.add_child(gm)
	for cup_id in cups:
		var cup := TrackCatalogScript.load_cup(str(cup_id))
		if cup.is_empty():
			failures.append("cup load %s" % cup_id)
			continue
		if not gm.start_cup(str(cup_id), cup.get("track_ids", [])):
			failures.append("start_cup %s" % cup_id)
		gm.clear_cup()

	if failures.is_empty():
		print(
			"ChampionshipCatalogTest PASS — cups 8 · tracks 32 · raceable 32 · art candidates %d · pending %d"
			% [int(art.get("final_track_art_candidate", 0)), int(art.get("final_track_art_pending", 0))]
		)
		quit(0)
		return
	print("ChampionshipCatalogTest FAIL:")
	for f in failures:
		print(" - ", f)
	quit(1)
