extends Node

## Global game state and settings.

enum RaceMode { SINGLE, TIME_TRIAL, PRACTICE }

var current_race_mode: RaceMode = RaceMode.SINGLE
var selected_racer_id: String = "dash"
var selected_shoe_id: String = "starter_soles"
var selected_track_id: String = "sneaker_city_sprintway"
var total_laps: int = 3

var camera_shake_enabled: bool = true
var auto_accelerate: bool = false

var last_race_time: float = 0.0
var last_race_position: int = 1
var last_race_finished: bool = false


func reset_race_stats() -> void:
	last_race_time = 0.0
	last_race_position = 1
	last_race_finished = false
