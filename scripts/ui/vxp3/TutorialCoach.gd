extends CanvasLayer
class_name TutorialCoach

## Non-blocking contextual coaching for foot-racing tutorial.
## Does not replace TutorialDirector completion contracts — complements them.
## Keep Tutorial Guide available from pause; avoid slideshow gating.

signal tip_dismissed(tip_id: String)

const BRAND := preload("res://scripts/ui/vxp3/Vxp3Brand.gd")

var _panel: PanelContainer
var _title: Label
var _body: Label
var _dismiss: Button
var _active_id: String = ""
var _shown: Dictionary = {}


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "CoachPanel"
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 24
	_panel.offset_right = -24
	_panel.offset_top = -168
	_panel.offset_bottom = -24
	add_child(_panel)
	var theme := BRAND.theme()
	if theme:
		_panel.theme = theme
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var header := HBoxContainer.new()
	v.add_child(header)
	var glyph := TextureRect.new()
	glyph.custom_minimum_size = Vector2(36, 36)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.texture = BRAND.glyph_texture("perfect_step")
	header.add_child(glyph)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", BRAND.TYPE_HUD_PRIMARY)
	_title.add_theme_color_override("font_color", BRAND.COLOR_MIDSOLE_YELLOW)
	header.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", BRAND.TYPE_BODY)
	v.add_child(_body)
	_dismiss = Button.new()
	_dismiss.text = "Got it"
	_dismiss.custom_minimum_size = Vector2(0, 44)
	_dismiss.pressed.connect(_on_dismiss)
	v.add_child(_dismiss)


func show_tip(tip_id: String, title: String, body: String, once: bool = true) -> void:
	if once and bool(_shown.get(tip_id, false)):
		return
	_shown[tip_id] = true
	_active_id = tip_id
	_title.text = title
	_body.text = body
	visible = true
	if BRAND.reduce_motion_active():
		_panel.modulate.a = 1.0
	else:
		_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.18)


func show_mechanic_tip(mech_id: String) -> void:
	var copy := {
		"sprint": ["Sprint", "Hold accelerate. Steer with left/right. Your feet are the vehicle."],
		"drift_spark_tiers": ["Drift sparks", "Hold drift while turning to charge sparks. Release for a boost — shape + color mark the tier."],
		"perfect_step": ["Perfect Step", "On GO, accelerate in the Perfect Step window — not early."],
		"boost_chain": ["Boost", "Spend boost meter from pickups, drifts, and tricks."],
		"items_counterplay": ["Items", "Use your item when ready. Warnings mean shield, slide, or jump."],
		"footwear_surfaces": ["Footwear", "Grip loves mud. Speed loves asphalt. Bounce loves rails and pads."],
	}
	var entry = copy.get(mech_id, ["Coach", "Practice this foot-racing mechanic on a real course."])
	show_tip(mech_id, str(entry[0]), str(entry[1]), true)


func _on_dismiss() -> void:
	visible = false
	var id := _active_id
	_active_id = ""
	tip_dismissed.emit(id)


func hide_coach() -> void:
	visible = false
	_active_id = ""
