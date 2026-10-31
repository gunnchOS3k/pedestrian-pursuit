extends Control

## Full 50-vehicle Kinetic Sole garage — list / select / preview with truthful stub flags.

const VehicleCatalogScript = preload("res://scripts/data/VehicleCatalog.gd")
const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")
const GarageProgressionScript = preload("res://scripts/data/GarageProgression.gd")
const ArtAcceptanceScript = preload("res://scripts/data/ArtAcceptance.gd")

signal vehicle_selected(vehicle_id: String)
signal closed()

var _family_list: ItemList
var _vehicle_list: ItemList
var _detail: RichTextLabel
var _select_btn: Button
var _close_btn: Button
var _status: Label
var _families: Array[String] = []
var _current_family: String = ""
var _selected_id: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_populate_families()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
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
	title.text = "Kinetic Sole Garage — 50 Footwear Vehicles"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var counts := VehicleCatalogScript.counts()
	var art := ArtAcceptanceScript.counts()
	var unlocked := GarageProgressionScript.player_selectable_ids().size()
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = (
		"%d race-capable  •  %d player-unlocked  •  final-art pending %d / candidate %d  •  commercial art NOT approved"
		% [
			int(counts.get("playable", 50)),
			unlocked,
			int(art.get("final_art_pending", 0)),
			int(art.get("final_art_candidate", 0)),
		]
	)
	root.add_child(_status)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	root.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(180, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var fam_label := Label.new()
	fam_label.text = "Families"
	left.add_child(fam_label)
	_family_list = ItemList.new()
	_family_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_family_list.item_selected.connect(_on_family_selected)
	left.add_child(_family_list)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(mid)
	var veh_label := Label.new()
	veh_label.text = "Vehicles"
	mid.add_child(veh_label)
	_vehicle_list = ItemList.new()
	_vehicle_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vehicle_list.item_selected.connect(_on_vehicle_row_selected)
	mid.add_child(_vehicle_list)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(260, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var det_label := Label.new()
	det_label.text = "Preview"
	right.add_child(det_label)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = false
	_detail.scroll_active = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.custom_minimum_size = Vector2(0, 180)
	right.add_child(_detail)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)
	_select_btn = Button.new()
	_select_btn.text = "Select for Race"
	_select_btn.custom_minimum_size = Vector2(160, 40)
	_select_btn.pressed.connect(_on_select_pressed)
	buttons.add_child(_select_btn)
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(100, 40)
	_close_btn.pressed.connect(_on_close_pressed)
	buttons.add_child(_close_btn)


func _populate_families() -> void:
	_family_list.clear()
	_families.clear()
	var reg := VehicleCatalogScript.load_registry()
	for fam in reg.get("families", []):
		if typeof(fam) != TYPE_DICTIONARY:
			continue
		var fid := str(fam.get("id", ""))
		var name := str(fam.get("name", fid))
		var count := int(fam.get("count", 0))
		_families.append(fid)
		_family_list.add_item("%s (%d)" % [name, count])
	if _family_list.item_count > 0:
		_family_list.select(0)
		_on_family_selected(0)


func _on_family_selected(index: int) -> void:
	if index < 0 or index >= _families.size():
		return
	_current_family = _families[index]
	_vehicle_list.clear()
	var vehicles := VehicleCatalogScript.vehicles_in_family(_current_family)
	for v in vehicles:
		var playable := bool(v.get("playable", false))
		var vid := str(v.get("id", ""))
		var unlocked := GarageProgressionScript.is_unlocked_for_player(vid)
		var final_art := ArtAcceptanceScript.final_art_status(vid)
		var tag := "UNLOCKED" if unlocked else "LOCKED"
		if playable and not unlocked:
			tag = "LOCKED · %s" % GarageProgressionScript.unlock_mode(vid)
		elif playable:
			tag = "UNLOCKED · %s" % final_art
		var label := "%s  [%s]" % [str(v.get("display_name", vid)), tag]
		var idx := _vehicle_list.item_count
		_vehicle_list.add_item(label)
		_vehicle_list.set_item_metadata(idx, vid)
		if not unlocked:
			_vehicle_list.set_item_custom_fg_color(idx, Color(0.7, 0.72, 0.78))
	if _vehicle_list.item_count > 0:
		_vehicle_list.select(0)
		_on_vehicle_row_selected(0)


func _on_vehicle_row_selected(index: int) -> void:
	if index < 0 or index >= _vehicle_list.item_count:
		return
	_selected_id = str(_vehicle_list.get_item_metadata(index))
	_show_detail(_selected_id)
	var playable := VehicleCatalogScript.is_playable(_selected_id)
	var unlocked := GarageProgressionScript.is_unlocked_for_player(_selected_id)
	_select_btn.disabled = not (playable and unlocked)
	if playable and unlocked:
		_select_btn.text = "Select for Race"
	elif playable:
		_select_btn.text = "Locked — progress to unlock"
	else:
		_select_btn.text = "Not race-capable"


func _show_detail(vehicle_id: String) -> void:
	var v := VehicleCatalogScript.by_id(vehicle_id)
	if v.is_empty():
		_detail.text = "Missing vehicle %s" % vehicle_id
		return
	var playable := bool(v.get("playable", false))
	var unlock: Dictionary = {}
	var unlock_raw: Variant = v.get("unlock", {})
	if typeof(unlock_raw) == TYPE_DICTIONARY:
		unlock = unlock_raw
	var art_acc := ArtAcceptanceScript.by_id(vehicle_id)
	_detail.clear()
	_detail.append_text("[b]%s[/b]\n" % str(v.get("display_name", vehicle_id)))
	_detail.append_text("ID: [code]%s[/code]\n" % vehicle_id)
	_detail.append_text("Family: %s\n" % str(v.get("family_name", "")))
	_detail.append_text("Archetype: %s\n" % str(v.get("movement_archetype", "")))
	_detail.append_text(
		"Runtime: %s  •  Mesh art: %s\n"
		% [str(art_acc.get("runtime_status", "")), str(v.get("art_status", ""))]
	)
	_detail.append_text(
		"Final-art acceptance: %s  •  Commercial approved: %s\n"
		% [
			str(art_acc.get("final_art_status", "final_art_pending")),
			"yes" if bool(art_acc.get("human_commercial_art_approved", false)) else "NO",
		]
	)
	_detail.append_text(
		"Player unlocked: %s  •  Race-capable: %s\n"
		% [
			"yes" if GarageProgressionScript.is_unlocked_for_player(vehicle_id) else "no",
			"yes" if playable else "no",
		]
	)
	_detail.append_text(
		"Stats  top %.2f  accel %.2f  hand %.2f  drift %.2f  jump %.2f  boost %.2f\n"
		% [
			float(v.get("top_speed_modifier", 1.0)),
			float(v.get("acceleration_modifier", 1.0)),
			float(v.get("handling_modifier", 1.0)),
			float(v.get("drift_modifier", 1.0)),
			float(v.get("jump_modifier", 1.0)),
			float(v.get("boost_modifier", 1.0)),
		]
	)
	_detail.append_text("\n%s\n" % str(v.get("description", "")))
	_detail.append_text("\n[i]%s[/i]\n" % str(v.get("gameplay_distinction", "")))
	_detail.append_text("\nCollision: %s\n" % str(v.get("collision_contract", "")))
	if typeof(unlock) == TYPE_DICTIONARY:
		_detail.append_text(
			"\nUnlock: %s — %s"
			% [str(unlock.get("mode", "")), str(unlock.get("note", ""))]
		)


func _on_select_pressed() -> void:
	if _selected_id.is_empty() or not VehicleCatalogScript.is_playable(_selected_id):
		return
	if not GarageProgressionScript.is_unlocked_for_player(_selected_id):
		return
	vehicle_selected.emit(_selected_id)
	_on_close_pressed()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
