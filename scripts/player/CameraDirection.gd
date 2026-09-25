extends RefCounted
class_name CameraDirection

## Shared chase-camera orientation contract.
## Racer forward and camera optical forward are both local -Z.
## Do not flip meshes, invert steering, or change gameplay velocity to satisfy this.

static func flatten(dir: Vector3) -> Vector3:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.000001:
		return Vector3(0.0, 0.0, -1.0)
	return d.normalized()


static func racer_forward(basis: Basis) -> Vector3:
	return flatten(-basis.z)


static func optical_forward(basis: Basis) -> Vector3:
	return flatten(-basis.z)


static func yaw_for_minus_z_forward(dir: Vector3) -> float:
	var d := flatten(dir)
	return atan2(-d.x, -d.z)


static func yaw_plus_z_forward(dir: Vector3) -> float:
	## Reversed conversion shipped on PR #33. Kept to prove the 180° bug.
	var d := flatten(dir)
	return atan2(d.x, d.z)


static func optical_xz_from_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func springarm_yaw_for_behind(optical_yaw: float) -> float:
	## SpringArm3D extends along local -Z, so the arm must face opposite travel
	## for the Camera3D child to sit physically behind the racer.
	return wrapf(optical_yaw + PI, -PI, PI)


static func is_behind_racer(target_pos: Vector3, camera_pos: Vector3, forward: Vector3) -> bool:
	var to_cam := camera_pos - target_pos
	to_cam.y = 0.0
	var f := flatten(forward)
	if to_cam.length_squared() < 0.000001:
		return false
	return to_cam.dot(f) < 0.0
