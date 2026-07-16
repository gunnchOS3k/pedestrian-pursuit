extends CanvasLayer

## Debug telemetry overlay (toggle with F3).

@onready var label: Label = $Label

var _player: Node = null
var _visible: bool = false


func _ready() -> void:
	visible = false
	_visible = false


func setup(player: Node) -> void:
	_player = player
	visible = false
	_visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		# Release builds keep this off unless explicitly enabled in editor.
		if OS.has_feature("release") and not OS.is_debug_build():
			return
		_visible = not _visible
		visible = _visible


func _process(_delta: float) -> void:
	if not _visible or _player == null:
		return
	var lines: PackedStringArray = []
	lines.append("=== Pedestrian Pursuit Debug ===")
	lines.append("Speed: %.1f" % _player.horizontal_speed)
	lines.append("Terrain: %s" % _player.terrain_name)
	if _player.has_node("RacerStateMachine"):
		var sm = _player.get_node("RacerStateMachine")
		lines.append("State: %s" % sm.State.keys()[sm.current_state])
	if _player.has_node("DriftSystem"):
		var ds = _player.get_node("DriftSystem")
		lines.append("Drift charge: %.2f tier %d" % [ds.drift_charge, ds.spark_tier])
	if _player.has_node("BoostSystem"):
		var bs = _player.get_node("BoostSystem")
		lines.append("Boost: %.0f / %.0f" % [bs.current_boost, bs.max_boost])
	label.text = "\n".join(lines)
