class_name PlayerController
extends CharacterBody3D

## Foot-powered racer movement: sprint, steer, drift, boost, jump, slide, stomp,
## drafting, rail grind, and collision recovery.

const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")

signal speed_changed(speed: float)
signal terrain_changed(terrain_name: String)
signal item_warning_received(item_id: String, seconds: float)
signal special_ability_activated(ability_id: String)

@export var is_player: bool = true
@export var racer_id: String = "dash"
@export var shoe_id: String = "starter_soles"
@export var local_player_index: int = 0

var horizontal_speed: float = 0.0
var terrain_speed_multiplier: float = 1.0
var terrain_handling_multiplier: float = 1.0
var terrain_name: String = "standard"
var movement_enabled: bool = true
var shield_active: bool = false
var _slow_timer: float = 0.0
var _start_boost_multiplier: float = 1.0
var _start_boost_time: float = 0.0
var _recovery_transform := Transform3D.IDENTITY
var _collision_stun: float = 0.0
var _wall_kick_cooldown: float = 0.0

@onready var stats: Node = $MovementStats
@onready var state_machine: Node = $RacerStateMachine
@onready var drift_system: Node = $DriftSystem
@onready var boost_system: Node = $BoostSystem
@onready var stomp_system: Node = $StompSystem
@onready var trick_system: Node = $TrickSystem
@onready var item_manager: Node = $ItemManager
@onready var drift_particles: GPUParticles3D = $DriftParticles
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var shoe_mesh: MeshInstance3D = $ShoeMesh

var drafting_system: Node
var rail_grind_system: Node
var special_ability: Node

## Sprint cadence / coyote / slide timing (feet grammar depth).
var _cadence_phase: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer: float = 0.0
var _slide_timer: float = 0.0
var _momentum_line_bonus: float = 1.0
var _last_wall_kick: bool = false
const COYOTE_SEC := 0.12
const JUMP_BUFFER_SEC := 0.12
const MAX_SLIDE_SEC := 1.35


func _ready() -> void:
	add_to_group("racers")
	_ensure_aux_systems()
	var racer_data := RacerData.load_by_id(racer_id)
	var shoe_data := ShoeDataScript.load_by_id(shoe_id)
	stats.apply_racer_and_shoe(racer_data, shoe_data)
	if boost_system != null and boost_system.has_method("set_efficiency"):
		boost_system.set_efficiency(float(stats.boost_efficiency))
	_setup_special_ability(racer_data)
	drift_system.drift_released.connect(_on_drift_released)
	trick_system.trick_landed.connect(_on_trick_landed)
	if item_manager and item_manager.has_signal("item_warning"):
		item_manager.item_warning.connect(_on_item_warning)


func _ensure_aux_systems() -> void:
	drafting_system = get_node_or_null("DraftingSystem")
	if drafting_system == null:
		drafting_system = Node.new()
		drafting_system.name = "DraftingSystem"
		drafting_system.set_script(load("res://scripts/player/DraftingSystem.gd"))
		add_child(drafting_system)
	if drafting_system.has_method("setup"):
		drafting_system.setup(self)

	rail_grind_system = get_node_or_null("RailGrindSystem")
	if rail_grind_system == null:
		rail_grind_system = Node.new()
		rail_grind_system.name = "RailGrindSystem"
		rail_grind_system.set_script(load("res://scripts/player/RailGrindSystem.gd"))
		add_child(rail_grind_system)

	special_ability = get_node_or_null("SpecialAbilitySystem")
	if special_ability == null:
		special_ability = Node.new()
		special_ability.name = "SpecialAbilitySystem"
		special_ability.set_script(load("res://scripts/player/SpecialAbilitySystem.gd"))
		add_child(special_ability)


func _setup_special_ability(racer_data: Dictionary) -> void:
	if special_ability == null:
		return
	var sid := str(racer_data.get("special_ability_id", "clean_lines"))
	if special_ability.has_method("setup"):
		special_ability.setup(self, sid)
	if special_ability.has_signal("ability_activated") and not special_ability.ability_activated.is_connected(_on_special_activated):
		special_ability.ability_activated.connect(_on_special_activated)


