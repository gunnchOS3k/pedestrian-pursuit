extends RefCounted
class_name Vxp3Brand

## VXP-3 KINETIC SOLE design tokens.
## Design label only — product name remains Pedestrian Pursuit.
## Footwear is the machine. The runner is the vehicle.

const BRAND_DIR := "res://assets/branding/vxp3/"
const GLYPH_DIR := "res://assets/branding/vxp3/glyphs/"
const THEME_PATH := "res://assets/ui/vxp3/themes/pp_vxp3_theme.tres"
const DISPLAY_FONT_PATH := "res://assets/fonts/vxp31/barlow_condensed/BarlowCondensed-SemiBold.ttf"
const DISPLAY_FONT_BOLD_PATH := "res://assets/fonts/vxp31/barlow_condensed/BarlowCondensed-Bold.ttf"
const CUSTOM_FONT_PENDING := false

## Surfaces
const COLOR_NIGHT_TRACK := Color("0B1220")
const COLOR_ASPHALT := Color("1A2336")
const COLOR_PANEL := Color("243049")
## Accents (semantic — not equal usage)
const COLOR_KINETIC_ORANGE := Color("FF6A3D")
const COLOR_PURSUIT_BLUE := Color("3D8BFF")
const COLOR_MIDSOLE_YELLOW := Color("F5C518")
## Status
const COLOR_BOOST_CYAN := Color("2EE6D6")
const COLOR_GRIP_GREEN := Color("3DDC84")
const COLOR_HAZARD_RED := Color("FF4D6A")
const COLOR_GHOST_VIOLET := Color("A78BFA")
const COLOR_INK := Color("F4F7FB")
const COLOR_MUTED := Color("8FA3C4")
const COLOR_HC_BG := Color(0, 0, 0, 1)
const COLOR_HC_FG := Color(1, 1, 1, 1)
const COLOR_HC_ACCENT := Color("FFE033")

## Type roles (px). Custom face deferred — hierarchy is the contract.
const TYPE_DISPLAY := 48
const TYPE_RACE_TITLE := 36
const TYPE_RUNNER_NAME := 28
const TYPE_COURSE_NAME := 24
const TYPE_HUD_PRIMARY := 22
const TYPE_HUD_SECONDARY := 16
const TYPE_CONTROL := 18
const TYPE_BODY := 16
const TYPE_METADATA := 13
const TYPE_TIMING_NUMBER := 28
const TYPE_POSITION_NUMBER := 32

const TOUCH_MIN := 48.0

const ENGINEER_TOKENS := [
	"DIGITAL RC READY",
	"DIGITAL RC",
	"procedural-final presentation",
	"procedural-final",
	"PROCEDURAL_FINAL",
	"PROCEDURAL_PRODUCTION_PROXY",
	"REQUIRES_ART_PRODUCTION",
	"device-lab",
	"Device Lab GPS",
]


static func display_font() -> Font:
	if ResourceLoader.exists(DISPLAY_FONT_PATH):
		return load(DISPLAY_FONT_PATH) as Font
	return null


static func display_font_bold() -> Font:
	if ResourceLoader.exists(DISPLAY_FONT_BOLD_PATH):
		return load(DISPLAY_FONT_BOLD_PATH) as Font
	return display_font()


static func theme() -> Theme:
	if ResourceLoader.exists(THEME_PATH):
		var loaded := load(THEME_PATH) as Theme
		_apply_display_font(loaded)
		return loaded
	return _build_runtime_theme()


static func _apply_display_font(t: Theme) -> void:
	if t == null:
		return
	var font := display_font_bold()
	if font == null:
		return
	t.set_font("font", "Label", font)
	t.set_font("font", "Button", font)


static func _build_runtime_theme() -> Theme:
	var t := Theme.new()
	var btn := StyleBoxFlat.new()
	btn.bg_color = COLOR_PANEL
	btn.set_corner_radius_all(12)
	btn.content_margin_left = 16
	btn.content_margin_right = 16
	btn.content_margin_top = 10
	btn.content_margin_bottom = 10
	t.set_stylebox("normal", "Button", btn)
	var btn_h := btn.duplicate() as StyleBoxFlat
	btn_h.bg_color = COLOR_ASPHALT
	btn_h.border_color = COLOR_KINETIC_ORANGE
	btn_h.set_border_width_all(2)
	t.set_stylebox("hover", "Button", btn_h)
	var btn_p := btn.duplicate() as StyleBoxFlat
	btn_p.bg_color = COLOR_KINETIC_ORANGE
	t.set_stylebox("pressed", "Button", btn_p)
	var btn_f := btn.duplicate() as StyleBoxFlat
	btn_f.border_color = COLOR_MIDSOLE_YELLOW
	btn_f.set_border_width_all(3)
	t.set_stylebox("focus", "Button", btn_f)
	t.set_color("font_color", "Button", COLOR_INK)
	t.set_color("font_hover_color", "Button", COLOR_INK)
	t.set_color("font_pressed_color", "Button", COLOR_NIGHT_TRACK)
	t.set_color("font_color", "Label", COLOR_INK)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(COLOR_PANEL.r, COLOR_PANEL.g, COLOR_PANEL.b, 0.94)
	panel.set_corner_radius_all(16)
	panel.content_margin_left = 18
	panel.content_margin_right = 18
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


