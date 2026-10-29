extends Control

## Fashion Studio — rotate/zoom preview, apply pieces, save outfits/favorites.
## Accessible keyboard/button navigation. No unrestricted uploads / public text.

const WardrobeCatalogScript = preload("res://scripts/data/WardrobeCatalog.gd")
const CreatedRacerStoreScript = preload("res://scripts/data/CreatedRacerStore.gd")
const RunnerProfileScript = preload("res://scripts/data/RunnerProfile.gd")
const RacerVisualScript = preload("res://scripts/player/RacerVisual.gd")
const GarageProgressionScript = preload("res://scripts/data/GarageProgression.gd")

signal closed()
signal outfit_saved(outfit_id: String)

var _slot_list: ItemList
var _piece_list: ItemList
var _status: Label
var _preview_host: SubViewportContainer
var _preview_vp: SubViewport
var _preview_visual: Node3D
var _yaw: float = 0.35
var _zoom: float = 2.6
var _camera: Camera3D
var _slots: Dictionary = {}
var _current_slot: String = "top"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var preset := WardrobeCatalogScript.preset("metro_pulse_default")
	_slots = (preset.get("slots", {}) as Dictionary).duplicate(true)
	_build_ui()
	_populate_slots()
	_rebuild_preview()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.07, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -460
	panel.offset_right = 460
	panel.offset_top = -300
	panel.offset_bottom = 300
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Fashion Studio — Global Wardrobe"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = "Outfit cosmetic · footwear owns handling · multi-family integrated meshes · Crosswind Kiln + Archive Loom integrated"
	root.add_child(_status)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	root.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(150, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var sl := Label.new()
	sl.text = "Slots"
	left.add_child(sl)
	_slot_list = ItemList.new()
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_list.item_selected.connect(_on_slot_selected)
	left.add_child(_slot_list)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var pl := Label.new()
	pl.text = "Pieces"
	mid.add_child(pl)
	_piece_list = ItemList.new()
	_piece_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_piece_list.item_selected.connect(_on_piece_selected)
	mid.add_child(_piece_list)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(260, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var pv := Label.new()
	pv.text = "Preview (rotate / zoom)"
	right.add_child(pv)
	_preview_host = SubViewportContainer.new()
	_preview_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_host.stretch = true
	_preview_host.custom_minimum_size = Vector2(240, 220)
	right.add_child(_preview_host)
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.size = Vector2i(240, 220)
	_preview_host.add_child(_preview_vp)

	var cam_row := HBoxContainer.new()
	cam_row.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(cam_row)
	var rot_l := Button.new()
	rot_l.text = "⟲"
	rot_l.pressed.connect(func (): _yaw -= 0.35; _update_camera())
	cam_row.add_child(rot_l)
	var rot_r := Button.new()
	rot_r.text = "⟳"
	rot_r.pressed.connect(func (): _yaw += 0.35; _update_camera())
	cam_row.add_child(rot_r)
	var zoom_in := Button.new()
	zoom_in.text = "+"
	zoom_in.pressed.connect(func (): _zoom = maxf(1.6, _zoom - 0.25); _update_camera())
	cam_row.add_child(zoom_in)
	var zoom_out := Button.new()
	zoom_out.text = "−"
	zoom_out.pressed.connect(func (): _zoom = minf(4.0, _zoom + 0.25); _update_camera())
	cam_row.add_child(zoom_out)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)
	var save_btn := Button.new()
	save_btn.text = "Save Outfit + Favorite"
	save_btn.custom_minimum_size = Vector2(200, 40)
	save_btn.pressed.connect(_on_save)
	buttons.add_child(save_btn)
	var apply_btn := Button.new()
	apply_btn.text = "Apply to Created Racer"
	apply_btn.custom_minimum_size = Vector2(200, 40)
	apply_btn.pressed.connect(_on_apply_active)
	buttons.add_child(apply_btn)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.pressed.connect(func (): closed.emit(); queue_free())
	buttons.add_child(close_btn)


func _populate_slots() -> void:
	_slot_list.clear()
	for s in WardrobeCatalogScript.slots():
		if s == "footwear_vehicle":
			continue ## footwear selected via garage
		_slot_list.add_item(s)
	if _slot_list.item_count > 0:
		_slot_list.select(0)
		_on_slot_selected(0)


func _on_slot_selected(idx: int) -> void:
	_current_slot = _slot_list.get_item_text(idx)
	_piece_list.clear()
	for g in WardrobeCatalogScript.garments_in_slot(_current_slot):
		var label := "%s [%s]" % [str(g.get("display_name", g.get("id"))), str(g.get("art_status", ""))]
		_piece_list.add_item(label)
		_piece_list.set_item_metadata(_piece_list.item_count - 1, str(g.get("id", "")))


func _on_piece_selected(idx: int) -> void:
	var gid := str(_piece_list.get_item_metadata(idx))
	_slots[_current_slot] = gid
	_rebuild_preview()


func _rebuild_preview() -> void:
	for c in _preview_vp.get_children():
		c.queue_free()
	var world := Node3D.new()
	_preview_vp.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	world.add_child(light)
	_camera = Camera3D.new()
	world.add_child(_camera)
	_update_camera()
	_preview_visual = Node3D.new()
	_preview_visual.set_script(RacerVisualScript)
	world.add_child(_preview_visual)
	var profile := RunnerProfileScript.by_id("dash_reed")
	var active := CreatedRacerStoreScript.get_active()
	if not active.is_empty():
		profile = RunnerProfileScript.by_id(str(active.get("canonical_base_id", "dash_reed")))
		profile.display_name = str(active.get("display_name", profile.display_name))
		if _preview_visual.has_method("apply_avatar_appearance"):
			_preview_visual.apply_avatar_appearance(active.get("appearance", {}), false)
	if _preview_visual.has_method("set_menu_preview"):
		_preview_visual.set_menu_preview(true)
	var foot := str(_slots.get("footwear_vehicle", "reedline_circlers"))
	if not GarageProgressionScript.is_unlocked_for_player(foot) and not GarageProgressionScript.unlock_all_for_tests:
		foot = "reedline_circlers"
	if _preview_visual.has_method("set_vehicle_id"):
		_preview_visual.set_vehicle_id(foot, false)
	if _preview_visual.has_method("apply_wardrobe_outfit"):
		_preview_visual.apply_wardrobe_outfit(_slots, false)
	if _preview_visual.has_method("apply_profile"):
		_preview_visual.apply_profile(profile)


func _update_camera() -> void:
	if _camera == null:
		return
	_camera.position = Vector3(sin(_yaw) * _zoom, 1.2, cos(_yaw) * _zoom)
	_camera.look_at(Vector3(0, 1.0, 0))


func _on_save() -> void:
	var oid := "outfit_%d" % Time.get_unix_time_from_system()
	CreatedRacerStoreScript.save_outfit(oid, _slots, true)
	_status.text = "Saved outfit %s (favorite). Cosmetic only — footwear still owns handling." % oid
	outfit_saved.emit(oid)


func _on_apply_active() -> void:
	var active := CreatedRacerStoreScript.get_active()
	if active.is_empty():
		active = CreatedRacerStoreScript.create_racer("Studio Racer")
	var oid := "metro_pulse_default"
	CreatedRacerStoreScript.save_outfit(oid, _slots, true)
	active["outfit_id"] = oid
	active["footwear_vehicle_id"] = str(_slots.get("footwear_vehicle", active.get("footwear_vehicle_id", "reedline_circlers")))
	CreatedRacerStoreScript.update_racer(active)
	_status.text = "Applied to %s" % str(active.get("display_name", "racer"))
	outfit_saved.emit(oid)