func setup_for_race(start_transform: Transform3D) -> void:
	global_transform = start_transform
	_recovery_transform = start_transform
	horizontal_speed = 0.0
	movement_enabled = false
	_collision_stun = 0.0
	if stats != null:
		var racer_data := RacerData.load_by_id(racer_id)
		var shoe_data := ShoeDataScript.load_by_id(shoe_id)
		stats.apply_racer_and_shoe(racer_data, shoe_data)
		_setup_special_ability(racer_data)
	if drafting_system and drafting_system.has_method("setup"):
		drafting_system.setup(self)


func setup_rails(rail_world_points: Array) -> void:
	if rail_grind_system and rail_grind_system.has_method("setup"):
		rail_grind_system.setup(self, rail_world_points)


func enable_movement() -> void:
	movement_enabled = true


func apply_perfect_start(multiplier: float) -> void:
	_start_boost_multiplier = multiplier
	_start_boost_time = 1.5


func _physics_process(delta: float) -> void:
	if global_position.y < -12.0:
		_recover_from_fall()
		return
	if not movement_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	stomp_system.tick(delta)
	drift_system.tick_boost(delta)
	boost_system.tick(delta)
	if drafting_system and drafting_system.has_method("tick"):
		drafting_system.tick(delta)
	if special_ability and special_ability.has_method("tick"):
		special_ability.tick(delta)
	_tick_timers(delta)
	_update_jump_windows(delta)

	if rail_grind_system and rail_grind_system.get("is_grinding"):
		if is_player and InputManager.is_jumping() and rail_grind_system.has_method("request_jump_exit"):
			if rail_grind_system.request_jump_exit():
				velocity.y = stats.jump_force * 0.85
				state_machine.set_state(state_machine.State.AIR)
				return
		var grind: Dictionary = rail_grind_system.tick(delta)
		if grind.get("active", false):
			velocity = grind.get("velocity", Vector3.ZERO)
			move_and_slide()
			speed_changed.emit(horizontal_speed)
			_emit_movement_telemetry("RAIL")
			return

	var steer := _get_steer()
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") * stats.gravity_scale

	if is_on_floor():
		if state_machine.current_state == state_machine.State.AIR:
			if stomp_system != null and stomp_system.get("last_was_airborne"):
				stomp_system.on_air_stomp_landed(global_position, self)
				var pen := float(stomp_system.consume_recovery_penalty())
				horizontal_speed *= maxf(0.0, 1.0 - pen)
			trick_system.on_landed()
			state_machine.set_state(state_machine.State.GROUNDED)
		_coyote_timer = COYOTE_SEC
		_handle_ground_movement(delta, steer)
	else:
		state_machine.set_state(state_machine.State.AIR)
		trick_system.on_airborne(delta)
		_handle_air_movement(delta, steer, gravity)

	velocity.y -= gravity * delta
	move_and_slide()
	_handle_collision_recovery(delta)
	speed_changed.emit(horizontal_speed)
	_emit_movement_telemetry(get_speed_state())


