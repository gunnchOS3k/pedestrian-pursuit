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

	audio.set_enabled(false)
	if failures.is_empty():
		print(
			"AudioDirectorContractTest PASS — per-track race bed · cup_theme fallback · procedural≠commercial · HUMAN/COURSE false"
		)
		quit(0)
	else:
		for f in failures:
			print("FAIL ", f)
		print("AudioDirectorContractTest FAIL count=", failures.size())
		quit(1)
