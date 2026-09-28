extends Node
class_name RaceExperienceDirector
const CourseIdentityCatalogScript = preload("res://scripts/gamefeel/CourseIdentityCatalog.gd")

## Authored race journey: start, HUD facts, cues, highlights. Not a cutscene.

signal presentation_changed(snapshot: Dictionary)
signal caption_requested(text: String)
signal highlight_recorded(kind: String, payload: Dictionary)

const START_ESTABLISH_SEC := 0.35

var player: Node = null
var race_manager: Node = null
var track: Node = null
var course_data: Dictionary = {}
var identity: Dictionary = {}

var start_phase: String = "idle"
var go_released: bool = false
var last_caption: String = ""
var draft_phase: String = "none"
var boost_presenting: bool = false
var shortcut_cue: String = ""
var proximity_text: String = ""
var gap_text: String = ""
var final_lap: bool = false
var finish_approach: bool = false
var last_lap_seen: int = 0
var highlights: Array = []
var overtakes: int = 0
var shortcuts_taken: int = 0
var strongest_boost: float = 1.0
var _course_banner_left: float = 2.2


func setup(p_player: Node, p_race_manager: Node, p_track: Node, p_course: Dictionary) -> void:
	player = p_player
	race_manager = p_race_manager
	track = p_track
	course_data = p_course.duplicate(true)
	identity = CourseIdentityCatalogScript.identity_for(str(course_data.get("id", "")))
	start_phase = "establish"
	go_released = false
	_course_banner_left = 2.2
	if race_manager != null:
		if race_manager.has_signal("countdown_tick") and not race_manager.countdown_tick.is_connected(_on_countdown):
			race_manager.countdown_tick.connect(_on_countdown)
		if race_manager.has_signal("race_started") and not race_manager.race_started.is_connected(_on_go):
			race_manager.race_started.connect(_on_go)
		if race_manager.has_node("LapManager"):
			var laps: Node = race_manager.get_node("LapManager")
			if laps.has_signal("lap_changed") and not laps.lap_changed.is_connected(_on_lap_changed):
				laps.lap_changed.connect(_on_lap_changed)
	if player != null:
		var boost := player.get_node_or_null("BoostSystem")
		if boost != null:
			if boost.has_signal("boost_activated") and not boost.boost_activated.is_connected(_on_boost_on):
				boost.boost_activated.connect(_on_boost_on)
			if boost.has_signal("boost_ended") and not boost.boost_ended.is_connected(_on_boost_off):
				boost.boost_ended.connect(_on_boost_off)
		var draft := player.get_node_or_null("DraftingSystem")
		if draft != null and draft.has_signal("draft_phase_changed"):
			if not draft.draft_phase_changed.is_connected(_on_draft_phase):
				draft.draft_phase_changed.connect(_on_draft_phase)
	_emit()


func snapshot() -> Dictionary:
	var lap := 0
	var total := 3
	var place := 1
	var next_cp := 1
	var cp_count := 1
	if GameManager != null:
		total = int(GameManager.total_laps)
	if race_manager != null and player != null and race_manager.has_node("LapManager"):
		var lm = race_manager.get_node("LapManager")
		lap = int(lm.get_lap(player))
		next_cp = int(lm.get_next_checkpoint(player))
		cp_count = maxi(int(lm.checkpoint_count), 1)
	if race_manager != null and player != null and race_manager.has_node("PositionTracker"):
		place = int(race_manager.get_node("PositionTracker").get_position_for(player))
	var progress := clampf((float(lap) + float(next_cp) / float(cp_count)) / float(maxi(total, 1)), 0.0, 1.0)
	return {
		"position": place,
		"lap": mini(lap + 1, total),
		"total_laps": total,
		"progress": progress,
		"boost_active": boost_presenting,
		"draft_phase": draft_phase,
		"shortcut_cue": shortcut_cue,
		"proximity": proximity_text,
		"gap": gap_text,
		"course_name": str(identity.get("short_name", course_data.get("display_name", ""))),
		"course_banner_visible": _course_banner_left > 0.0 and start_phase != "racing",
		"final_lap": final_lap,
		"finish_approach": finish_approach,
		"start_phase": start_phase,
		"go_released": go_released,
		"caption": last_caption,
		"movement_enabled": player != null and bool(player.get("movement_enabled")),
		"hierarchy": {
			"primary": ["position", "lap_progress", "boost_or_draft", "shortcut_cue"],
			"secondary": ["proximity", "gap", "course_name"],
			"hidden_normal": ["footwear", "map_gps", "debug_metrics", "drift_spark_icon"],
		},
	}


