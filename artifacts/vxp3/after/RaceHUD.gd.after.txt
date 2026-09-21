extends CanvasLayer
const LaunchArtCatalogScript = preload("res://scripts/ui/LaunchArtCatalog.gd")
const Vxp3PresentationScript = preload("res://scripts/ui/vxp3/Vxp3Presentation.gd")
const Vxp3BrandScript = preload("res://scripts/ui/vxp3/Vxp3Brand.gd")

## Race HUD — lap, position, boost, item, timer, speed, wrong-way.

var _player: Node = null
var _wrong_way_label: Label

@onready var lap_label: Label = $Margin/VBox/LapLabel
@onready var position_label: Label = $Margin/VBox/PositionLabel
@onready var timer_label: Label = $Margin/VBox/TimerLabel
@onready var speed_label: Label = $Margin/VBox/SpeedLabel
@onready var boost_bar: ProgressBar = $Margin/VBox/BoostBar
@onready var item_label: Label = $Margin/VBox/ItemLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var course_label: Label = $CourseLabel
var _minimap: Control
var _role_hint: Label
var _map_label: Label
var _drift_meter: ProgressBar
var _footwear_label: Label
var _spark_icon: TextureRect
var _intro_phase: String = ""


func setup(player: Node, race_manager: Node, course_data: Dictionary = {}) -> void:
	_player = player
	race_manager.countdown_tick.connect(_on_countdown)
	race_manager.timer_updated.connect(_on_timer)
	race_manager.race_started.connect(_on_race_started)
	race_manager.race_finished.connect(_on_race_finished)
	if player.has_node("BoostSystem"):
		player.get_node("BoostSystem").boost_changed.connect(_on_boost_changed)
	if player.has_node("ItemManager"):
		player.get_node("ItemManager").item_changed.connect(_on_item_changed)
		if player.get_node("ItemManager").has_signal("item_warning"):
			player.get_node("ItemManager").item_warning.connect(_on_item_warning)
	if player.has_signal("item_warning_received"):
		player.item_warning_received.connect(func(id, secs): _on_item_warning(id, secs, null))
	if player.has_signal("speed_changed"):
		player.speed_changed.connect(_on_speed_changed)
	if race_manager.has_node("PositionTracker"):
		var tracker := race_manager.get_node("PositionTracker")
		if tracker.has_signal("place_changed") and not tracker.place_changed.is_connected(_on_place_changed):
			tracker.place_changed.connect(_on_place_changed)
	countdown_label.visible = true
	item_label.text = "Item: None"
	if _wrong_way_label == null:
		_wrong_way_label = Label.new()
		_wrong_way_label.name = "WrongWayLabel"
		_wrong_way_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wrong_way_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_wrong_way_label.offset_top = 120
		_wrong_way_label.offset_bottom = 160
		_wrong_way_label.add_theme_font_size_override("font_size", 28)
		_wrong_way_label.add_theme_color_override("font_color", Vxp3BrandScript.COLOR_HAZARD_RED)
		add_child(_wrong_way_label)
	_wrong_way_label.visible = false
	_ensure_vxp3_meters()
	if _minimap == null:
		_minimap = Control.new()
		_minimap.set_script(load("res://scripts/ui/MiniMap.gd"))
		_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_minimap.offset_left = -160
		_minimap.offset_top = 16
		_minimap.offset_right = -16
		_minimap.offset_bottom = 156
		add_child(_minimap)
	if _minimap.has_method("setup"):
		_minimap.setup(player, race_manager)
	var round_prefix := GameManager.get_cup_round_label()
	var course_name := str(course_data.get("display_name", "Unknown Course"))
	course_label.text = (
		"%s  •  %s" % [round_prefix, course_name] if not round_prefix.is_empty() else course_name
	)
	_ensure_role_labels()
	_apply_ui_scale()
	_apply_marker_colors()
	Vxp3PresentationScript.apply_hud_chrome(self)
	_play_race_intro(course_name)
	_update_footwear_label()