func _handle_ground_movement(delta: float, steer: float) -> void:
	var drifting := _get_drift_input() and absf(steer) > 0.1 and horizontal_speed > 2.0
	var drift_charge_mult := 1.0
	if special_ability and special_ability.has_method("get_drift_charge_multiplier"):
		drift_charge_mult = special_ability.get_drift_charge_multiplier()
	var drift_ctrl := float(stats.drift_control)
	if stats.has_method("drift_grip_for_terrain"):
		drift_ctrl = float(stats.drift_grip_for_terrain(terrain_name))
	if drifting and drift_system.can_start_at_speed(horizontal_speed):
		if not drift_system.is_drifting:
			if not drift_system.start_drift(horizontal_speed, steer):
				drifting = false
		if drifting and drift_system.is_drifting:
			state_machine.set_state(state_machine.State.DRIFT)
			drift_system.update_drift(delta, steer, drift_ctrl, drift_charge_mult, horizontal_speed)
			_set_drift_vfx(true, drift_system.get_spark_color())
	else:
		if drift_system.is_drifting:
			drift_system.stop_drift(steer, horizontal_speed)
		_set_drift_vfx(false, Color.WHITE)
		if is_player and InputManager.is_sliding():
			state_machine.set_state(state_machine.State.SLIDE)
			_slide_timer = minf(_slide_timer + delta, MAX_SLIDE_SEC)
		else:
			_slide_timer = 0.0
			state_machine.set_state(state_machine.State.GROUNDED)

	if _wants_jump():
		if rail_grind_system and rail_grind_system.has_method("try_start_from_jump"):
			if rail_grind_system.try_start_from_jump():
				_jump_buffer = 0.0
				return
		_do_jump()
		return

	if is_player and InputManager.is_sliding() and stomp_system.can_stomp() and _slide_timer > 0.12:
		stomp_system.execute_ground_stomp(global_position, self)

	var target_speed := _compute_target_speed()
	var accel: float = stats.acceleration
	if stats.has_method("accel_for_terrain"):
		accel = float(stats.accel_for_terrain(terrain_name, terrain_speed_multiplier))
	# Cadence timing window: brief accel crest near stride apex.
	_cadence_phase = fposmod(_cadence_phase + delta / maxf(stats.cadence_period, 0.2), 1.0)
	var cadence_crest := 1.0 + 0.04 * sin(_cadence_phase * TAU)
	accel *= cadence_crest * _momentum_line_bonus
	if state_machine.current_state == state_machine.State.DRIFT:
		accel *= 0.65
	elif state_machine.current_state == state_machine.State.SLIDE:
		target_speed *= stats.slide_speed_multiplier
		# Long slide decays — no permanent low-profile exploit.
		if _slide_timer > 0.9:
			target_speed *= 0.92
	if _collision_stun > 0.0:
		accel *= 0.35
		target_speed *= 0.55

	if _get_accelerate_input():
		horizontal_speed = move_toward(horizontal_speed, target_speed, accel * delta)
		# Good line: low steer at speed preserves momentum briefly.
		if absf(steer) < 0.18 and horizontal_speed > stats.top_speed * 0.7:
			_momentum_line_bonus = move_toward(_momentum_line_bonus, 1.06, delta * 0.35)
		else:
			_momentum_line_bonus = move_toward(_momentum_line_bonus, 1.0, delta * 0.8)
	elif _get_brake_input():
		horizontal_speed = move_toward(horizontal_speed, 0.0, stats.brake_strength * delta)
		_momentum_line_bonus = 1.0
	else:
		var coast: float = float(stats.brake_strength) * 0.35
		if special_ability and special_ability.has_method("get_speed_decay_resist"):
			coast *= maxf(0.0, 1.0 - float(special_ability.get_speed_decay_resist()))
		horizontal_speed = move_toward(horizontal_speed, 0.0, coast * delta)
		_momentum_line_bonus = move_toward(_momentum_line_bonus, 1.0, delta)

	var turn_rate: float = stats.handling * terrain_handling_multiplier
	if special_ability and special_ability.has_method("get_handling_multiplier"):
		turn_rate *= special_ability.get_handling_multiplier()
	if state_machine.current_state == state_machine.State.DRIFT:
		turn_rate *= 1.35
	elif state_machine.current_state == state_machine.State.SLIDE:
		turn_rate *= float(stats.slide_handling_multiplier)
	if horizontal_speed > 0.5:
		rotate_y(-steer * turn_rate * delta * 0.08)

	var forward := -global_transform.basis.z
	velocity.x = forward.x * horizontal_speed
	velocity.z = forward.z * horizontal_speed

	if is_player:
		_handle_player_actions()


