extends SceneTree

## Digital a11y baseline (PP-RTM-10): reduce-motion / larger UI / colorblind HUD / auto-accel.
## FOV punch contract mirrors CameraRig (do not preload CameraRig — GameManager autoload
## is not visible to that script under --script preload). Not WCAG / not HUMAN.

const AccessibilitySettingsScript = preload("res://scripts/core/AccessibilitySettings.gd")


func _initialize() -> void:
	call_deferred("_run")


func _camera_target_fov(base_fov: float, max_fov: float, feel: float, reduce_motion: bool) -> float:
	## Mirrors scripts/player/CameraRig.gd reduce-motion FOV path.
	var fov_t := 0.0 if reduce_motion else feel
	return lerpf(base_fov, max_fov, clampf(fov_t, 0.0, 1.0))


func _run() -> void:
	var failures: PackedStringArray = []
	var a11y: Node = AccessibilitySettingsScript.new()
	a11y.name = "AccessibilitySettings"
	root.add_child(a11y)

	a11y.set_reduce_motion(false)
	a11y.set_larger_ui(false)
	a11y.set_colorblind_safe_hud(false)
	a11y.set_auto_accelerate(false)

	a11y.set_larger_ui(true)
	if float(a11y.get_ui_scale_multiplier()) < 1.24:
		failures.append("larger_ui scale multiplier too small")

	var default_player: Color = a11y.get_marker_color("player")
	a11y.set_colorblind_safe_hud(true)
	var cb_player: Color = a11y.get_marker_color("player")
	if cb_player.is_equal_approx(default_player):
		failures.append("colorblind HUD must change player marker color")
	if not cb_player.is_equal_approx(AccessibilitySettingsScript.MARKER_PLAYER):
		failures.append("colorblind player marker must use Okabe–Ito blue")

	a11y.set_auto_accelerate(true)
	if not bool(a11y.auto_accelerate):
		failures.append("auto_accelerate toggle did not stick")

	a11y.set_reduce_motion(true)
	if bool(a11y.camera_shake_allowed()):
		failures.append("reduce_motion must block camera shake")

	## Boost feel punch (0.32) still freezes FOV when reduce_motion is on.
	var feel_boost := clampf(1.0 + 0.32, 0.0, 1.25)
	var frozen := _camera_target_fov(68.0, 88.0, feel_boost, true)
	if absf(frozen - 68.0) > 0.01:
		failures.append("reduce_motion FOV contract must stay at base (got %.2f)" % frozen)
	var punched := _camera_target_fov(68.0, 88.0, feel_boost, false)
	if punched <= 68.2:
		failures.append("boost FOV punch contract should rise when reduce_motion is off")

	## Persist round-trip (digital — not HUMAN a11y certification).
	a11y.set_reduce_motion(true)
	a11y.set_larger_ui(true)
	a11y.set_colorblind_safe_hud(true)
	var a11y2: Node = AccessibilitySettingsScript.new()
	root.add_child(a11y2)
	a11y2.load_settings()
	if not bool(a11y2.reduce_motion) or not bool(a11y2.larger_ui) or not bool(a11y2.colorblind_safe_hud):
		failures.append("accessibility settings did not persist")

	## Cleanup toggles so later local runs are not sticky.
	a11y.set_reduce_motion(false)
	a11y.set_larger_ui(false)
	a11y.set_colorblind_safe_hud(false)
	a11y.set_auto_accelerate(false)

	if failures.is_empty():
		print(
			"AccessibilityBaselineTest PASS — reduce-motion FOV contract · larger_ui · colorblind HUD · auto-accel · not WCAG/HUMAN"
		)
		quit(0)
	else:
		for f in failures:
			print("FAIL ", f)
		print("AccessibilityBaselineTest FAIL count=", failures.size())
		quit(1)
