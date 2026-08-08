extends CanvasLayer

## First-run / practice tutorial with gated advanced-mechanic prompts.

signal tutorial_finished

const GRAMMAR_PATH := "res://data/mechanics/foot_racing_grammar.json"

var _lessons: Array = []
var _index: int = 0
var _panel: PanelContainer
var _title: Label
var _body: Label
var _next_btn: Button
var _active: bool = false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_load_lessons()
	visible = false


func begin(advanced_only: bool = false) -> void:
	_index = 0
	if advanced_only:
		_lessons = _lessons.filter(func(l): return str(l.get("tier", "")) == "advanced")
	_active = true
	visible = true
	_show_lesson()


func _load_lessons() -> void:
	_lessons.clear()
	if not FileAccess.file_exists(GRAMMAR_PATH):
		_lessons = _fallback_lessons()
		return
	var f := FileAccess.open(GRAMMAR_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_lessons = _fallback_lessons()
		return
	for mech in parsed.get("mechanics", []):
		if typeof(mech) != TYPE_DICTIONARY:
			continue
		_lessons.append(mech)
	_lessons.sort_custom(func(a, b): return int(a.get("tutorial_lesson", 99)) < int(b.get("tutorial_lesson", 99)))
	if _lessons.is_empty():
		_lessons = _fallback_lessons()


func _fallback_lessons() -> Array:
	return [
		{"id": "sprint", "tier": "core", "tutorial_lesson": 1},
		{"id": "drift_spark_tiers", "tier": "core", "tutorial_lesson": 2},
		{"id": "perfect_step", "tier": "advanced", "tutorial_lesson": 3},
		{"id": "rail_grind", "tier": "advanced", "tutorial_lesson": 7},
		{"id": "footwear_surfaces", "tier": "advanced", "tutorial_lesson": 11},
	]


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 280)
	_panel.offset_left = -260
	_panel.offset_right = 260
	_panel.offset_top = -140
	_panel.offset_bottom = 140
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 15)
	v.add_child(_body)
	_next_btn = Button.new()
	_next_btn.text = "Next"
	_next_btn.custom_minimum_size = Vector2(0, 44)
	_next_btn.pressed.connect(_on_next)
	v.add_child(_next_btn)


func _show_lesson() -> void:
	if _index >= _lessons.size():
		_finish()
		return
	var lesson: Dictionary = _lessons[_index]
	var mech_id := str(lesson.get("id", "mechanic"))
	_title.text = "Tutorial %d / %d — %s" % [_index + 1, _lessons.size(), mech_id.replace("_", " ").capitalize()]
	_body.text = _copy_for(mech_id, str(lesson.get("tier", "core")), str(lesson.get("notes", "")))
	_next_btn.text = "Finish" if _index == _lessons.size() - 1 else "Got it — next"


func _copy_for(mech_id: String, tier: String, notes: String) -> String:
	var base := {
		"sprint": "Hold W to sprint, A/D to steer, S to brake. Your feet are the vehicle.",
		"drift_spark_tiers": "Hold Shift while turning to charge drift sparks (4 tiers). Release for a boost.",
		"perfect_step": "During countdown, wait for GO — accelerate in the Perfect Step window, not early.",
		"jump_air_control": "Space jumps. Steer in air. Q boosts; chain after drift release.",
		"slide_stomp": "Ctrl slides on ground or stomps in air to slow rivals ahead.",
		"wall_kick_scrape": "Hit a wall while jumping to wall-kick rebound — scrape recovery, not a stuck state.",
		"rail_grind": "Jump near a rail segment to attach and grind for speed.",
		"drafting": "Sit in a rival's wake to draft; pull out to surge.",
		"tricks": "Press T in air for tricks — successful landings refill boost.",
		"boost_chain": "Boost (Q) spends meter from pickups, drifts, and tricks.",
		"items_counterplay": "E uses items. Watch warnings — shield, slide, or jump to counter.",
		"footwear_surfaces": "Shoes have material families. Grip loves mud; Speed loves asphalt; Bounce loves rails/pads.",
	}
	var text := str(base.get(mech_id, "Practice this foot-racing mechanic in a real course."))
	if not notes.is_empty():
		text += "\n\n" + notes
	text += "\n\nTier: %s" % tier
	return text


func _on_next() -> void:
	_index += 1
	_show_lesson()


func _finish() -> void:
	_active = false
	visible = false
	var prog := get_tree().root.get_node_or_null("ProgressionSave")
	if prog != null and prog.has_method("mark_tutorial_done"):
		prog.mark_tutorial_done()
	tutorial_finished.emit()
