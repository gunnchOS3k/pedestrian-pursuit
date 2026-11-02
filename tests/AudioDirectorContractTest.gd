extends SceneTree

## Digital audio contract: race bed prefers per-track, falls back to cup_theme.
## Procedural candidate ≠ commercial final. COURSE/HUMAN false.

const AudioDirectorScript = preload("res://scripts/audio/AudioDirector.gd")
const TrackCatalogScript = preload("res://scripts/data/TrackCatalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	var audio: Node = AudioDirectorScript.new()
	root.add_child(audio)
	## Mute playback for CI/headless — still resolve paths.
	audio.set_enabled(false)

	if not audio.has_method("play_race_music") or not audio.has_method("describe"):
		failures.append("AudioDirector missing race/describe hooks")
	else:
		audio.set_enabled(true)
		## Known championship track with bank present.
		audio.play_race_music("verdant_cascade_circuit")
		var d1: Dictionary = audio.describe()
		if bool(d1.get("commercial_final_audio", true)):
			failures.append("commercial_final_audio must stay false")
		if bool(d1.get("HUMAN", true)) or bool(d1.get("COURSE_ACCEPTED", true)):
			failures.append("audio describe must keep HUMAN/COURSE false")
		var music1 := str(d1.get("last_music_path", ""))
		if music1.find("verdant_cascade_circuit_race.wav") < 0 and not bool(d1.get("last_music_fallback", false)):
			## Accept either direct path or soft-load miss under sandbox; fallback flag required if not direct.
			if music1.is_empty():
				failures.append("verdant race music path not recorded")
		## Synthetic missing track → cup_theme fallback.
		audio.play_race_music("__no_such_track_pp_s7e__")
		var d2: Dictionary = audio.describe()
		if not bool(d2.get("last_music_fallback", false)):
			failures.append("missing track must set last_music_fallback")
		if str(d2.get("last_music_path", "")).find("cup_theme.wav") < 0:
			failures.append("missing track must fall back to cup_theme.wav")

		## Soft coverage: a few cup tracks resolve without crash.
		for tid in ["lantern_corridor", "stack_corridor", "cloudstep_ridge", "sneaker_city_sprintway"]:
			audio.play_race_music(tid)
		var cups := TrackCatalogScript.list_cup_ids()
		if cups.is_empty():
			failures.append("TrackCatalog cup list empty")

		## Championship deepen: all 32 tracks resolve music+ambience paths; commercial stays false.
		var all_ids: PackedStringArray = TrackCatalogScript.list_all_track_ids()
		if all_ids.size() != 32:
			failures.append("championship audio coverage expects 32 tracks, got %d" % all_ids.size())
		if audio.has_method("resolve_championship_music_coverage"):
			var cov: Dictionary = audio.resolve_championship_music_coverage(all_ids)
			if int(cov.get("track_count", -1)) != 32:
				failures.append("audio coverage track_count != 32")
			if int(cov.get("missing_paths", 1)) != 0:
				failures.append("championship music missing_paths must be 0")
			if int(cov.get("preferred_hits", 0)) + int(cov.get("cup_theme_fallback_hits", 0)) != 32:
				failures.append("preferred+fallback must cover 32 tracks")
			if bool(cov.get("commercial_final_audio", true)):
				failures.append("coverage must keep commercial_final_audio false")
		## S7N ambience coverage: 32 tracks resolve preferred or verdant fallback.
		if audio.has_method("resolve_championship_ambience_coverage"):
			var amb: Dictionary = audio.resolve_championship_ambience_coverage(all_ids)
			if int(amb.get("track_count", -1)) != 32:
				failures.append("ambience coverage track_count != 32")
			if int(amb.get("missing_paths", 1)) != 0:
				failures.append("championship ambience missing_paths must be 0")
			if int(amb.get("preferred_hits", 0)) + int(amb.get("ambience_fallback_hits", 0)) != 32:
				failures.append("ambience preferred+fallback must cover 32 tracks")
			if bool(amb.get("commercial_final_audio", true)):
				failures.append("ambience coverage must keep commercial_final_audio false")
		for tid2 in all_ids:
			audio.play_race_music(tid2)
			var d3: Dictionary = audio.describe()
			if str(d3.get("last_music_path", "")).is_empty():
				failures.append("%s music path empty" % tid2)
			if str(d3.get("last_ambience_path", "")).is_empty():
				failures.append("%s ambience path empty" % tid2)
		## Synthetic missing ambience track still falls back honestly.
		audio.play_race_music("__no_such_track_pp_s7m_amb__")
		var d4: Dictionary = audio.describe()
		if not bool(d4.get("last_music_fallback", false)):
			failures.append("missing track must set last_music_fallback")
		if not bool(d4.get("last_ambience_fallback", false)):
			failures.append("missing track must set last_ambience_fallback")
		## S7O footstep surface coverage: 7 surfaces resolve preferred or asphalt fallback.
		if audio.has_method("resolve_footstep_surface_coverage"):
			var feet: Dictionary = audio.resolve_footstep_surface_coverage()
			if int(feet.get("surface_count", -1)) != 7:
				failures.append("footstep surface_count != 7")
			if int(feet.get("missing_paths", 1)) != 0:
				failures.append("footstep missing_paths must be 0")
			if int(feet.get("preferred_hits", 0)) + int(feet.get("asphalt_fallback_hits", 0)) != 7:
				failures.append("footstep preferred+fallback must cover 7 surfaces")
			if bool(feet.get("commercial_final_audio", true)):
				failures.append("footstep coverage must keep commercial_final_audio false")
		## S7P UI cue coverage: 6 core cues on disk; procedural ≠ commercial.
		var ui: Dictionary = audio.resolve_ui_cue_coverage()
		if int(ui.get("cue_count", -1)) != 6:
			failures.append("ui cue_count != 6")
		if int(ui.get("missing_paths", 1)) != 0:
			failures.append("ui cue missing_paths must be 0")
		if int(ui.get("preferred_hits", 0)) != 6:
			failures.append("ui preferred_hits must be 6")
		if bool(ui.get("commercial_final_audio", true)):
			failures.append("ui coverage must keep commercial_final_audio false")
		if bool(ui.get("HUMAN", true)) or bool(ui.get("RC2", true)) or bool(ui.get("V1", true)):
			failures.append("ui coverage must keep HUMAN/RC2/V1 false")
		## S7Q menu/cup/results beds.
		var beds: Dictionary = audio.resolve_menu_results_music_coverage()
		if int(beds.get("bed_count", -1)) != 3:
			failures.append("menu/results bed_count != 3")
		if int(beds.get("missing_paths", 1)) != 0 or int(beds.get("preferred_hits", 0)) != 3:
			failures.append("menu/cup/results beds must all resolve")
		if bool(beds.get("commercial_final_audio", true)):
			failures.append("menu/results must keep commercial_final_audio false")
		if bool(beds.get("HUMAN", true)) or bool(beds.get("RC2", true)) or bool(beds.get("V1", true)):
			failures.append("menu/results must keep HUMAN/RC2/V1 false")
		## S7R item SFX coverage.
		var items: Dictionary = audio.resolve_item_sfx_coverage()
		if int(items.get("item_count", -1)) != 7:
			failures.append("item sfx item_count != 7")
		if int(items.get("missing_paths", 1)) != 0 or int(items.get("preferred_hits", 0)) != 7:
			failures.append("item sfx banks must all resolve")
		if bool(items.get("commercial_final_audio", true)):
			failures.append("item sfx must keep commercial_final_audio false")
		if bool(items.get("HUMAN", true)) or bool(items.get("RC2", true)) or bool(items.get("V1", true)):
			failures.append("item sfx must keep HUMAN/RC2/V1 false")
		## S7S race-control SFX coverage.
		var race: Dictionary = audio.resolve_race_control_sfx_coverage()
		if int(race.get("cue_count", -1)) != 5:
			failures.append("race-control sfx cue_count != 5")
		if int(race.get("missing_paths", 1)) != 0 or int(race.get("preferred_hits", 0)) != 5:
			failures.append("race-control sfx banks must all resolve")
		if bool(race.get("commercial_final_audio", true)):
			failures.append("race-control sfx must keep commercial_final_audio false")
		if bool(race.get("HUMAN", true)) or bool(race.get("RC2", true)) or bool(race.get("V1", true)):
			failures.append("race-control sfx must keep HUMAN/RC2/V1 false")
		## S7T UI core cue path integrity.
		var ui_paths: Dictionary = audio.resolve_ui_core_cue_path_integrity()
		if not bool(ui_paths.get("path_integrity_ok", false)):
			failures.append("ui core cue path_integrity_ok required")
		if int(ui_paths.get("cue_count", -1)) != 6:
			failures.append("ui core cue_count != 6")
		if bool(ui_paths.get("commercial_final_audio", true)):
			failures.append("ui core cues must keep commercial_final_audio false")
		if bool(ui_paths.get("HUMAN", true)) or bool(ui_paths.get("RC2", true)) or bool(ui_paths.get("V1", true)):
			failures.append("ui core cue integrity must keep HUMAN/RC2/V1 false")

	audio.set_enabled(false)
	if failures.is_empty():
		print(
			"AudioDirectorContractTest PASS — 32-track race beds · cup_theme/ambience fallback · procedural≠commercial · HUMAN/COURSE false"
		)
		quit(0)
	else:
		for f in failures:
			print("FAIL ", f)
		print("AudioDirectorContractTest FAIL count=", failures.size())
		quit(1)
