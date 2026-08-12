extends Node

## Drift charge builds while turning with drift held; release grants speed boost.

signal drift_released(boost_strength: float, spark_tier: int)

@export var charge_rate: float = 0.35
@export var min_turn_for_charge: float = 0.25
@export var boost_durations: Array[float] = [0.6, 1.0, 1.4, 1.8]
@export var boost_multipliers: Array[float] = [1.08, 1.15, 1.22, 1.32]

var is_drifting: bool = false
var drift_charge: float = 0.0
var spark_tier: int = 0

var _active_boost_time: float = 0.0
var _active_boost_multiplier: float = 1.0


func start_drift() -> void:
	is_drifting = true


func stop_drift(steer_amount: float) -> void:
	if not is_drifting:
		return
	is_drifting = false
	if drift_charge > 0.05 and absf(steer_amount) >= min_turn_for_charge * 0.5:
		_apply_release_boost()
	drift_charge = 0.0
	spark_tier = 0


func update_drift(delta: float, steer_amount: float, drift_control: float, charge_mult: float = 1.0) -> void:
	if not is_drifting:
		return
	if absf(steer_amount) < min_turn_for_charge:
		return
	drift_charge = clampf(
		drift_charge + charge_rate * delta * drift_control * 0.1 * maxf(charge_mult, 0.01),
		0.0,
		1.0
	)
	spark_tier = _tier_from_charge(drift_charge)


func _tier_from_charge(charge: float) -> int:
	if charge >= 0.85:
		return 3
	if charge >= 0.55:
		return 2
	if charge >= 0.25:
		return 1
	return 0


func _apply_release_boost() -> void:
	var tier := clampi(spark_tier, 0, boost_multipliers.size() - 1)
	_active_boost_multiplier = boost_multipliers[tier]
	_active_boost_time = boost_durations[tier]
	drift_released.emit(_active_boost_multiplier, tier)


func tick_boost(delta: float) -> void:
	if _active_boost_time > 0.0:
		_active_boost_time = maxf(0.0, _active_boost_time - delta)
		if _active_boost_time <= 0.0:
			_active_boost_multiplier = 1.0


func get_speed_multiplier() -> float:
	return _active_boost_multiplier


func get_spark_color() -> Color:
	match spark_tier:
		3: return Color(0.7, 0.2, 1.0)
		2: return Color(1.0, 0.5, 0.1)
		1: return Color(0.3, 0.6, 1.0)
		_: return Color(0.5, 0.5, 0.5)
