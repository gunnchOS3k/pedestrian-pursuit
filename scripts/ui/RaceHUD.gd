extends CanvasLayer

## Race HUD — lap, position, boost, item, timer, speed.

@onready var lap_label: Label = $Margin/VBox/LapLabel
@onready var position_label: Label = $Margin/VBox/PositionLabel
@onready var timer_label: Label = $Margin/VBox/TimerLabel
@onready var speed_label: Label = $Margin/VBox/SpeedLabel
@onready var boost_bar: ProgressBar = $Margin/VBox/BoostBar
@onready var item_label: Label = $Margin/VBox/ItemLabel
@onready var countdown_label: Label = $CountdownLabel

var _player: Node = null


func setup(player: Node, race_manager: Node) -> void:
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


func _process(_delta: float) -> void:
	if _player == null:
		return
	var race_mgr := get_tree().get_first_node_in_group("race_manager")
	if race_mgr and race_mgr.has_node("LapManager"):
		var lap_mgr := race_mgr.get_node("LapManager")
		var lap: int = lap_mgr.get_lap(_player)
		lap_label.text = "Lap: %d / %d" % [min(lap + 1, GameManager.total_laps), GameManager.total_laps]
	if race_mgr and race_mgr.has_node("PositionTracker"):
		var pos: int = race_mgr.get_node("PositionTracker").get_position_for(_player)
		position_label.text = "Position: %d" % pos


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
