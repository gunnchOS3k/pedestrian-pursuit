extends Node
class_name LocomotionPresenter

## Presentation-only locomotion: lean, stride cadence, landing squash, skid pose.
## Does not rewrite physics.

var lean: float = 0.0
var stride_rate: float = 0.0
var landing_compression: float = 0.0
var skid: float = 0.0
var boost_posture: float = 0.0
var _was_airborne: bool = false
var _air_vy: float = 0.0


func tick(delta: float, body: CharacterBody3D, boosting: bool, drifting: bool, steer: float) -> void:
	if body == null:
		return
	var speed := 0.0
	if "horizontal_speed" in body:
		speed = float(body.horizontal_speed)
	else:
		var vel: Vector3 = body.velocity
		vel.y = 0.0
		speed = vel.length()
	stride_rate = clampf(speed * 0.22, 0.0, 8.0)
	var target_lean := clampf(steer * 0.22, -0.28, 0.28)
	lean = lerpf(lean, target_lean, 1.0 - exp(-10.0 * delta))
	skid = lerpf(skid, 1.0 if drifting else 0.0, 1.0 - exp(-8.0 * delta))
	boost_posture = lerpf(boost_posture, 1.0 if boosting else 0.0, 1.0 - exp(-7.0 * delta))
	var grounded := body.is_on_floor() if body.has_method("is_on_floor") else true
	var vy := float(body.velocity.y)
	if not grounded:
		_was_airborne = true
		_air_vy = vy
	elif _was_airborne:
		if _air_vy < -4.0:
			landing_compression = clampf((-_air_vy - 4.0) / 10.0, 0.12, 0.55)
		_was_airborne = false
		_air_vy = 0.0
	landing_compression = maxf(0.0, landing_compression - delta * 2.4)
	var visual := body.get_node_or_null("RacerVisual")
	if visual != null and visual.has_method("apply_locomotion_presentation"):
		visual.apply_locomotion_presentation(lean, landing_compression, skid, boost_posture)
