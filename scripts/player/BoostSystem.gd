extends Node

## Boost meter: fill from drift/pickups, spend for dash speed.

signal boost_changed(current: float, maximum: float)
signal boost_activated(multiplier: float, duration: float)

@export var max_boost: float = 100.0
@export var boost_cost: float = 35.0
@export var boost_speed_multiplier: float = 1.35
@export var boost_duration: float = 1.2
@export var pickup_amount: float = 25.0

var current_boost: float = 50.0
var _active_time: float = 0.0
var _active_multiplier: float = 1.0


func _ready() -> void:
	boost_changed.emit(current_boost, max_boost)


func add_boost(amount: float) -> void:
	current_boost = clampf(current_boost + amount * _efficiency(), 0.0, max_boost)
	boost_changed.emit(current_boost, max_boost)


func try_consume_boost() -> bool:
	if current_boost < boost_cost or _active_time > 0.0:
		return false
	current_boost -= boost_cost
	_active_time = boost_duration
	_active_multiplier = boost_speed_multiplier
	boost_changed.emit(current_boost, max_boost)
	boost_activated.emit(_active_multiplier, boost_duration)
	return true


func apply_external_boost(multiplier: float, duration: float) -> void:
	_active_multiplier = maxf(_active_multiplier, multiplier)
	_active_time = maxf(_active_time, duration)
	boost_activated.emit(_active_multiplier, duration)


func tick(delta: float) -> void:
	if _active_time > 0.0:
		_active_time = maxf(0.0, _active_time - delta)
		if _active_time <= 0.0:
			_active_multiplier = 1.0


func get_speed_multiplier() -> float:
	return _active_multiplier if _active_time > 0.0 else 1.0


func _efficiency() -> float:
	return 1.0