func _ensure_vxp3_meters() -> void:
	var vbox := $Margin/VBox as VBoxContainer
	if vbox == null:
		return
	if _drift_meter == null:
		_drift_meter = ProgressBar.new()
		_drift_meter.name = "DriftMeter"
		_drift_meter.custom_minimum_size = Vector2(200, 14)
		_drift_meter.max_value = 4.0
		_drift_meter.show_percentage = false
		_drift_meter.modulate = Vxp3BrandScript.COLOR_PURSUIT_BLUE
		vbox.add_child(_drift_meter)
		vbox.move_child(_drift_meter, boost_bar.get_index() + 1)
	if _footwear_label == null:
		_footwear_label = Label.new()
		_footwear_label.name = "FootwearLabel"
		_footwear_label.add_theme_font_size_override("font_size", Vxp3BrandScript.TYPE_HUD_SECONDARY)
		_footwear_label.add_theme_color_override("font_color", Vxp3BrandScript.COLOR_MUTED)
		vbox.add_child(_footwear_label)
	if _spark_icon == null:
		_spark_icon = TextureRect.new()
		_spark_icon.name = "DriftSparkIcon"
		_spark_icon.custom_minimum_size = Vector2(28, 28)
		_spark_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_spark_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(_spark_icon)
		vbox.move_child(_spark_icon, _drift_meter.get_index() + 1)


func _update_footwear_label() -> void:
	if _footwear_label == null:
		return
	var shoe_id := str(GameManager.selected_shoe_id)
	var shoe := ShoeData.load_by_id(shoe_id) if ClassDB.class_exists("ShoeData") else {}
	## ShoeData is a GDScript class_name — call via preload helper.
	var path := "res://data/shoes/%s.json" % shoe_id
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			shoe = parsed
	_footwear_label.text = "Footwear: %s" % str(shoe.get("display_name", shoe_id))


func _play_race_intro(course_name: String) -> void:
	## course → line → 3-2-1-GO (GO from RaceManager ticks). Reduce-motion safe.
	_intro_phase = "course"
	if countdown_label == null:
		return
	countdown_label.visible = true
	countdown_label.text = course_name
	countdown_label.add_theme_color_override("font_color", Vxp3BrandScript.COLOR_PURSUIT_BLUE)
	if Vxp3BrandScript.reduce_motion_active():
		countdown_label.text = "%s  ·  ON THE LINE" % course_name
		return
	countdown_label.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	tw.tween_property(countdown_label, "scale", Vector2.ONE, 0.25)
	tw.tween_callback(func ():
		if is_instance_valid(countdown_label) and _intro_phase == "course":
			_intro_phase = "line"
			countdown_label.text = "ON THE LINE"
			countdown_label.add_theme_color_override("font_color", Vxp3BrandScript.COLOR_BOOST_CYAN)
	)


func _process(_delta: float) -> void:
	if _player == null:
		return
	var race_mgr := get_tree().get_first_node_in_group("race_manager")
	if race_mgr and race_mgr.has_node("LapManager"):
		var lap_mgr := race_mgr.get_node("LapManager")
		var lap: int = lap_mgr.get_lap(_player)
		lap_label.text = (
			"Lap: %d / %d" % [min(lap + 1, GameManager.total_laps), GameManager.total_laps]
		)
	if race_mgr and race_mgr.has_node("PositionTracker"):
		var pos: int = race_mgr.get_node("PositionTracker").get_position_for(_player)
		position_label.text = "P%d" % pos
	_update_wrong_way(race_mgr)
	_update_drift_meter()


func _update_drift_meter() -> void:
	if _drift_meter == null or _player == null:
		return
	var tier := 0.0
	if _player.has_method("get_drift_spark_tier"):
		tier = float(_player.get_drift_spark_tier())
	elif _player.has_node("DriftSystem"):
		var drift = _player.get_node("DriftSystem")
		if drift.has_method("get_spark_tier"):
			tier = float(drift.get_spark_tier())
		elif "spark_tier" in drift:
			tier = float(drift.spark_tier)
	_drift_meter.value = clampf(tier, 0.0, 4.0)
	var spark_name := "spark_%d" % int(clampf(tier, 1.0, 4.0)) if tier >= 1.0 else ""
	if _spark_icon:
		if spark_name.is_empty():
			_spark_icon.texture = null
		else:
			_spark_icon.texture = Vxp3BrandScript.glyph_texture(spark_name)
			## Shape redundancy: also tint by tier for colorblind-safe HUD when markers on.
			if Vxp3BrandScript.colorblind_hud_active():
				_spark_icon.modulate = Color.WHITE
			else:
				match int(tier):
					2:
						_spark_icon.modulate = Vxp3BrandScript.COLOR_PURSUIT_BLUE
					3:
						_spark_icon.modulate = Vxp3BrandScript.COLOR_BOOST_CYAN
					4:
						_spark_icon.modulate = Vxp3BrandScript.COLOR_MIDSOLE_YELLOW
					_:
						_spark_icon.modulate = Vxp3BrandScript.COLOR_MUTED


func setup_local_mp_secondary(player2: Node) -> void:
	## Dual-pane a11y: larger UI + colorblind markers apply; P2 status line for couch.
	_apply_ui_scale()
	_apply_marker_colors()
	if _role_hint == null:
		_ensure_role_labels()
	if _role_hint:
		_role_hint.text = "P1: WASD/gamepad0  •  P2: arrows/gamepad1  •  Esc pauses"
		_role_hint.visible = true
	if player2 != null:
		set_meta("local_mp_p2", player2)


