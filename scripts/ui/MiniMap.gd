extends Control

## Simple course mini-map — relative racer positions along checkpoint order.

var _player: Node3D
var _tracker: Node
var _checkpoints: Array[Node3D] = []


func setup(player: Node, race_manager: Node) -> void:
	_player = player as Node3D
	if race_manager and race_manager.has_node("PositionTracker"):
		_tracker = race_manager.get_node("PositionTracker")
		if _tracker.has_method("get_checkpoints"):
			_checkpoints = _tracker.get_checkpoints()
	custom_minimum_size = Vector2(140, 140)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.1, 0.75), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.75, 0.8, 0.35), false, 2.0)
	if _checkpoints.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(12, h * 0.5), "No map", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))
		return
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for cp in _checkpoints:
		if cp == null:
			continue
		var p := Vector2(cp.global_position.x, cp.global_position.z)
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var span := max_p - min_p
	span.x = maxf(span.x, 1.0)
	span.y = maxf(span.y, 1.0)
	var pad := 12.0
	var to_map := func(world: Vector3) -> Vector2:
		var p := Vector2(world.x, world.z)
		var n := (p - min_p) / span
		return Vector2(pad + n.x * (w - pad * 2.0), pad + n.y * (h - pad * 2.0))
	for i in _checkpoints.size():
		var cp := _checkpoints[i]
		if cp == null:
			continue
		var pt: Vector2 = to_map.call(cp.global_position)
		var cp_color := Color(0.55, 0.75, 1.0, 0.9)
		if AccessibilitySettings != null:
			cp_color = AccessibilitySettings.get_marker_color("checkpoint")
			cp_color.a = 0.9
		draw_circle(pt, 3.0, cp_color)
	if _player:
		var ppt: Vector2 = to_map.call(_player.global_position)
		var player_color := Color(1.0, 0.85, 0.25, 1.0)
		if AccessibilitySettings != null:
			player_color = AccessibilitySettings.get_marker_color("player")
		draw_circle(ppt, 5.0, player_color)


func apply_marker_colors() -> void:
	queue_redraw()
