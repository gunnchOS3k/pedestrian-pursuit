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
	## Elevation present on Cups 1–3 production batch.
	for tid in ["prism_apex", "transit_spiral", "sneaker_city_sprintway"]:
		var d := TrackCatalogScript.load_track(tid)
		var has_y := false
		for p in d.get("path_points", []):
			if typeof(p) == TYPE_ARRAY and p.size() == 3 and absf(float(p[1])) > 0.1:
				has_y = true
				break
		if not has_y:
			failures.append("%s missing elevation" % tid)
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