func tick(delta: float, extra: Dictionary = {}) -> void:
	if extra.has("shortcut_cue"):
		shortcut_cue = str(extra.get("shortcut_cue", ""))
	if extra.has("proximity"):
		proximity_text = str(extra.get("proximity", ""))
	if extra.has("gap"):
		gap_text = str(extra.get("gap", ""))
	if extra.has("finish_approach"):
		finish_approach = bool(extra.get("finish_approach", false))
	if _course_banner_left > 0.0:
		_course_banner_left = maxf(0.0, _course_banner_left - delta)
	_emit()


func record_shortcut_taken(shortcut_id: String) -> void:
	shortcuts_taken += 1
	_record("shortcut_taken", {"id": shortcut_id})


func record_overtake() -> void:
	overtakes += 1
	_record("overtake", {"count": overtakes})


func results_highlights() -> PackedStringArray:
	var lines := PackedStringArray()
	if overtakes > 0:
		lines.append("Overtakes: %d" % overtakes)
	if shortcuts_taken > 0:
		lines.append("Shortcuts taken: %d" % shortcuts_taken)
	if strongest_boost > 1.05:
		lines.append("Strongest boost: x%.2f" % strongest_boost)
	if finish_approach:
		lines.append("Close finish")
	return lines


func _on_countdown(value: String) -> void:
	var token := value
	if token.begins_with("GO"):
		token = "GO"
	if token in ["3", "2", "1"]:
		start_phase = "countdown"
		_caption(token)
		_play("countdown")
	elif token == "GO":
		start_phase = "go"
		_caption("GO")
		_play("go")


func _on_go() -> void:
	start_phase = "racing"
	go_released = true
	_caption("GO")
	_emit()


func _on_lap_changed(racer: Node, lap: int) -> void:
	if racer != player:
		return
	last_lap_seen = lap
	var total := int(GameManager.total_laps) if GameManager != null else 3
	if lap + 1 >= total:
		final_lap = true
		_caption("FINAL LAP")
		_play("final_lap")
		_record("final_lap", {"lap": lap})
	else:
		_caption("LAP %d" % (lap + 1))
		_play("checkpoint")


func _on_boost_on(multiplier: float, _duration: float, _source: String) -> void:
	boost_presenting = true
	strongest_boost = maxf(strongest_boost, multiplier)
	_caption("BOOST")
	_play("boost")
	_record("boost", {"multiplier": multiplier})
	_emit()


func _on_boost_off() -> void:
	boost_presenting = false
	_emit()


func _on_draft_phase(phase: String, _strength: float) -> void:
	draft_phase = phase
	if phase == "entering":
		_caption("DRAFT")
		_play("draft")
	elif phase == "leaving":
		_caption("")
	_emit()


func _caption(text: String) -> void:
	last_caption = text
	caption_requested.emit(text)


func _play(cue: String) -> void:
	var audio := _audio()
	if audio != null and audio.has_method("play_race_cue"):
		audio.play_race_cue(cue)


func _record(kind: String, payload: Dictionary) -> void:
	highlights.append({"kind": kind, "payload": payload})
	highlight_recorded.emit(kind, payload)


func _emit() -> void:
	presentation_changed.emit(snapshot())


func _audio() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("AudioDirector")
