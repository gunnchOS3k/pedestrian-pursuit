extends CanvasLayer
class_name OpponentAwareness

## Nearby / pass / draft-target readability. Minimal offscreen marks, shape not color-only.

var _marks: Dictionary = {}
var last_proximity: String = ""
var last_gap: String = ""
var last_overtake: bool = false


func _ready() -> void:
	layer = 7


func update_field(player: Node3D, racers: Array, reduced_motion: bool) -> Dictionary:
	last_proximity = ""
	last_gap = ""
	last_overtake = false
	if player == null:
		return {"proximity": "", "gap": "", "overtake": false}
	var nearest_dist := 999.0
	var nearest: Node3D = null
	var ahead_gap := 999.0
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var used := {}
	for other in racers:
		if other == null or other == player or not (other is Node3D):
			continue
		var body: Node3D = other
		var delta: Vector3 = body.global_position - player.global_position
		delta.y = 0.0
		var dist := delta.length()
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = body
		var fwd := -player.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length_squared() > 0.001 and fwd.normalized().dot(delta.normalized()) > 0.25 and dist < ahead_gap:
			ahead_gap = dist
		if cam != null and dist > 14.0:
			var unproj: Vector3 = cam.unproject_position(body.global_position)
			var off := unproj.x < 24.0 or unproj.x > vp.x - 24.0 or unproj.y < 24.0 or unproj.y > vp.y - 24.0
			if off:
				_place_mark(str(body.get_instance_id()), vp, unproj, reduced_motion)
				used[str(body.get_instance_id())] = true
	_prune(used)
	if nearest != null and nearest_dist < 10.0:
		var name := str(nearest.get_meta("runner_display_name")) if nearest.has_meta("runner_display_name") else "runner"
		last_proximity = "NEAR %s" % name
	if ahead_gap < 40.0:
		last_gap = "GAP %.0f" % ahead_gap
	return {"proximity": last_proximity, "gap": last_gap, "overtake": last_overtake}


func _place_mark(id: String, vp: Vector2, unproj: Vector3, reduced_motion: bool) -> void:
	var mark: Label = _marks.get(id)
	if mark == null:
		mark = Label.new()
		mark.name = "OppMark_%s" % id
		mark.text = "▲"
		mark.add_theme_font_size_override("font_size", 18)
		add_child(mark)
		_marks[id] = mark
	var x := clampf(unproj.x, 16.0, vp.x - 28.0)
	var y := clampf(unproj.y, 16.0, vp.y - 28.0)
	mark.position = Vector2(x, y)
	mark.modulate.a = 0.45 if reduced_motion else 0.75


func _prune(used: Dictionary) -> void:
	for id in _marks.keys():
		if not used.has(id):
			var node: Label = _marks[id]
			if is_instance_valid(node):
				node.queue_free()
			_marks.erase(id)