func apply_device_role(profile: Dictionary, map_profile: Dictionary = {}) -> void:
	_ensure_role_labels()
	var layout := str(profile.get("hud_layout", ""))
	var map_id := str(profile.get("map_profile", "sim_campus"))
	var gps := str(profile.get("gps_mode", "SIMULATED"))
	if _role_hint:
		var hint := str(profile.get("input_hints", ""))
		if bool(profile.get("dock_display_hook", false)):
			hint += "  ·  Dock: %s (screens=%d)" % [
				"ON" if bool(profile.get("docked", false)) else "OFF",
				int(profile.get("screen_count", 1)),
			]
		_role_hint.text = hint
		_role_hint.add_theme_color_override("font_color", Vxp3BrandScript.COLOR_MUTED)
	if _map_label:
		var map_name := str(map_profile.get("label", map_id))
		## Demote device-lab GPS copy; keep data available for Advanced roles.
		_map_label.text = "Map: %s" % map_name if map_id != "n/a" else ""
		_map_label.visible = map_id != "n/a"
		_map_label.add_theme_font_size_override("font_size", Vxp3BrandScript.TYPE_METADATA)
	if _minimap:
		_minimap.visible = map_id != "n/a"
		if layout == "handheld":
			_minimap.offset_left = -140
			_minimap.offset_bottom = 140
		elif layout == "dual_screen_debug":
			_minimap.offset_left = -200
			_minimap.offset_bottom = 200
		elif layout == "landscape_classroom":
			_minimap.offset_left = -180
			_minimap.offset_bottom = 160
	_apply_ui_scale()
	_apply_marker_colors()
	Vxp3PresentationScript.apply_hud_chrome(self)


func _ensure_role_labels() -> void:
	if _role_hint == null:
		_role_hint = Label.new()
		_role_hint.name = "RoleHint"
		_role_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_role_hint.offset_top = -48
		_role_hint.offset_bottom = -8
		_role_hint.offset_left = 16
		_role_hint.offset_right = -16
		_role_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_role_hint.add_theme_font_size_override("font_size", 13)
		_role_hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.85))
		add_child(_role_hint)
	if _map_label == null:
		_map_label = Label.new()
		_map_label.name = "MapProfileLabel"
		_map_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_map_label.offset_left = 16
		_map_label.offset_top = 8
		_map_label.offset_right = 420
		_map_label.offset_bottom = 36
		_map_label.add_theme_font_size_override("font_size", 14)
		add_child(_map_label)


func _apply_ui_scale() -> void:
	var scale := 1.0
	if AccessibilitySettings != null:
		scale = AccessibilitySettings.get_ui_scale_multiplier()
	var font_base := {
		lap_label: 18,
		position_label: 18,
		timer_label: 18,
		speed_label: 16,
		item_label: 16,
		course_label: 16,
	}
	for label in font_base.keys():
		if label != null:
			label.add_theme_font_size_override("font_size", int(float(font_base[label]) * scale))
	if boost_bar:
		boost_bar.custom_minimum_size = Vector2(0, 18.0 * scale)


func _apply_marker_colors() -> void:
	if AccessibilitySettings == null:
		return
	var wrong := AccessibilitySettings.get_marker_color("hazard")
	if _wrong_way_label:
		_wrong_way_label.add_theme_color_override("font_color", wrong)
	var finish_col := AccessibilitySettings.get_marker_color("finish")
	if position_label:
		position_label.add_theme_color_override("font_color", AccessibilitySettings.get_marker_color("player"))
	if countdown_label:
		countdown_label.add_theme_color_override("font_color", finish_col)
	if _minimap != null and _minimap.has_method("apply_marker_colors"):
		_minimap.apply_marker_colors()


func _update_wrong_way(race_mgr: Node) -> void:
	if _wrong_way_label == null or race_mgr == null or not (_player is CharacterBody3D):
		return
	if not race_mgr.has_node("PositionTracker") or not race_mgr.has_node("LapManager"):
		return
	var tracker := race_mgr.get_node("PositionTracker")
	var lap_mgr := race_mgr.get_node("LapManager")
	var body := _player as CharacterBody3D
	if body.velocity.length() < 2.5:
		_wrong_way_label.visible = false
		return
	var nodes: Array[Node3D] = tracker.get_checkpoints()
	var next_i: int = lap_mgr.get_next_checkpoint(_player)
	if next_i < 0 or next_i >= nodes.size() or nodes[next_i] == null:
		_wrong_way_label.visible = false
		return
	var toward := nodes[next_i].global_position - body.global_position
	toward.y = 0.0
	var vel := body.velocity
	vel.y = 0.0
	if toward.length() < 0.5 or vel.length() < 2.5:
		_wrong_way_label.visible = false
		return
	var wrong := toward.normalized().dot(vel.normalized()) < -0.25
	_wrong_way_label.visible = wrong
	if wrong:
		_wrong_way_label.text = "WRONG WAY"


