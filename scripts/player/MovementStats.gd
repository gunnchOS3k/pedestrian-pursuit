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
@export var boost_efficiency: float = 1.0
@export var trick_skill: float = 8.0
@export var recovery: float = 10.0

var shoe_id: String = "starter_soles"
var material_family: String = "balanced_rubber"
var surface_affinities: Dictionary = {}


func apply_racer_and_shoe(racer: Dictionary, shoe: Dictionary) -> void:
	top_speed = float(racer.get("top_speed", 22.0)) * float(shoe.get("top_speed_modifier", 1.0))
	acceleration = float(racer.get("acceleration", 18.0)) * float(shoe.get("acceleration_modifier", 1.0))
	handling = float(racer.get("handling", 12.0)) * float(shoe.get("handling_modifier", 1.0))
	drift_control = float(racer.get("drift_control", 10.0)) * float(shoe.get("drift_modifier", 1.0))
	jump_force = 9.0 * float(shoe.get("jump_modifier", 1.0))
	stomp_force = 14.0 * float(shoe.get("stomp_modifier", 1.0))
	boost_efficiency = float(racer.get("boost_efficiency", 1.0)) * float(shoe.get("boost_modifier", 1.0))
	trick_skill = float(racer.get("trick_skill", 8.0))
	recovery = float(racer.get("recovery", 10.0))
	shoe_id = str(shoe.get("id", shoe_id))
	material_family = str(shoe.get("material_family", "balanced_rubber"))
	surface_affinities = shoe.get("surface_affinities", {})


func affinity_for(surface: String) -> float:
	if surface_affinities.is_empty():
		return 1.0
	return float(surface_affinities.get(surface, surface_affinities.get("standard", 1.0)))
