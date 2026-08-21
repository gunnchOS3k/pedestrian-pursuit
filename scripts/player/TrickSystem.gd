extends Node

## Airborne tricks: multiple styles, combo tracking, landing reward/fail penalty.
## Grounded farming is rejected. Works with jump/rail/stomp airtime.

signal trick_started(trick_id: String)
signal trick_landed(success: bool, boost_reward: float, trick_id: String, combo: int)

const TRICK_IDS: Array[String] = ["heel_spin", "cross_kick", "air_twist", "sole_flip"]

@export var base_boost_reward: float = 12.0
@export var combo_bonus: float = 4.0
@export var fail_boost_penalty: float = 6.0
@export var min_air_time: float = 0.28
@export var max_air_time_for_clean: float = 2.8

var trick_active: bool = false
var active_trick_id: String = ""
var combo_count: int = 0
var last_trick_id: String = ""
var _air_time: float = 0.0
var _tricks_this_air: int = 0


func on_airborne(delta: float) -> void:
	_air_time += delta


func on_landed() -> void:
	if not trick_active:
		_reset_air()
		trick_landed.emit(false, 0.0, "", combo_count)
		return
	var clean := _air_time >= min_air_time and _air_time <= max_air_time_for_clean
	if clean:
		if active_trick_id != last_trick_id:
			combo_count += 1
		else:
			combo_count = maxi(1, combo_count)
		var reward := base_boost_reward + float(combo_count - 1) * combo_bonus
		last_trick_id = active_trick_id
		trick_landed.emit(true, reward, active_trick_id, combo_count)
	else:
		combo_count = 0
		trick_landed.emit(false, -fail_boost_penalty, active_trick_id, 0)
	_reset_air()


func try_trick(preferred_id: String = "") -> bool:
	if _air_time <= 0.0:
		return false
	if _tricks_this_air >= 2:
		return false
	var tid := preferred_id
	if tid.is_empty() or tid not in TRICK_IDS:
		tid = TRICK_IDS[_tricks_this_air % TRICK_IDS.size()]
	trick_active = true
	active_trick_id = tid
	_tricks_this_air += 1
	trick_started.emit(tid)
	return true


func cancel_on_stomp() -> void:
	## Air stomp interrupts trick — no reward, combo broken.
	if trick_active:
		combo_count = 0
	_reset_air()


func _reset_air() -> void:
	trick_active = false
	active_trick_id = ""
	_air_time = 0.0
	_tricks_this_air = 0