func _handle_air_movement(delta: float, steer: float, _gravity: float) -> void:
	if is_player and InputManager.is_tricking():
		trick_system.try_trick()
	if is_player and InputManager.is_sliding() and stomp_system.can_stomp():
		stomp_system.execute_air_stomp(self)
		state_machine.set_state(state_machine.State.STOMP)
	if is_player and InputManager.is_jumping() and rail_grind_system:
		if rail_grind_system.has_method("try_start_from_jump"):
			rail_grind_system.try_start_from_jump()
	# Coyote / buffered jump only when recently grounded — no infinite air chain.
	if _wants_jump() and _coyote_timer > 0.0 and velocity.y <= 0.5:
		_do_jump()
		return

	var forward := -global_transform.basis.z
	var air_cap: float = float(stats.air_control)
	velocity.x += forward.x * steer * air_cap * delta
	velocity.z += forward.z * steer * air_cap * delta
	# Bound air lateral so air control cannot exceed grounded turn authority.
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var max_air: float = maxf(horizontal_speed, stats.top_speed * 0.85) + air_cap * 0.5
	if horiz.length() > max_air:
		horiz = horiz.normalized() * max_air
		velocity.x = horiz.x
		velocity.z = horiz.z
	rotate_y(-steer * air_cap * 0.05 * delta)


func _handle_collision_recovery(delta: float) -> void:
	_last_wall_kick = false
	if get_slide_collision_count() == 0:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col == null:
			continue
		var normal := col.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.05:
			continue
		normal = normal.normalized()
		# Wall scrape: bleed speed and push off rather than sticking in geometry.
		horizontal_speed *= 0.82
		global_position += normal * 0.12
		_collision_stun = maxf(_collision_stun, 0.35)
		# Wall-kick window: jump + collision while moving grants a rebound.
		if _wall_kick_cooldown <= 0.0 and is_player and InputManager.is_jumping():
			velocity += normal * 7.5
			velocity.y = maxf(velocity.y, stats.jump_force * 0.65)
			horizontal_speed = maxf(horizontal_speed, stats.top_speed * 0.55)
			_wall_kick_cooldown = 0.8
			_last_wall_kick = true
			if TelemetryBus != null:
				TelemetryBus.record("wall_kick", {"racer_id": racer_id})
		break
	_collision_stun = maxf(0.0, _collision_stun - delta)


func _handle_player_actions() -> void:
	if local_player_index == 0:
		if InputManager.is_boosting():
			boost_system.try_consume_boost()
		if InputManager.is_using_item():
			item_manager.use_held_item(self)
		if InputManager.is_special() and special_ability and special_ability.has_method("try_activate"):
			special_ability.try_activate()
	elif local_player_index == 1:
		if Input.is_action_just_pressed("p2_boost") or Input.is_action_just_pressed("boost"):
			boost_system.try_consume_boost()
		if Input.is_action_just_pressed("p2_use_item") or Input.is_action_just_pressed("use_item"):
			item_manager.use_held_item(self)
		if Input.is_action_just_pressed("special") and special_ability and special_ability.has_method("try_activate"):
			special_ability.try_activate()


func _compute_target_speed() -> float:
	var mult := terrain_speed_multiplier
	if stats != null and stats.has_method("affinity_for") and terrain_name != "standard":
		mult *= clampf(0.92 + 0.08 * float(stats.affinity_for(terrain_name)), 0.75, 1.2)
	mult *= drift_system.get_speed_multiplier()
	mult *= boost_system.get_speed_multiplier()
	if stats != null:
		mult *= float(stats.boost_efficiency) if boost_system.get_speed_multiplier() > 1.01 else 1.0
	mult *= _start_boost_multiplier
	if drafting_system and drafting_system.has_method("get_speed_multiplier"):
		mult *= drafting_system.get_speed_multiplier()
	if special_ability and special_ability.has_method("get_speed_multiplier"):
		mult *= special_ability.get_speed_multiplier()
	if _slow_timer > 0.0:
		var slow_mult := 0.55
		if special_ability and special_ability.has_method("get_slow_resist"):
			slow_mult = lerpf(0.55, 1.0, special_ability.get_slow_resist())
		mult *= slow_mult
	# Doctrine: never apply place-based competitive speed assist.
	return stats.top_speed * mult


func _tick_timers(delta: float) -> void:
	if _start_boost_time > 0.0:
		_start_boost_time = maxf(0.0, _start_boost_time - delta)
		if _start_boost_time <= 0.0:
			_start_boost_multiplier = 1.0
	if _slow_timer > 0.0:
		_slow_timer = maxf(0.0, _slow_timer - delta)
	if _wall_kick_cooldown > 0.0:
		_wall_kick_cooldown = maxf(0.0, _wall_kick_cooldown - delta)
	if _collision_stun > 0.0:
		_collision_stun = maxf(0.0, _collision_stun - delta)