func _on_countdown(value: String) -> void:
	var shown := value
	if value in ["3", "2", "1", "GO"]:
		shown = value
	countdown_label.text = shown
	countdown_label.visible = true
	if value == "GO":
		countdown_label.add_theme_color_override("font_color", Vxp3BrandScript.COLOR_MIDSOLE_YELLOW)
	elif AccessibilitySettings != null:
		countdown_label.add_theme_color_override(
			"font_color", AccessibilitySettings.get_marker_color("finish")
		)


func _on_race_started() -> void:
	await get_tree().create_timer(0.8).timeout
	countdown_label.visible = false


func _on_race_finished(_player: Node, _results: Array) -> void:
	countdown_label.text = "FINISH!"
	countdown_label.visible = true


func _on_timer(elapsed: float) -> void:
	var mins := int(elapsed) / 60
	var secs := fmod(elapsed, 60.0)
	timer_label.text = "Time: %02d:%05.2f" % [mins, secs]


func _on_boost_changed(current: float, maximum: float) -> void:
	boost_bar.max_value = maximum
	boost_bar.value = current


func _on_item_changed(item_id: String) -> void:
	if item_id.is_empty():
		item_label.text = "Item: None"
		_set_item_icon(null)
		return
	var data := ItemData.load_by_id(item_id)
	item_label.text = "Item: %s" % data.get("display_name", item_id)
	_set_item_icon(LaunchArtCatalogScript.item_icon(item_id))


func _set_item_icon(tex: Texture2D) -> void:
	var icon := get_node_or_null("ItemIcon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "ItemIcon"
		icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		icon.offset_left = -112
		icon.offset_top = -112
		icon.offset_right = -16
		icon.offset_bottom = -16
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(icon)
	var slot := LaunchArtCatalogScript.ui_texture("item_slot")
	if tex == null:
		icon.texture = slot
		icon.visible = slot != null
	else:
		icon.texture = tex
		icon.visible = true


func _on_item_warning(item_id: String, seconds: float, _target: Node) -> void:
	## Brief HUD flash so counterplay (shield / slide / jump) is readable.
	if countdown_label == null:
		return
	var prior := countdown_label.text
	var prior_vis := countdown_label.visible
	countdown_label.visible = true
	countdown_label.text = "WARN: %s (%.1fs)" % [item_id.replace("_", " ").capitalize(), seconds]
	get_tree().create_timer(maxf(seconds, 0.35)).timeout.connect(func ():
		if is_instance_valid(countdown_label):
			countdown_label.text = prior
			countdown_label.visible = prior_vis
	)


func _on_speed_changed(speed: float) -> void:
	var state := "SPRINT"
	if _player != null and _player.has_method("get_speed_state"):
		state = str(_player.get_speed_state())
	speed_label.text = "Speed: %.0f  [%s]" % [speed, state]
	var scene := get_parent()
	if scene != null:
		var cam = scene.get_node_or_null("CameraRig")
		if cam != null and cam.has_method("set_boosting") and _player != null:
			var boosting := false
			var boost = _player.get_node_or_null("BoostSystem")
			if boost != null and boost.has_method("get_speed_multiplier"):
				boosting = boost.get_speed_multiplier() > 1.05
			cam.set_boosting(boosting)


## GAME-RC-003 — overtake / being-overtaken HUD pulse + optional SFX.
func _on_place_changed(racer: Node, old_place: int, new_place: int) -> void:
	if racer != _player or position_label == null:
		return
	var gained := new_place < old_place
	position_label.text = "Position: %d" % new_place
	position_label.modulate = Color(0.45, 1.0, 0.55) if gained else Color(1.0, 0.55, 0.45)
	var tw := create_tween()
	tw.tween_property(position_label, "scale", Vector2(1.18, 1.18), 0.1)
	tw.tween_property(position_label, "scale", Vector2.ONE, 0.15)
	tw.tween_property(position_label, "modulate", Color.WHITE, 0.35)
	var audio := get_tree().root.get_node_or_null("AudioDirector")
	if audio != null and gained and audio.has_method("play_ui"):
		audio.play_ui("confirm")

