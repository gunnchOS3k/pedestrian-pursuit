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
	_play_loop(_music, MUSIC_DIR + "%s_race.wav" % track_id, -5.0)
	_play_loop(_ambience, AMB_DIR + "%s.wav" % track_id, -10.0)


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
