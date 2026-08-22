extends Area3D

## Authored shortcut corridor: skill/risk alternate path that does NOT skip checkpoints.
## Entry/exit are measurable; terrain risk may apply. Lap integrity remains LapManager's job.

signal shortcut_entered(racer: Node, shortcut_id: String)
signal shortcut_exited(racer: Node, shortcut_id: String)

@export var shortcut_id: String = "shortcut"
@export var risk_terrain: String = ""
@export var risk_speed_mult: float = 0.88
@export var risk_handling_mult: float = 0.92

var _inside: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("racers"):
		return
	_inside[body.get_instance_id()] = true
	body.set_meta("on_shortcut_id", shortcut_id)
	if not risk_terrain.is_empty() and body.has_method("set_terrain_modifiers"):
		body.set_terrain_modifiers(risk_terrain, risk_speed_mult, risk_handling_mult)
	shortcut_entered.emit(body, shortcut_id)
	var bus := _telemetry()
	if bus != null and bus.has_method("record"):
		bus.record("shortcut_entered", {
			"shortcut_id": shortcut_id,
			"racer_id": str(body.get("racer_id")),
		})


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("racers"):
		return
	_inside.erase(body.get_instance_id())
	if str(body.get_meta("on_shortcut_id", "")) == shortcut_id:
		body.set_meta("on_shortcut_id", "")
		body.set_meta("shortcut_completed", shortcut_id)
		if body.has_method("set_terrain_modifiers"):
			body.set_terrain_modifiers("standard", 1.0, 1.0)
	shortcut_exited.emit(body, shortcut_id)
	var bus := _telemetry()
	if bus != null and bus.has_method("record"):
		bus.record("shortcut_completed", {
			"shortcut_id": shortcut_id,
			"racer_id": str(body.get("racer_id")),
		})


func _telemetry() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("TelemetryBus")