static func reduce_motion_active() -> bool:
	if AccessibilitySettings != null:
		return bool(AccessibilitySettings.reduce_motion)
	return false


static func high_contrast_active() -> bool:
	## No dedicated high-contrast flag yet — larger_ui + colorblind markers approximate.
	if AccessibilitySettings != null:
		return bool(AccessibilitySettings.larger_ui) and bool(AccessibilitySettings.colorblind_safe_hud)
	return false


static func colorblind_hud_active() -> bool:
	if AccessibilitySettings != null:
		return bool(AccessibilitySettings.colorblind_safe_hud)
	return false


static func apply_surface_chrome(root: Control, opts: Dictionary = {}) -> void:
	if root == null:
		return
	var t := theme()
	if t != null:
		root.theme = t
	var bg := root.get_node_or_null("Background") as ColorRect
	if bg != null:
		bg.color = COLOR_HC_BG if high_contrast_active() else COLOR_NIGHT_TRACK
	var title := root.get_node_or_null("VBox/Title") as Label
	if title == null:
		title = root.find_child("Title", true, false) as Label
	if title != null:
		title.add_theme_font_size_override("font_size", int(opts.get("title_size", TYPE_DISPLAY)))
		title.add_theme_color_override(
			"font_color", COLOR_HC_FG if high_contrast_active() else COLOR_INK
		)
	_ensure_min_touch_targets(root)


static func _ensure_min_touch_targets(node: Node) -> void:
	if node is Button:
		var b := node as Button
		var min_sz := b.custom_minimum_size
		b.custom_minimum_size = Vector2(maxf(min_sz.x, 160.0), maxf(min_sz.y, TOUCH_MIN))
	for c in node.get_children():
		_ensure_min_touch_targets(c)


static func glyph_texture(name: String) -> Texture2D:
	var path := GLYPH_DIR + "glyph_%s.png" % name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func mark_texture(mono: bool = false) -> Texture2D:
	var path := BRAND_DIR + ("pp-kinetic-mark-monochrome.png" if mono else "pp-kinetic-mark.png")
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func wordmark_texture() -> Texture2D:
	var path := BRAND_DIR + "pedestrian-pursuit-wordmark.png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func footwear_symbol(family: String) -> Texture2D:
	var key := family.to_lower()
	var file := "pp-symbol-grip.svg"
	if "speed" in key or "hard_carbon" in key:
		file = "pp-symbol-speed.svg"
	elif "bounce" in key or "reactive_foam" in key:
		file = "pp-symbol-bounce.svg"
	elif "grip" in key or "lug" in key:
		file = "pp-symbol-grip.svg"
	var path := BRAND_DIR + file
	## Prefer PNG if present; SVG may need import.
	var png := path.replace(".svg", ".png")
	if ResourceLoader.exists(png):
		return load(png) as Texture2D
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func strip_engineer_copy(text: String) -> String:
	var out := text
	for token in ENGINEER_TOKENS:
		out = out.replace(token, "")
	while "  " in out:
		out = out.replace("  ", " ")
	out = out.replace("•  •", "•").strip_edges()
	if out.begins_with("•"):
		out = out.substr(1).strip_edges()
	return out


static func player_subtitle() -> String:
	return "Sprint · Drift · Boost — footwear is the machine"


static func style_primary_cta(btn: Button) -> void:
	if btn == null:
		return
	btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, 220.0), maxf(btn.custom_minimum_size.y, 56.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_KINETIC_ORANGE if not high_contrast_active() else COLOR_HC_ACCENT
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_MIDSOLE_YELLOW
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", COLOR_NIGHT_TRACK)
	btn.add_theme_font_size_override("font_size", TYPE_CONTROL + 2)


static func style_secondary_control(btn: Button) -> void:
	if btn == null:
		return
	btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, TOUCH_MIN)
	btn.add_theme_font_size_override("font_size", TYPE_CONTROL)


static func footwear_strength_label(shoe: Dictionary) -> String:
	## Honest presentation from existing modifiers — no invented stats.
	var handling := float(shoe.get("handling_modifier", 1.0))
	var top := float(shoe.get("top_speed_modifier", 1.0))
	var jump := float(shoe.get("jump_modifier", 1.0))
	if handling >= 1.15:
		return "Grip strength"
	if top >= 1.1:
		return "Speed strength"
	if jump >= 1.1:
		return "Bounce strength"
	return "Balanced strength"


static func footwear_affinity_blurb(shoe: Dictionary) -> String:
	var aff: Dictionary = shoe.get("surface_affinities", {})
	if aff.is_empty():
		return "Surface affinity: balanced"
	var best_k := "standard"
	var best_v := -999.0
	for k in aff.keys():
		var v := float(aff[k])
		if v > best_v:
			best_v = v
			best_k = str(k)
	return "Strongest on %s" % best_k.replace("_", " ")
