extends CanvasLayer

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
	if player.has_signal("speed_changed"):
		player.speed_changed.connect(_on_speed_changed)
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
		_wrong_way_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
		add_child(_wrong_way_label)
	_wrong_way_label.visible = false
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
		position_label.text = "Position: %d" % pos
	_update_wrong_way(race_mgr)


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
	countdown_label.text = value
	countdown_label.visible = true


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
	else:
		var data := ItemData.load_by_id(item_id)
		item_label.text = "Item: %s" % data.get("display_name", item_id)


func _on_speed_changed(speed: float) -> void:
	speed_label.text = "Speed: %.0f" % speed
