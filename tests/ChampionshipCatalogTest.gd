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
		"rooftop_ribbon",
		"marble_foyer_loop",
		"cascade_colossus",
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
	## Cups 1–2: championship_upgraded with landmarks + chase cameras; collision stays lap-safe.
	var prism := TrackCatalogScript.load_track("prism_apex")
	if str(prism.get("geometry_status", "")) != "championship_upgraded":
		failures.append("prism_apex not championship_upgraded")
	if (prism.get("landmarks", []) as Array).is_empty():
		failures.append("prism_apex missing landmarks")
	if absf(float(prism.get("bank_bias", 0.0))) < 0.05:
		failures.append("prism_apex missing bank metadata")
	var sole_stride_cams := {
		"verdant_cascade_circuit": "cascade_chase",
		"cloverwind_ranch": "ranch_chase",
		"prism_apex": "prism_chase",
		"emberkeep_gauntlet": "ember_chase",
		"tideglass_harbor": "harbor_chase",
		"neon_switchyard": "neon_yard_chase",
		"cloudstep_ridge": "ridge_chase",
		"mirage_mesa": "mesa_chase",
	}
	var sole_stride_fill := {
		"verdant_cascade_circuit": "CascadeFill",
		"cloverwind_ranch": "RanchFill",
		"prism_apex": "PrismFill",
		"emberkeep_gauntlet": "EmberFill",
		"tideglass_harbor": "HarborFill",
		"neon_switchyard": "NeonYardFill",
		"cloudstep_ridge": "RidgeFill",
		"mirage_mesa": "MesaFill",
	}
	for tid in sole_stride_cams.keys():
		var ss := TrackCatalogScript.load_track(str(tid))
		if str(ss.get("camera_identity", "")) != str(sole_stride_cams[tid]):
			failures.append("%s missing camera %s" % [tid, sole_stride_cams[tid]])
		if bool(ss.get("human_track_art_approved", false)):
			failures.append("%s commercial art leak" % tid)
		var ss_course: Node = CourseTrackScript.new()
		root.add_child(ss_course)
		ss_course.configure(ss)
		if not ss_course.build():
			failures.append("build sole/stride %s" % tid)
		elif ss_course.get_node_or_null(str(sole_stride_fill[tid])) == null:
			failures.append("%s missing %s lighting" % [tid, sole_stride_fill[tid]])
		ss_course.queue_free()
	## Cup 3 Metro Motion: elevation + distinct scenery; art may be candidate (not commercial).
	var metro_landmarks := {
		"sneaker_city_sprintway": "BillboardArch",
		"metro_pulse_loop": "PulseStation",
		"crosswalk_canyon": "CanyonSignal",
		"transit_spiral": "SpiralTower",
	}
	for tid in ["sneaker_city_sprintway", "metro_pulse_loop", "crosswalk_canyon", "transit_spiral"]:
		var d := TrackCatalogScript.load_track(tid)
		var has_y := false
		for p in d.get("path_points", []):
			if typeof(p) == TYPE_ARRAY and p.size() == 3 and absf(float(p[1])) > 0.1:
				has_y = true
				break
		if not has_y:
			failures.append("%s missing elevation" % tid)
		var fas := str(d.get("final_track_art_status", ""))
		if fas not in ["track_art_candidate", "track_art_pending"]:
			failures.append("%s unexpected art status %s" % [tid, fas])
		if bool(d.get("human_track_art_approved", false)):
			failures.append("%s commercial art must stay false" % tid)
		if str(d.get("camera_identity", "")) != "metro_chase":
			failures.append("%s missing metro camera identity" % tid)
		var metro_course: Node = CourseTrackScript.new()
		root.add_child(metro_course)
		metro_course.configure(d)
		if not metro_course.build():
			failures.append("build metro %s" % tid)
		else:
			var metro_scenery := metro_course.get_node_or_null("Scenery")
			var want := str(metro_landmarks.get(tid, ""))
			if metro_scenery == null:
				failures.append("%s missing Scenery" % tid)
			elif want != "" and metro_scenery.get_node_or_null(want) == null:
				failures.append("%s missing %s" % [tid, want])
			if metro_course.get_node_or_null("WorldEnvironment") == null:
				failures.append("%s missing WorldEnvironment lighting" % tid)
			if metro_course.get_node_or_null("MetroFill") == null:
				failures.append("%s missing MetroFill lighting" % tid)
		metro_course.queue_free()
	## Cup 4 Kinetic Coast: elevation + distinct scenery; art may be candidate (not commercial).
	var coast := TrackCatalogScript.load_cup("kinetic_coast_cup")
	var coast_ids: Array = coast.get("track_ids", [])
	if coast_ids.size() != 4:
		failures.append("kinetic_coast size")
	var coast_landmarks := {
		"saltline_boardwalk": "PierArch",
		"cliffside_draft": "CliffCairn",
		"tidal_bridge_run": "NorthBridge",
		"seaglass_switchback": "SeaglassSpire",
	}
	for tid in ["saltline_boardwalk", "cliffside_draft", "tidal_bridge_run", "seaglass_switchback"]:
		if tid not in coast_ids:
			failures.append("kinetic_coast missing %s" % tid)
		var cd := TrackCatalogScript.load_track(tid)
		var coast_gs := str(cd.get("geometry_status", ""))
		if coast_gs not in ["championship_upgraded", "championship_raceable"]:
			failures.append("%s unexpected geometry %s" % [tid, coast_gs])
		var coast_fas := str(cd.get("final_track_art_status", ""))
		if coast_fas not in ["track_art_candidate", "track_art_pending"]:
			failures.append("%s unexpected art status %s" % [tid, coast_fas])
		if bool(cd.get("human_track_art_approved", false)):
			failures.append("%s commercial art must stay false" % tid)
		if str(cd.get("camera_identity", "")) != "coast_chase":
			failures.append("%s missing coast camera identity" % tid)
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
			var want_coast := str(coast_landmarks.get(tid, ""))
			if scenery == null:
				failures.append("%s missing Scenery" % tid)
			elif want_coast != "" and scenery.get_node_or_null(want_coast) == null:
				failures.append("%s missing %s" % [tid, want_coast])
			if coast_course.get_node_or_null("WorldEnvironment") == null:
				failures.append("%s missing WorldEnvironment lighting" % tid)
			if coast_course.get_node_or_null("CoastFill") == null:
				failures.append("%s missing CoastFill lighting" % tid)
		coast_course.queue_free()
	## Cup 5 Neon Night: upgraded candidates with NeonFill env/collision/audio.
	var neon := TrackCatalogScript.load_cup("neon_night_cup")
	var neon_ids: Array = neon.get("track_ids", [])
	if neon_ids.size() != 4:
		failures.append("neon_night size")
	var neon_landmarks := {
		"lantern_corridor": "LanternCanopy",
		"mirror_boulevard": "MirrorGateA",
		"afterglow_overpass": "OverpassNorth",
		"signal_storm_yard": "SignalGantry",
	}
	for tid in ["lantern_corridor", "mirror_boulevard", "afterglow_overpass", "signal_storm_yard"]:
		if tid not in neon_ids:
			failures.append("neon_night missing %s" % tid)
		var nd := TrackCatalogScript.load_track(tid)
		if str(nd.get("geometry_status", "")) != "championship_upgraded":
			failures.append("%s not championship_upgraded" % tid)
		if str(nd.get("final_track_art_status", "")) != "track_art_candidate":
			failures.append("%s art must be candidate" % tid)
		if bool(nd.get("human_track_art_approved", false)):
			failures.append("%s commercial art must stay false" % tid)
		if str(nd.get("camera_identity", "")) != "neon_chase":
			failures.append("%s missing neon camera identity" % tid)
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
			var want_neon := str(neon_landmarks.get(tid, ""))
			if neon_scenery == null:
				failures.append("%s missing Scenery" % tid)
			elif want_neon != "" and neon_scenery.get_node_or_null(want_neon) == null:
				failures.append("%s missing %s" % [tid, want_neon])
			if neon_course.get_node_or_null("WorldEnvironment") == null:
				failures.append("%s missing WorldEnvironment lighting" % tid)
			if neon_course.get_node_or_null("NeonFill") == null:
				failures.append("%s missing NeonFill lighting" % tid)
		neon_course.queue_free()
	## Cup 6 Skyline Relay: upgraded candidates with SkylineFill.
	var sky := TrackCatalogScript.load_cup("skyline_relay_cup")
	var sky_ids: Array = sky.get("track_ids", [])
	if sky_ids.size() != 4:
		failures.append("skyline_relay size")
	var sky_landmarks := {
		"rooftop_ribbon": "BillboardArch",
		"skybridge_sprint": "BridgeTowerA",
		"antenna_ascent": "AntennaMast",
		"cloud_deck_circuit": "ObsSpire",
	}
	for tid in ["rooftop_ribbon", "skybridge_sprint", "antenna_ascent", "cloud_deck_circuit"]:
		if tid not in sky_ids:
			failures.append("skyline_relay missing %s" % tid)
		var sd := TrackCatalogScript.load_track(tid)
		if str(sd.get("geometry_status", "")) != "championship_upgraded":
			failures.append("%s not championship_upgraded" % tid)
		if str(sd.get("final_track_art_status", "")) != "track_art_candidate":
			failures.append("%s art must be candidate" % tid)
		if bool(sd.get("human_track_art_approved", false)):
			failures.append("%s commercial art must stay false" % tid)
		if str(sd.get("camera_identity", "")) != "skyline_chase":
			failures.append("%s missing skyline camera identity" % tid)
		var sky_has_y := false
		for p in sd.get("path_points", []):
			if typeof(p) == TYPE_ARRAY and p.size() == 3 and absf(float(p[1])) > 0.1:
				sky_has_y = true
				break
		if not sky_has_y:
			failures.append("%s missing elevation" % tid)
		if (sd.get("landmarks", []) as Array).size() < 2:
			failures.append("%s needs distinct landmarks" % tid)
		var sky_course: Node = CourseTrackScript.new()
		root.add_child(sky_course)
		sky_course.configure(sd)
		if not sky_course.build():
			failures.append("build skyline %s" % tid)
		else:
			var sky_scenery := sky_course.get_node_or_null("Scenery")
			var want_sky := str(sky_landmarks.get(tid, ""))
			if sky_scenery == null:
				failures.append("%s missing Scenery" % tid)
			elif want_sky != "" and sky_scenery.get_node_or_null(want_sky) == null:
				failures.append("%s missing %s" % [tid, want_sky])
			if sky_course.get_node_or_null("WorldEnvironment") == null:
				failures.append("%s missing WorldEnvironment lighting" % tid)
			if sky_course.get_node_or_null("SkylineFill") == null:
				failures.append("%s missing SkylineFill lighting" % tid)
		sky_course.queue_free()
	## Cup 7 Archive Relay: upgraded tribute candidates with ArchiveFill.
	var archive := TrackCatalogScript.load_cup("archive_relay_cup")
	var archive_ids: Array = archive.get("track_ids", [])
	if archive_ids.size() != 4:
		failures.append("archive_relay size")
	var archive_landmarks := {
		"marble_foyer_loop": "FoyerArch",
		"stack_corridor": "ShelfRowA",
		"gallery_grand_oval": "SkylightBank",
		"vault_gate_gauntlet": "VaultArch",
	}
	for tid in ["marble_foyer_loop", "stack_corridor", "gallery_grand_oval", "vault_gate_gauntlet"]:
		if tid not in archive_ids:
			failures.append("archive_relay missing %s" % tid)
		var ad := TrackCatalogScript.load_track(tid)
		if str(ad.get("geometry_status", "")) != "championship_upgraded":
			failures.append("%s not championship_upgraded" % tid)
		if str(ad.get("final_track_art_status", "")) != "track_art_candidate":
			failures.append("%s art must be candidate" % tid)
		if bool(ad.get("human_track_art_approved", false)):
			failures.append("%s commercial art must stay false" % tid)
		if str(ad.get("tribute_note", "")).is_empty():
			failures.append("%s missing tribute honesty note" % tid)
		if str(ad.get("camera_identity", "")) != "archive_chase":
			failures.append("%s missing archive camera identity" % tid)
		var archive_has_y := false
		for p in ad.get("path_points", []):
			if typeof(p) == TYPE_ARRAY and p.size() == 3 and absf(float(p[1])) > 0.1:
				archive_has_y = true
				break
		if not archive_has_y:
			failures.append("%s missing elevation" % tid)
		if (ad.get("landmarks", []) as Array).size() < 2:
			failures.append("%s needs distinct landmarks" % tid)
		var archive_course: Node = CourseTrackScript.new()
		root.add_child(archive_course)
		archive_course.configure(ad)
		if not archive_course.build():
			failures.append("build archive %s" % tid)
		else:
			var archive_scenery := archive_course.get_node_or_null("Scenery")
			var want_archive := str(archive_landmarks.get(tid, ""))
			if archive_scenery == null:
				failures.append("%s missing Scenery" % tid)
			elif want_archive != "" and archive_scenery.get_node_or_null(want_archive) == null:
				failures.append("%s missing %s" % [tid, want_archive])
			if archive_course.get_node_or_null("WorldEnvironment") == null:
				failures.append("%s missing WorldEnvironment lighting" % tid)
			if archive_course.get_node_or_null("ArchiveFill") == null:
				failures.append("%s missing ArchiveFill lighting" % tid)
		archive_course.queue_free()
	## Cup 8 World Wonder Grand Prix: upgraded candidates with WonderFill.
	var wonder := TrackCatalogScript.load_cup("world_wonder_grand_prix")
	var wonder_ids: Array = wonder.get("track_ids", [])
	if wonder_ids.size() != 4:
		failures.append("world_wonder size")
	var wonder_landmarks := {
		"cascade_colossus": "ColossusFalls",
		"aurora_amphitheater": "AuroraRim",
		"origami_orchard": "PaperSpire",
		"horizon_crown_finale": "CrownArchNorth",
	}
	for tid in ["cascade_colossus", "aurora_amphitheater", "origami_orchard", "horizon_crown_finale"]:
		if tid not in wonder_ids:
			failures.append("world_wonder missing %s" % tid)
		var wd := TrackCatalogScript.load_track(tid)
		if str(wd.get("geometry_status", "")) != "championship_upgraded":
			failures.append("%s not championship_upgraded" % tid)
		if str(wd.get("final_track_art_status", "")) != "track_art_candidate":
			failures.append("%s art must be candidate" % tid)
		if bool(wd.get("human_track_art_approved", false)):
			failures.append("%s commercial art must stay false" % tid)
		if str(wd.get("camera_identity", "")) != "wonder_chase":
			failures.append("%s missing wonder camera identity" % tid)
		var wonder_has_y := false
		for p in wd.get("path_points", []):
			if typeof(p) == TYPE_ARRAY and p.size() == 3 and absf(float(p[1])) > 0.1:
				wonder_has_y = true
				break
		if not wonder_has_y:
			failures.append("%s missing elevation" % tid)
		if (wd.get("landmarks", []) as Array).size() < 2:
			failures.append("%s needs distinct landmarks" % tid)
		var wonder_course: Node = CourseTrackScript.new()
		root.add_child(wonder_course)
		wonder_course.configure(wd)
		if not wonder_course.build():
			failures.append("build wonder %s" % tid)
		else:
			var wonder_scenery := wonder_course.get_node_or_null("Scenery")
			var want_wonder := str(wonder_landmarks.get(tid, ""))
			if wonder_scenery == null:
				failures.append("%s missing Scenery" % tid)
			elif want_wonder != "" and wonder_scenery.get_node_or_null(want_wonder) == null:
				failures.append("%s missing %s" % [tid, want_wonder])
			if wonder_course.get_node_or_null("WorldEnvironment") == null:
				failures.append("%s missing WorldEnvironment lighting" % tid)
			if wonder_course.get_node_or_null("WonderFill") == null:
				failures.append("%s missing WonderFill lighting" % tid)
		wonder_course.queue_free()
	## All 32 tracks must be championship_upgraded (no stubs / no pending-only raceable).
	var stub_left := 0
	var pending_left := 0
	for tid_all in TrackCatalogScript.list_all_track_ids():
		var gd := TrackCatalogScript.load_track(str(tid_all))
		var gs := str(gd.get("geometry_status", ""))
		if gs == "championship_stub_raceable":
			stub_left += 1
		elif gs != "championship_upgraded":
			failures.append("%s unexpected geometry %s" % [tid_all, gs])
		if str(gd.get("final_track_art_status", "")) == "track_art_pending":
			pending_left += 1
		if bool(gd.get("human_track_art_approved", false)):
			failures.append("%s commercial art leak" % tid_all)
	if stub_left != 0:
		failures.append("stub tracks remaining %d" % stub_left)
	if pending_left != 0:
		failures.append("track_art_pending remaining %d" % pending_left)
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

	if int(art.get("final_track_art_candidate", 0)) != 32:
		failures.append("expected 32 track_art_candidate, got %s" % str(art.get("final_track_art_candidate")))
	if int(art.get("final_track_art_pending", 0)) != 0:
		failures.append("expected 0 track_art_pending, got %s" % str(art.get("final_track_art_pending")))
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
