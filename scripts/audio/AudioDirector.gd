extends Node

## Launch audio director — loads procedural WAV banks and plays music/SFX/UI.
## Missing streams fail soft (digital headless / CI without import still OK).

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const UI_DIR := "res://assets/audio/ui/"
const AMB_DIR := "res://assets/audio/ambience/"

var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _enabled: bool = true
var _cache: Dictionary = {}
var _last_music_path: String = ""
var _last_ambience_path: String = ""
var _last_music_fallback: bool = false
var _last_ambience_fallback: bool = false


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "MusicPlayer"
	_music.bus = "Master"
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "AmbiencePlayer"
	_ambience.volume_db = -8.0
	add_child(_ambience)
	_sfx = AudioStreamPlayer.new()
	_sfx.name = "SfxPlayer"
	add_child(_sfx)
	_ui = AudioStreamPlayer.new()
	_ui.name = "UiPlayer"
	add_child(_ui)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		stop_music()


func play_menu_music() -> void:
	_play_loop(_music, MUSIC_DIR + "menu_theme.wav", -6.0)


func play_cup_music() -> void:
	_play_loop(_music, MUSIC_DIR + "cup_theme.wav", -6.0)


func play_race_music(track_id: String) -> void:
	## Prefer per-track race bed; fall back to cup_theme so cups never go silent digitally.
	## Missing banks still fail soft — not commercial/final audio, not HUMAN.
	var preferred := MUSIC_DIR + "%s_race.wav" % track_id
	var music_path := preferred
	_last_music_fallback = false
	if not FileAccess.file_exists(music_path):
		music_path = MUSIC_DIR + "cup_theme.wav"
		_last_music_fallback = true
	_last_music_path = music_path
	_play_loop(_music, music_path, -5.0)
	var amb := AMB_DIR + "%s.wav" % track_id
	_last_ambience_fallback = false
	if not FileAccess.file_exists(amb):
		amb = AMB_DIR + "verdant_cascade_circuit.wav"
		_last_ambience_fallback = true
	_last_ambience_path = amb
	_play_loop(_ambience, amb, -10.0)


func play_results() -> void:
	_play_oneshot(_music, MUSIC_DIR + "results_fanfare.wav", -4.0)


func stop_music() -> void:
	if _music:
		_music.stop()
	if _ambience:
		_ambience.stop()


func play_ui(name: String) -> void:
	_play_oneshot(_ui, UI_DIR + "%s.wav" % name, -2.0)


func play_sfx(name: String) -> void:
	_play_oneshot(_sfx, SFX_DIR + "%s.wav" % name, -1.0)


func play_item(item_id: String) -> void:
	play_sfx("item_%s" % item_id)


func play_footstep(surface: String) -> void:
	var key := surface if surface in ["asphalt", "grass", "mud", "ash", "sand", "metal", "wet"] else "asphalt"
	play_sfx("footstep_%s" % key)


func has_bank(path: String) -> bool:
	return FileAccess.file_exists(path)


func describe() -> Dictionary:
	return {
		"schema": "pp_audio_director/v1",
		"enabled": _enabled,
		"music_dir": MUSIC_DIR,
		"sfx_dir": SFX_DIR,
		"procedural_final": true,
		"commercial_final_audio": false,
		"last_music_path": _last_music_path,
		"last_ambience_path": _last_ambience_path,
		"last_music_fallback": _last_music_fallback,
		"last_ambience_fallback": _last_ambience_fallback,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
	}


