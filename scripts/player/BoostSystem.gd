extends Node

## Boost meter economy: fill from attributed sources, spend for dash speed.
## Caps, stacking rules, and anti-infinite-chain guards are explicit.

signal boost_changed(current: float, maximum: float)
signal boost_activated(multiplier: float, duration: float, source: String)
signal boost_source_recorded(source: String, amount: float)

@export var max_boost: float = 100.0
@export var boost_cost: float = 35.0
@export var boost_speed_multiplier: float = 1.35
@export var boost_duration: float = 1.2
@export var pickup_amount: float = 25.0
@export var max_active_multiplier: float = 1.55
@export var chain_window_sec: float = 0.35

var current_boost: float = 50.0
var last_source: String = "none"
var _active_time: float = 0.0
var _active_multiplier: float = 1.0
var _active_source: String = "none"
var _efficiency: float = 1.0
var _chain_cooldown: float = 0.0
var _source_totals: Dictionary = {}


func _ready() -> void:
	boost_changed.emit(current_boost, max_boost)


func set_efficiency(value: float) -> void:
	_efficiency = clampf(value, 0.5, 1.5)


func add_boost(amount: float, source: String = "generic") -> void:
	var gained := amount * _efficiency
	current_boost = clampf(current_boost + gained, 0.0, max_boost)
	last_source = source
	_source_totals[source] = float(_source_totals.get(source, 0.0)) + gained
	boost_changed.emit(current_boost, max_boost)
	boost_source_recorded.emit(source, gained)


func try_consume_boost() -> bool:
	if current_boost < boost_cost or _active_time > 0.0:
		return false
	if _chain_cooldown > 0.0:
		return false
	current_boost -= boost_cost
	_active_time = boost_duration
	_active_multiplier = minf(boost_speed_multiplier * _efficiency, max_active_multiplier)
	_active_source = "manual"
	last_source = "manual"
	_chain_cooldown = chain_window_sec
	boost_changed.emit(current_boost, max_boost)
	boost_activated.emit(_active_multiplier, boost_duration, _active_source)
	return true


func apply_external_boost(multiplier: float, duration: float, source: String = "external") -> void:
	var capped := minf(multiplier, max_active_multiplier)
	# Stacking: take max multiplier, extend duration modestly — never multiply forever.
	if _active_time > 0.0:
		_active_multiplier = minf(maxf(_active_multiplier, capped), max_active_multiplier)
		_active_time = minf(_active_time + duration * 0.35, boost_duration * 2.2)
	else:
		_active_multiplier = capped
		_active_time = duration
	_active_source = source
	last_source = source
	boost_activated.emit(_active_multiplier, _active_time, source)


func tick(delta: float) -> void:
	if _chain_cooldown > 0.0:
		_chain_cooldown = maxf(0.0, _chain_cooldown - delta)
	if _active_time > 0.0:
		_active_time = maxf(0.0, _active_time - delta)
		if _active_time <= 0.0:
			_active_multiplier = 1.0
			_active_source = "none"


func get_speed_multiplier() -> float:
	return _active_multiplier if _active_time > 0.0 else 1.0


func get_active_source() -> String:
	return _active_source if _active_time > 0.0 else "none"


func get_active_duration_left() -> float:
	return _active_time


func get_source_totals() -> Dictionary:
	return _source_totals.duplicate()


func is_capped() -> bool:
	return is_equal_approx(current_boost, max_boost)