func _update_jump_windows(delta: float) -> void:
	if is_player and InputManager.is_jumping():
		_jump_buffer = JUMP_BUFFER_SEC
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if not is_on_floor():
		_coyote_timer = maxf(0.0, _coyote_timer - delta)


func _wants_jump() -> bool:
	if not is_player:
		return false
	return _jump_buffer > 0.0 or InputManager.is_jumping()


func _do_jump() -> void:
	velocity.y = stats.jump_force
	state_machine.set_state(state_machine.State.AIR)
	_jump_buffer = 0.0
	_coyote_timer = 0.0
	if TelemetryBus != null:
		TelemetryBus.record("jump", {"racer_id": racer_id})


func _get_steer() -> float:
	if is_player:
		if local_player_index == 1:
			var steer := Input.get_action_strength("p2_move_right") - Input.get_action_strength("p2_move_left")
			# Prefer gamepad 1 when present.
			if Input.get_connected_joypads().size() > 1:
				steer = Input.get_joy_axis(1, JOY_AXIS_LEFT_X)
			return clampf(steer, -1.0, 1.0)
		return InputManager.get_steer()
	return 0.0


func _get_accelerate_input() -> bool:
	if is_player:
		if local_player_index == 1:
			if Input.is_action_pressed("p2_accelerate"):
				return true
			if Input.get_connected_joypads().size() > 1 and Input.get_joy_axis(1, JOY_AXIS_TRIGGER_RIGHT) > 0.3:
				return true
			return false
		return InputManager.is_accelerating()
	return true


func _get_brake_input() -> bool:
	if is_player:
		if local_player_index == 1:
			if Input.is_action_pressed("p2_brake"):
				return true
			if Input.get_connected_joypads().size() > 1 and Input.get_joy_axis(1, JOY_AXIS_TRIGGER_LEFT) > 0.3:
				return true
			return false
		return InputManager.is_braking()
	return false


func _get_drift_input() -> bool:
	if is_player:
		if local_player_index == 1:
			if Input.is_action_pressed("p2_drift"):
				return true
			if Input.get_connected_joypads().size() > 1 and Input.is_joy_button_pressed(1, JOY_BUTTON_LEFT_SHOULDER):
				return true
			return false
		return InputManager.is_drifting()
	return false


func set_terrain_modifiers(name: String, speed_mult: float, handling_mult: float) -> void:
	terrain_name = name
	# Shoe material affinities also apply on "standard" exit resets via affinity_for.
	var affinity := 1.0
	if stats != null and stats.has_method("affinity_for"):
		affinity = float(stats.affinity_for(name))
	elif not shoe_id.is_empty():
		affinity = ShoeDataScript.surface_affinity(shoe_id, name)
	if name == "standard":
		terrain_speed_multiplier = 1.0
		terrain_handling_multiplier = 1.0
	else:
		terrain_speed_multiplier = speed_mult
		terrain_handling_multiplier = handling_mult
	set_meta("shoe_surface_affinity", affinity)
	set_meta("shoe_material_family", ShoeDataScript.material_family(shoe_id))
	terrain_changed.emit(name)


func collect_boost_pickup() -> void:
	boost_system.add_boost(boost_system.pickup_amount, "pickup")


func apply_stomp_slow(duration: float) -> void:
	if shield_active:
		shield_active = false
		return
	if item_manager and item_manager.has_method("consume_bounce_bubble") and item_manager.consume_bounce_bubble():
		velocity.y = maxf(velocity.y, 7.0)
		return
	_slow_timer = maxf(_slow_timer, duration)


func apply_lace_trap_slow(duration: float) -> void:
	apply_stomp_slow(duration)


func activate_shield() -> void:
	shield_active = true


func set_recovery_transform(recovery_transform: Transform3D) -> void:
	_recovery_transform = recovery_transform


