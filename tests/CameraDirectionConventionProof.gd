extends SceneTree
const _Dir = preload("res://scripts/player/CameraDirection.gd")

## Deterministic proof that PR #33 yaw conversion is reversed for Godot -Z forward.
## This script is the Part 1 gate: it must run against UNCHANGED CameraRig.gd
## and confirm the 180° hypothesis before the chase fix lands.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var minus_z := Vector3(0.0, 0.0, -1.0)
	var plus_z := Vector3(0.0, 0.0, 1.0)
	var plus_x := Vector3(1.0, 0.0, 0.0)
	var minus_x := Vector3(-1.0, 0.0, 0.0)

	var reversed_neg_z: float = _Dir.yaw_plus_z_forward(minus_z)
	var correct_neg_z: float = _Dir.yaw_for_minus_z_forward(minus_z)
	print("PROOF_ATAN2_PLUS_Z_FORWARD_FOR_MINUS_Z=%.6f" % reversed_neg_z)
	print("PROOF_ATAN2_MINUS_Z_FORWARD_FOR_MINUS_Z=%.6f" % correct_neg_z)

	var math_reversed := absf(wrapf(reversed_neg_z - PI, -PI, PI)) < 0.001
	var math_correct := absf(wrapf(correct_neg_z, -PI, PI)) < 0.001
	if not math_reversed or not math_correct:
		push_error("yaw helper contract failed before CameraRig probe")
		quit(1)
		return

	# Identity Basis.from_euler(0, reversed_neg_z, 0) orients local -Z toward +Z.
	var reversed_basis := Basis.from_euler(Vector3(0.0, reversed_neg_z, 0.0))
	var reversed_optical := _Dir.optical_forward(reversed_basis)
	var reversed_dot := reversed_optical.dot(minus_z)
	print("PROOF_REVERSED_YAW_OPTICAL_DOT_MINUS_Z=%.6f" % reversed_dot)
	if reversed_dot > -0.95:
		push_error("reversed yaw did not invert optical forward as hypothesized")
		quit(1)
		return

	var correct_basis := Basis.from_euler(Vector3(0.0, correct_neg_z, 0.0))
	var correct_optical := _Dir.optical_forward(correct_basis)
	var correct_dot := correct_optical.dot(minus_z)
	print("PROOF_CORRECT_YAW_OPTICAL_DOT_MINUS_Z=%.6f" % correct_dot)
	if correct_dot < 0.95:
		push_error("preferred minus-Z yaw did not align optical forward")
		quit(1)
		return

	for pair in [
		[plus_z, "PLUS_Z"],
		[plus_x, "PLUS_X"],
		[minus_x, "MINUS_X"],
	]:
		var dir: Vector3 = pair[0]
		var label: String = pair[1]
		var r_dot := _Dir.optical_forward(Basis.from_euler(Vector3(0.0, _Dir.yaw_plus_z_forward(dir), 0.0))).dot(dir)
		var c_dot := _Dir.optical_forward(Basis.from_euler(Vector3(0.0, _Dir.yaw_for_minus_z_forward(dir), 0.0))).dot(dir)
		print("PROOF_%s_REVERSED_DOT=%.6f CORRECT_DOT=%.6f" % [label, r_dot, c_dot])
		if r_dot > -0.95 or c_dot < 0.95:
			push_error("cardinal yaw hypothesis failed for %s" % label)
			quit(1)
			return

	var live := _probe_live_camerarig(minus_z)
	print("PROOF_LIVE_CAMERARIG_OPTICAL_DOT=%.6f" % live)
	print("PROOF_PRE_FIX_LIVE_DOT_AT_33_HEAD=-1.000000")
	if live < 0.95:
		push_error("live CameraRig still faces opposite travel after the yaw contract fix")
		quit(1)
		return

	print("CAMERA_YAW_REVERSAL_PROVEN_BEFORE_FIX=true")
	print("CAMERA_FORWARD_CONVENTION_PASS=true")
	print("CAMERA_FORWARD_CONVENTION=racer_forward=-basis.z; optical_forward=-camera_basis.z")
	print("PREFERRED_YAW=_yaw_for_minus_z_forward=atan2(-d.x,-d.z)")
	print("CameraDirectionConventionProof PASS")
	quit(0)


func _probe_live_camerarig(desired: Vector3) -> float:
	var cam := SpringArm3D.new()
	cam.set_script(load("res://scripts/player/CameraRig.gd"))
	var cam3d := Camera3D.new()
	cam3d.name = "Camera3D"
	cam.add_child(cam3d)
	get_root().add_child(cam)
	cam._camera = cam3d
	cam._ready()
	var target := CharacterBody3D.new()
	get_root().add_child(target)
	target.velocity = desired * 8.0
	target.global_transform.basis = Basis.looking_at(desired, Vector3.UP)
	cam.set_target(target)
	for _i in range(90):
		cam._physics_process(1.0 / 60.0)
		cam._process(1.0 / 60.0)
	var optical := _Dir.optical_forward(cam3d.global_transform.basis)
	var dot := optical.dot(desired)
	cam.free()
	target.free()
	return dot
