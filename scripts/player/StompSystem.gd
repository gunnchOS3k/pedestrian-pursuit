extends Node

## Ground stomp pulse and airborne downward stomp with recovery cost / anti-spam.

signal stomp_executed(is_airborne: bool)

@export var ground_pulse_radius: float = 4.2
@export var ground_slow_duration: float = 0.85
@export var air_stomp_velocity: float = -24.0
@export var stomp_cooldown: float = 0.55
@export var recovery_speed_penalty: float = 0.18
@export var air_impact_radius: float = 3.2

var _cooldown: float = 0.0
var last_was_airborne: bool = false
var pending_recovery_penalty: float = 0.0


func tick(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func can_stomp() -> bool:
	return _cooldown <= 0.0


func execute_ground_stomp(origin: Vector3, owner: Node) -> bool:
	if not can_stomp():
		return false
	_cooldown = stomp_cooldown
	last_was_airborne = false
	pending_recovery_penalty = recovery_speed_penalty * 0.5
	stomp_executed.emit(false)
	_pulse(origin, owner, ground_pulse_radius, ground_slow_duration)
	return true


func execute_air_stomp(body: CharacterBody3D) -> bool:
	if not can_stomp():
		return false
	_cooldown = stomp_cooldown * 1.15
	last_was_airborne = true
	pending_recovery_penalty = recovery_speed_penalty
	body.velocity.y = air_stomp_velocity
	stomp_executed.emit(true)
	var trick := body.get_node_or_null("TrickSystem")
	if trick != null and trick.has_method("cancel_on_stomp"):
		trick.cancel_on_stomp()
	return true


func on_air_stomp_landed(origin: Vector3, owner: Node) -> void:
	if not last_was_airborne:
		return
	_pulse(origin, owner, air_impact_radius, ground_slow_duration * 0.9)
	last_was_airborne = false


func consume_recovery_penalty() -> float:
	var p := pending_recovery_penalty
	pending_recovery_penalty = 0.0
	return p


func _pulse(origin: Vector3, owner: Node, radius: float, slow_duration: float) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var world: World3D = owner.get_world_3d()
	if world == null:
		return
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform3D(Basis(), origin)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [owner.get_rid()] if owner is CollisionObject3D else []
	for hit in space.intersect_shape(query, 16):
		var collider: Object = hit.collider
		if collider.has_method("apply_stomp_slow"):
			collider.apply_stomp_slow(slow_duration)