func resolve_championship_music_coverage(track_ids: PackedStringArray) -> Dictionary:
	## Digital deepen: every championship track resolves a race bed path (preferred or cup_theme).
	## Does not claim commercial/final audio or HUMAN acceptance.
	var preferred_hits := 0
	var fallback_hits := 0
	var missing_paths := 0
	for tid in track_ids:
		var preferred := MUSIC_DIR + "%s_race.wav" % tid
		if FileAccess.file_exists(preferred):
			preferred_hits += 1
		elif FileAccess.file_exists(MUSIC_DIR + "cup_theme.wav"):
			fallback_hits += 1
		else:
			missing_paths += 1
	return {
		"schema": "pp_audio_championship_coverage/v1",
		"track_count": track_ids.size(),
		"preferred_hits": preferred_hits,
		"cup_theme_fallback_hits": fallback_hits,
		"missing_paths": missing_paths,
		"commercial_final_audio": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
	}


func resolve_championship_ambience_coverage(track_ids: PackedStringArray) -> Dictionary:
	## Audio deepen: every championship track resolves ambience (preferred or verdant fallback).
	## Procedural banks ≠ commercial final; COURSE/HUMAN false.
	var preferred_hits := 0
	var fallback_hits := 0
	var missing_paths := 0
	var verdant_fallback := AMB_DIR + "verdant_cascade_circuit.wav"
	for tid in track_ids:
		var preferred := AMB_DIR + "%s.wav" % tid
		if FileAccess.file_exists(preferred):
			preferred_hits += 1
		elif FileAccess.file_exists(verdant_fallback):
			fallback_hits += 1
		else:
			missing_paths += 1
	return {
		"schema": "pp_audio_championship_ambience_coverage/v1",
		"track_count": track_ids.size(),
		"preferred_hits": preferred_hits,
		"ambience_fallback_hits": fallback_hits,
		"missing_paths": missing_paths,
		"commercial_final_audio": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
	}


func resolve_footstep_surface_coverage() -> Dictionary:
	## S7O audio deepen: every kinetic footstep surface resolves a bank (or asphalt fallback).
	## Procedural SFX ≠ commercial final; COURSE/HUMAN false.
	var surfaces: PackedStringArray = PackedStringArray([
		"asphalt", "grass", "mud", "ash", "sand", "metal", "wet"
	])
	var preferred_hits := 0
	var asphalt_fallback_hits := 0
	var missing_paths := 0
	var asphalt_path := SFX_DIR + "footstep_asphalt.wav"
	for surface in surfaces:
		var preferred := SFX_DIR + "footstep_%s.wav" % surface
		if FileAccess.file_exists(preferred):
			preferred_hits += 1
		elif FileAccess.file_exists(asphalt_path):
			asphalt_fallback_hits += 1
		else:
			missing_paths += 1
	return {
		"schema": "pp_audio_footstep_surface_coverage/v1",
		"surface_count": surfaces.size(),
		"preferred_hits": preferred_hits,
		"asphalt_fallback_hits": asphalt_fallback_hits,
		"missing_paths": missing_paths,
		"commercial_final_audio": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
	}


