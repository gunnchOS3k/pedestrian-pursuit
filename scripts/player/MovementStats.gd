extends Node

## Combines racer and shoe stats into runtime movement values.

@export var top_speed: float = 22.0
@export var acceleration: float = 18.0
@export var handling: float = 12.0
@export var drift_control: float = 10.0
@export var jump_force: float = 9.0
@export var gravity_scale: float = 2.2
@export var brake_strength: float = 24.0
@export var air_control: float = 6.0
@export var slide_speed_multiplier: float = 0.85
@export var stomp_force: float = 14.0


func apply_racer_and_shoe(racer: Dictionary, shoe: Dictionary) -> void:
	top_speed = racer.get("top_speed", 22.0) * shoe.get("top_speed_modifier", 1.0)
	acceleration = racer.get("acceleration", 18.0) * shoe.get("acceleration_modifier", 1.0)
	handling = racer.get("handling", 12.0) * shoe.get("handling_modifier", 1.0)
	drift_control = racer.get("drift_control", 10.0) * shoe.get("drift_modifier", 1.0)
	jump_force = 9.0 * shoe.get("jump_modifier", 1.0)
