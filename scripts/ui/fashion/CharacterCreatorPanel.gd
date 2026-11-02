extends Control

## Create Your Racer — exposes every authored AvatarAppearance field.

const AvatarAppearanceScript = preload("res://scripts/data/AvatarAppearance.gd")
const CreatedRacerStoreScript = preload("res://scripts/data/CreatedRacerStore.gd")
const RunnerProfileScript = preload("res://scripts/data/RunnerProfile.gd")
const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")
const WardrobeCatalogScript = preload("res://scripts/data/WardrobeCatalog.gd")

signal closed()
signal racer_saved(racer_id: String)

var _name_edit: LineEdit
var _controls: Dictionary = {} ## field_id -> OptionButton or HSlider
var _status: Label
var _preview_vp: SubViewport
var _preview_visual: Node3D
var _options: Dictionary = {}
var _appearance: Dictionary = {}
var _outfit_id: String = "metro_pulse_default"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_options()
	_appearance = AvatarAppearanceScript.default_appearance().to_dict()
	var active := CreatedRacerStoreScript.get_active()
	if not active.is_empty():
		_appearance = active.get("appearance", _appearance)
		_outfit_id = str(active.get("outfit_id", _outfit_id))
	_build_ui()
	_rebuild_preview()


func _load_options() -> void:
	var f := FileAccess.open("res://data/avatar/avatar_options.json", FileAccess.READ)
	if f == null:
		_options = {}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_options = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -520
	panel.offset_right = 520
	panel.offset_top = -320
	panel.offset_bottom = 320
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var title := Label.new()
	title.text = "Create Your Racer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "All appearance fields are cosmetic — no hitbox/stat changes. Clothing not gender-locked."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(360, 0)
	cols.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	var nl := Label.new()
	nl.text = "Display name (filtered local save — no public chat)"
	form.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 24
	_name_edit.placeholder_text = "Racer name"
	var active := CreatedRacerStoreScript.get_active()
	_name_edit.text = str(active.get("display_name", "Created Racer")) if not active.is_empty() else "Created Racer"
	form.add_child(_name_edit)

	_add_slider(form, "height_scale", "Body height", 0.85, 1.2, float(_appearance.get("height_scale", 1.0)))
	_add_slider(form, "width_scale", "Body width", 0.85, 1.2, float(_appearance.get("width_scale", 1.0)))
	_add_slider(form, "leg_scale", "Leg proportion", 0.85, 1.2, float(_appearance.get("leg_scale", 1.0)))
	_bind_option(form, "skin_tone", "Skin tone", _options.get("skin_tones", []), str(_appearance.get("skin_tone", "warm_medium")))
	_bind_option(form, "undertone", "Undertone", _options.get("undertones", []), str(_appearance.get("undertone", "neutral")))
	_bind_option(form, "face_shape", "Face shape", _options.get("face_shapes", []), str(_appearance.get("face_shape", "oval")))
	_bind_option(form, "hair_style", "Hair / protective style", _options.get("hair_styles", []), str(_appearance.get("hair_style", "short_fade")))
	_bind_option(form, "facial_hair", "Facial hair", _options.get("facial_hair", []), str(_appearance.get("facial_hair", "none")))
	_bind_option(form, "makeup", "Makeup", _options.get("makeup", []), str(_appearance.get("makeup", "none")))
	_bind_option(form, "scar", "Scar", _options.get("scars", []), str(_appearance.get("scar", "none")))
	_bind_option(form, "birthmark", "Birthmark", _options.get("birthmarks", []), str(_appearance.get("birthmark", "none")))
	_bind_option(form, "head_covering", "Head covering", _options.get("head_coverings", []), str(_appearance.get("head_covering", "none")))
	_bind_option(form, "assistive", "Assistive visual", _options.get("assistive", []), str(_appearance.get("assistive", "none")))
	_bind_option(form, "expression_idle", "Idle expression", _options.get("expressions", []), str(_appearance.get("expression_idle", "neutral")))
	_bind_option(form, "expression_start", "Start expression", _options.get("expressions", []), str(_appearance.get("expression_start", "focused")))
	_bind_option(form, "expression_victory", "Victory expression", _options.get("expressions", []), str(_appearance.get("expression_victory", "bright")))

	var outfit_ids: Array = []
	for p in WardrobeCatalogScript.load_catalog().get("presets", []):
		if typeof(p) == TYPE_DICTIONARY:
			outfit_ids.append(str(p.get("id", "")))
	_bind_option(form, "outfit_preset", "Outfit preset", outfit_ids, _outfit_id)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(260, 0)
	cols.add_child(right)
	var host := SubViewportContainer.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.stretch = true
	host.custom_minimum_size = Vector2(240, 260)
	right.add_child(host)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.size = Vector2i(240, 260)
	host.add_child(_preview_vp)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(buttons)
	var save_btn := Button.new()
	save_btn.text = "Save Created Racer"
	save_btn.custom_minimum_size = Vector2(180, 40)
	save_btn.pressed.connect(_on_save)
	buttons.add_child(save_btn)
	var use_btn := Button.new()
	use_btn.text = "Use in Next Race"
	use_btn.custom_minimum_size = Vector2(160, 40)
	use_btn.pressed.connect(_on_use)
	buttons.add_child(use_btn)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func (): closed.emit(); queue_free())
	buttons.add_child(close_btn)