func resolve_ui_cue_coverage() -> Dictionary:
	## S7P audio deepen: core UI cues resolve on disk. Procedural ≠ commercial final.
	var cues: PackedStringArray = PackedStringArray([
		"back", "confirm", "countdown", "finish", "select", "start"
	])
	var hits := 0
	var missing_paths := 0
	for cue in cues:
		var path := UI_DIR + "%s.wav" % cue
		if FileAccess.file_exists(path):
			hits += 1
		else:
			missing_paths += 1
	return {
		"schema": "pp_audio_ui_cue_coverage/v1",
		"cue_count": cues.size(),
		"preferred_hits": hits,
		"missing_paths": missing_paths,
		"commercial_final_audio": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


func resolve_menu_results_music_coverage() -> Dictionary:
	## S7Q audio deepen: menu / cup / results beds resolve. Procedural ≠ commercial.
	var beds: PackedStringArray = PackedStringArray([
		"menu_theme.wav", "cup_theme.wav", "results_fanfare.wav"
	])
	var hits := 0
	var missing_paths := 0
	for bed in beds:
		if FileAccess.file_exists(MUSIC_DIR + bed):
			hits += 1
		else:
			missing_paths += 1
	return {
		"schema": "pp_audio_menu_results_music_coverage/v1",
		"bed_count": beds.size(),
		"preferred_hits": hits,
		"missing_paths": missing_paths,
		"commercial_final_audio": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


func resolve_item_sfx_coverage() -> Dictionary:
	## S7R audio deepen: launch item SFX banks resolve. Procedural ≠ commercial.
	var items: PackedStringArray = PackedStringArray([
		"box", "bounce_bubble", "lace_trap", "magnet_lace", "pulse_horn", "sole_shield", "turbo_toes"
	])
	var hits := 0
	var missing_paths := 0
	for item_id in items:
		var path := SFX_DIR + "item_%s.wav" % item_id
		if FileAccess.file_exists(path):
			hits += 1
		else:
			missing_paths += 1
	return {
		"schema": "pp_audio_item_sfx_coverage/v1",
		"item_count": items.size(),
		"preferred_hits": hits,
		"missing_paths": missing_paths,
		"commercial_final_audio": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


func resolve_ambience_bank_integrity(track_ids: PackedStringArray) -> Dictionary:
	## S7U audio deepen: per-track ambience banks resolve; procedural ≠ commercial.
	var hits := 0
	var missing_paths := 0
	for tid in track_ids:
		var path := AMB_DIR + "%s.wav" % tid
		if FileAccess.file_exists(path):
			hits += 1
		else:
			missing_paths += 1
	return {
		"schema": "pp_audio_ambience_bank_integrity/v1",
		"track_count": track_ids.size(),
		"preferred_hits": hits,
		"missing_paths": missing_paths,
		"path_integrity_ok": missing_paths == 0 and hits == track_ids.size() and track_ids.size() == 32,
		"commercial_final_audio": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


func resolve_ui_core_cue_path_integrity() -> Dictionary:
	## S7T audio deepen: core UI cue paths stay present; procedural ≠ commercial.
	var cues: PackedStringArray = PackedStringArray([
		"back", "confirm", "countdown", "finish", "select", "start"
	])
	var hits := 0
	var missing_paths := 0
	for cue in cues:
		var path := UI_DIR + "%s.wav" % cue
		if FileAccess.file_exists(path):
			hits += 1
		else:
			missing_paths += 1
	return {
		"schema": "pp_audio_ui_core_cue_path_integrity/v1",
		"cue_count": cues.size(),
		"preferred_hits": hits,
		"missing_paths": missing_paths,
		"path_integrity_ok": missing_paths == 0 and hits == cues.size(),
		"commercial_final_audio": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


func resolve_race_control_sfx_coverage() -> Dictionary:
	## S7S audio deepen: race-control SFX banks resolve. Procedural ≠ commercial.
	var cues: PackedStringArray = PackedStringArray([
		"boost", "checkpoint", "drift", "jump", "stomp"
	])
	var hits := 0
	var missing_paths := 0
	for cue in cues:
		var path := SFX_DIR + "%s.wav" % cue
		if FileAccess.file_exists(path):
			hits += 1
		else:
			missing_paths += 1
	return {
		"schema": "pp_audio_race_control_sfx_coverage/v1",
		"cue_count": cues.size(),
		"preferred_hits": hits,
		"missing_paths": missing_paths,
		"commercial_final_audio": false,
		"HUMAN": false,
		"COURSE_ACCEPTED": false,
		"RC2": false,
		"V1": false,
	}


func _play_loop(player: AudioStreamPlayer, path: String, volume_db: float) -> void:
	if not _enabled or player == null:
		return
	var stream := _load_stream(path)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _play_oneshot(player: AudioStreamPlayer, path: String, volume_db: float) -> void:
	if not _enabled or player == null:
		return
	var stream := _load_stream(path)
	if stream == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _load_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return null
	var stream = load(path)
	if stream is AudioStream:
		_cache[path] = stream
		return stream
	return null
