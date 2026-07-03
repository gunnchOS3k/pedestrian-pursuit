extends Node

## Simple airborne trick: press trick key, land clean for boost.

signal trick_started
signal trick_landed(success: bool, boost_reward: float)

@export var trick_boost_reward: float = 15.0

var trick_active: bool = false
var _air_time: float = 0.0


func on_airborne(delta: float) -> void:
	_air_time += delta


func on_landed() -> void:
	if trick_active and _air_time > 0.3:
		trick_landed.emit(true, trick_boost_reward)
	else:
		trick_landed.emit(false, 0.0)
	trick_active = false
	_air_time = 0.0


func try_trick() -> bool:
	if trick_active:
		return false
	trick_active = true
	trick_started.emit()
	return true