func _bind_option(parent: Control, field: String, label: String, values: Array, selected: String) -> void:
	var l := Label.new()
	l.text = label
	parent.add_child(l)
	var ob := OptionButton.new()
	var sel := 0
	for i in range(values.size()):
		ob.add_item(str(values[i]))
		if str(values[i]) == selected:
			sel = i
	if ob.item_count > 0:
		ob.select(sel)
	ob.item_selected.connect(func (_i): _sync_from_controls(); _rebuild_preview())
	parent.add_child(ob)
	_controls[field] = ob


func _add_slider(parent: Control, field: String, label: String, mn: float, mx: float, value: float) -> void:
	var l := Label.new()
	l.text = "%s (%.2f)" % [label, value]
	parent.add_child(l)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = 0.01
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func (v):
		l.text = "%s (%.2f)" % [label, v]
		_sync_from_controls()
		_rebuild_preview()
	)
	parent.add_child(sl)
	_controls[field] = sl


func _option_text(field: String, fallback: String) -> String:
	var c = _controls.get(field, null)
	if c is OptionButton and c.item_count > 0:
		return c.get_item_text(c.selected)
	return fallback


func _slider_value(field: String, fallback: float) -> float:
	var c = _controls.get(field, null)
	if c is HSlider:
		return float(c.value)
	return fallback


func _sync_from_controls() -> void:
	_appearance["height_scale"] = clampf(_slider_value("height_scale", 1.0), 0.85, 1.2)
	_appearance["width_scale"] = clampf(_slider_value("width_scale", 1.0), 0.85, 1.2)
	_appearance["leg_scale"] = clampf(_slider_value("leg_scale", 1.0), 0.85, 1.2)
	_appearance["skin_tone"] = _option_text("skin_tone", "warm_medium")
	_appearance["undertone"] = _option_text("undertone", "neutral")
	_appearance["face_shape"] = _option_text("face_shape", "oval")
	_appearance["hair_style"] = _option_text("hair_style", "short_fade")
	_appearance["facial_hair"] = _option_text("facial_hair", "none")
	_appearance["makeup"] = _option_text("makeup", "none")
	_appearance["scar"] = _option_text("scar", "none")
	_appearance["birthmark"] = _option_text("birthmark", "none")
	_appearance["head_covering"] = _option_text("head_covering", "none")
	_appearance["assistive"] = _option_text("assistive", "none")
	_appearance["expression_idle"] = _option_text("expression_idle", "neutral")
	_appearance["expression_start"] = _option_text("expression_start", "focused")
	_appearance["expression_victory"] = _option_text("expression_victory", "bright")
	_appearance["affects_collision"] = false
	_appearance["affects_stats"] = false
	_outfit_id = _option_text("outfit_preset", _outfit_id)


func _filtered_name(raw: String) -> String:
	var cleaned := ""
	for i in raw.length():
		var ch := raw.unicode_at(i)
		if ch >= 32 and ch != 127:
			cleaned += String.chr(ch)
	cleaned = cleaned.strip_edges()
	if cleaned.is_empty():
		return "Created Racer"
	return cleaned.substr(0, 24)


func _rebuild_preview() -> void:
	for c in _preview_vp.get_children():
		c.queue_free()
	var world := Node3D.new()
	_preview_vp.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	world.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0.8, 1.3, 2.4)
	cam.look_at(Vector3(0, 1.0, 0))
	world.add_child(cam)
	_preview_visual = Node3D.new()
	_preview_visual.set_script(RacerVisualScript)
	world.add_child(_preview_visual)
	var profile := RunnerProfileScript.by_id("dash_reed")
	profile.display_name = _filtered_name(_name_edit.text if _name_edit else "Created Racer")
	if _preview_visual.has_method("set_menu_preview"):
		_preview_visual.set_menu_preview(true)
	if _preview_visual.has_method("apply_avatar_appearance"):
		_preview_visual.apply_avatar_appearance(_appearance, false)
	var preset := WardrobeCatalogScript.preset(_outfit_id)
	if _preview_visual.has_method("apply_wardrobe_outfit"):
		_preview_visual.apply_wardrobe_outfit(preset.get("slots", {}), false)
	if _preview_visual.has_method("apply_profile"):
		_preview_visual.apply_profile(profile)


func _on_save() -> void:
	_sync_from_controls()
	var active := CreatedRacerStoreScript.get_active()
	if active.is_empty():
		active = CreatedRacerStoreScript.create_racer(_filtered_name(_name_edit.text))
	active["display_name"] = _filtered_name(_name_edit.text)
	active["appearance"] = _appearance.duplicate(true)
	active["outfit_id"] = _outfit_id
	var preset := WardrobeCatalogScript.preset(_outfit_id)
	var slots: Dictionary = preset.get("slots", {})
	if not slots.is_empty():
		CreatedRacerStoreScript.save_outfit(_outfit_id, slots, true)
		var foot := str(slots.get("footwear_vehicle", ""))
		if not foot.is_empty():
			active["footwear_vehicle_id"] = foot
	CreatedRacerStoreScript.update_racer(active)
	_status.text = "Saved %s · outfit %s · all appearance fields persisted." % [active["display_name"], _outfit_id]
	racer_saved.emit(str(active.get("id", "")))
	_rebuild_preview()


func _on_use() -> void:
	_on_save()
	var active := CreatedRacerStoreScript.get_active()
	if active.is_empty():
		return
	GameManager.selected_runner_id = str(active.get("canonical_base_id", "dash_reed"))
	GameManager.selected_shoe_id = str(active.get("footwear_vehicle_id", "reedline_circlers"))
	GameManager.set_meta("created_racer_id", str(active.get("id", "")))
	_status.text = "Will race as %s with footwear %s" % [active.get("display_name"), active.get("footwear_vehicle_id")]
