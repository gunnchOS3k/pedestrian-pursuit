extends Control

## Create Your Racer — modular appearance beside the eight canonical racers.

const AvatarAppearanceScript = preload("res://scripts/data/AvatarAppearance.gd")
const CreatedRacerStoreScript = preload("res://scripts/data/CreatedRacerStore.gd")
const RunnerProfileScript = preload("res://scripts/data/RunnerProfile.gd")
const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")
const WardrobeCatalogScript = preload("res://scripts/data/WardrobeCatalog.gd")

signal closed()
signal racer_saved(racer_id: String)

var _name_edit: LineEdit
var _skin: OptionButton
var _undertone: OptionButton
var _hair: OptionButton
var _assist: OptionButton
var _status: Label
var _preview_vp: SubViewport
var _preview_visual: Node3D
var _options: Dictionary = {}
var _appearance: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_options()
	_appearance = AvatarAppearanceScript.default_appearance().to_dict()
	var active := CreatedRacerStoreScript.get_active()
	if not active.is_empty():
		_appearance = active.get("appearance", _appearance)
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
	dim.color = Color(0.02, 0.03, 0.06, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -280
	panel.offset_bottom = 280
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
	_status.text = "Appearance is cosmetic — no hitbox/stat changes. Clothing not gender-locked."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(form)
	form.add_child(Label.new())
	var nl := Label.new()
	nl.text = "Display name (filtered local save — no public chat)"
	form.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 24
	_name_edit.placeholder_text = "Racer name"
	var active := CreatedRacerStoreScript.get_active()
	_name_edit.text = str(active.get("display_name", "Created Racer")) if not active.is_empty() else "Created Racer"
	form.add_child(_name_edit)

	_skin = _add_option(form, "Skin tone", _options.get("skin_tones", []), str(_appearance.get("skin_tone", "warm_medium")))
	_undertone = _add_option(form, "Undertone", _options.get("undertones", []), str(_appearance.get("undertone", "neutral")))
	_hair = _add_option(form, "Hair / protective style", _options.get("hair_styles", []), str(_appearance.get("hair_style", "short_fade")))
	_assist = _add_option(form, "Assistive visual", _options.get("assistive", []), str(_appearance.get("assistive", "none")))
	_skin.item_selected.connect(func (_i): _sync_from_controls(); _rebuild_preview())
	_undertone.item_selected.connect(func (_i): _sync_from_controls(); _rebuild_preview())
	_hair.item_selected.connect(func (_i): _sync_from_controls(); _rebuild_preview())
	_assist.item_selected.connect(func (_i): _sync_from_controls(); _rebuild_preview())

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(240, 0)
	cols.add_child(right)
	var host := SubViewportContainer.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.stretch = true
	host.custom_minimum_size = Vector2(220, 220)
	right.add_child(host)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.size = Vector2i(220, 220)
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


func _add_option(parent: Control, label: String, values: Array, selected: String) -> OptionButton:
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
	parent.add_child(ob)
	return ob


func _sync_from_controls() -> void:
	_appearance["skin_tone"] = _skin.get_item_text(_skin.selected) if _skin.item_count else "warm_medium"
	_appearance["undertone"] = _undertone.get_item_text(_undertone.selected) if _undertone.item_count else "neutral"
	_appearance["hair_style"] = _hair.get_item_text(_hair.selected) if _hair.item_count else "short_fade"
	_appearance["assistive"] = _assist.get_item_text(_assist.selected) if _assist.item_count else "none"
	_appearance["affects_collision"] = false
	_appearance["affects_stats"] = false


func _filtered_name(raw: String) -> String:
	## Local-only name — strip control chars; no unmoderated public text path.
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
	var preset := WardrobeCatalogScript.preset("metro_pulse_default")
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
	if str(active.get("outfit_id", "")).is_empty():
		active["outfit_id"] = "metro_pulse_default"
	CreatedRacerStoreScript.update_racer(active)
	_status.text = "Saved %s (schema v1). Procedural fallback remains if wardrobe art pending." % active["display_name"]
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