func _recover_from_fall() -> void:
	var visual := get_node_or_null("RacerVisual")
	if visual != null and visual.has_method("play_stumble"):
		visual.play_stumble()
	var follower := get_node_or_null("AcceptPathFollower")
	if follower != null and follower.has_method("snap_to_path") and follower.get("path") != null:
		var path: Path3D = follower.path
		if path != null and path.curve != null:
			var offset := path.curve.get_closest_offset(path.to_local(global_position))
			follower.snap_to_path(self, offset, 0.0)
		else:
			global_transform = _recovery_transform
	else:
		global_transform = _recovery_transform
	velocity = Vector3.ZERO
	horizontal_speed = maxf(horizontal_speed * 0.35, 0.0)
	_collision_stun = 0.6
	terrain_speed_multiplier = 1.0
	terrain_handling_multiplier = 1.0
	if visual != null and visual.has_method("play_recovery"):
		get_tree().create_timer(0.35).timeout.connect(func ():
			if is_instance_valid(visual) and visual.has_method("play_recovery"):
				visual.play_recovery()
		)


func _on_special_activated(ability_id: String) -> void:
	special_ability_activated.emit(ability_id)
	var bus := get_tree().root.get_node_or_null("TelemetryBus") if get_tree() else null
	if bus != null and bus.has_method("special_ability"):
		bus.special_ability(ability_id, racer_id)


func get_speed_state() -> String:
	if boost_system != null and boost_system.get_speed_multiplier() > 1.05:
		return "BOOST"
	if drift_system != null and drift_system.is_drifting:
		return "DRIFT"
	if horizontal_speed < 4.0:
		return "WALK"
	if horizontal_speed < 14.0:
		return "JOG"
	return "SPRINT"


func _on_drift_released(multiplier: float, tier: int) -> void:
	boost_system.add_boost(8.0 + tier * 6.0, "drift_release")
	boost_system.apply_external_boost(multiplier, drift_system.boost_durations[clampi(tier, 0, 3)], "drift_release")
	if TelemetryBus != null:
		TelemetryBus.record("drift_release", {"tier": tier, "racer_id": racer_id})


func _on_trick_landed(success: bool, reward: float, trick_id: String = "", combo: int = 0) -> void:
	if success:
		boost_system.add_boost(reward, "trick")
	elif reward < 0.0:
		# Single penalty path — add_boost already clamps; do not also mutate current_boost.
		boost_system.add_boost(reward, "trick_fail")
	if TelemetryBus != null:
		TelemetryBus.record("trick", {
			"success": success,
			"trick_id": trick_id,
			"combo": combo,
			"racer_id": racer_id,
		})


func _emit_movement_telemetry(movement_state: String) -> void:
	if TelemetryBus == null or not is_player:
		return
	if Engine.get_physics_frames() % 15 != 0:
		return
	TelemetryBus.record("movement_sample", {
		"racer_id": racer_id,
		"shoe_id": shoe_id,
		"speed": snappedf(horizontal_speed, 0.01),
		"movement_state": movement_state,
		"terrain": terrain_name,
		"drift_tier": int(drift_system.spark_tier) if drift_system else 0,
		"boost_source": str(boost_system.get_active_source()) if boost_system.has_method("get_active_source") else "none",
		"boost_duration": snappedf(float(boost_system.get_active_duration_left()) if boost_system.has_method("get_active_duration_left") else 0.0, 0.01),
		"position": int(get_meta("race_place_estimate", 0)),
		"assist_flags": {
			"auto_accelerate": GameManager != null and GameManager.auto_accelerate,
			"mobile_assist": GameManager != null and absf(float(GameManager.mobile_assist_steer)) > 0.01,
			"competitive_mode": GameManager != null and GameManager.competitive_mode,
		},
	})


func _on_item_warning(item_id: String, seconds: float, _target: Node) -> void:
	item_warning_received.emit(item_id, seconds)


func _set_drift_vfx(active: bool, color: Color) -> void:
	if drift_particles == null:
		return
	var emit := active
	if emit and AccessibilitySettings != null and AccessibilitySettings.reduce_motion:
		emit = false
	drift_particles.emitting = emit
	var mat := drift_particles.process_material as ParticleProcessMaterial
	if mat:
		mat.color = color
