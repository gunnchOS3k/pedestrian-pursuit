extends Node

## Drift charge builds while turning with drift held at speed; release grants bounded boost.
## Overcommit / wrong-side drift bleeds speed. Stationary farming is rejected.

signal drift_released(boost_strength: float, spark_tier: int)
signal drift_quality_changed(tier: int, charge: float)

@export var charge_rate: float = 0.55
@export var min_turn_for_charge: float = 0.22
@export var min_speed_to_drift: float = 3.5
@export var boost_durations: Array[float] = [0.75, 1.15, 1.55, 2.05]
@export var boost_multipliers: Array[float] = [1.16, 1.24, 1.34, 1.45]
@export var overcommit_speed_penalty: float = 0.12

var is_drifting: bool = false
var drift_charge: float = 0.0
var spark_tier: int = 0
var last_release_quality: float = 0.0

var _active_boost_time: float = 0.0
var _active_boost_multiplier: float = 1.0
var _entry_steer_sign: float = 0.0
var _drift_time: float = 0.0
var _speed_at_entry: float = 0.0


func start_drift(current_speed: float = 0.0, steer_amount: float = 0.0) -> bool:
	if current_speed < min_speed_to_drift:
		return false
	is_drifting = true
	_drift_time = 0.0
	_speed_at_entry = current_speed
	_entry_steer_sign = signf(steer_amount) if absf(steer_amount) > 0.05 else 0.0
	return true


func stop_drift(steer_amount: float, current_speed: float = -1.0) -> void:
	if not is_drifting:
		return
	is_drifting = false
	var speed := current_speed if current_speed >= 0.0 else _speed_at_entry
	var wrong_side := _entry_steer_sign != 0.0 and signf(steer_amount) != 0.0 and signf(steer_amount) != _entry_steer_sign
	var overcommit := _drift_time > 2.4 and spark_tier < 2
	if drift_charge > 0.05 and absf(steer_amount) >= min_turn_for_charge * 0.45 and speed >= min_speed_to_drift * 0.75:
		if wrong_side or overcommit:
			last_release_quality = maxf(0.0, drift_charge * 0.45)
			_apply_release_boost(true)
		else:
			last_release_quality = drift_charge
			_apply_release_boost(false)
	else:
		last_release_quality = 0.0
	drift_charge = 0.0
	spark_tier = 0
	_drift_time = 0.0
	_entry_steer_sign = 0.0


func update_drift(delta: float, steer_amount: float, drift_control: float, charge_mult: float = 1.0, current_speed: float = 10.0) -> void:
	if not is_drifting:
		return
	_drift_time += delta
	if current_speed < min_speed_to_drift * 0.55:
		# Bleed charge when nearly stopped — no stationary farm.
		drift_charge = maxf(0.0, drift_charge - delta * 0.8)
		spark_tier = _tier_from_charge(drift_charge)
		drift_quality_changed.emit(spark_tier, drift_charge)
		return
	if absf(steer_amount) < min_turn_for_charge:
		drift_charge = maxf(0.0, drift_charge - delta * 0.25)
		spark_tier = _tier_from_charge(drift_charge)
		return
	var quality := clampf(absf(steer_amount), 0.0, 1.0)
	var speed_factor := clampf((current_speed - min_speed_to_drift) / 12.0, 0.35, 1.25)
	# Charge scales with steer quality and speed — arcade-readable spark tiers in a corner.
	drift_charge = clampf(
		drift_charge + charge_rate * delta * drift_control * maxf(charge_mult, 0.01) * quality * speed_factor,
		0.0,
		1.0
	)
	var prev := spark_tier
	spark_tier = _tier_from_charge(drift_charge)
	if spark_tier != prev:
		drift_quality_changed.emit(spark_tier, drift_charge)


func _tier_from_charge(charge: float) -> int:
	if charge >= 0.85:
		return 3
	if charge >= 0.55:
		return 2
	if charge >= 0.25:
		return 1
	return 0


func _apply_release_boost(penalized: bool) -> void:
	var tier := clampi(spark_tier, 0, boost_multipliers.size() - 1)
	var mult: float = boost_multipliers[tier]
	var dur: float = boost_durations[tier]
	if penalized:
		mult = maxf(1.02, mult - overcommit_speed_penalty)
		dur *= 0.65
	_active_boost_multiplier = mult
	_active_boost_time = dur
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


func can_start_at_speed(speed: float) -> bool:
	return speed >= min_speed_to_drift
