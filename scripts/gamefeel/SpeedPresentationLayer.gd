extends CanvasLayer
class_name SpeedPresentationLayer

## Layered speed cues without camera jitter. Reduced Motion keeps state, drops motion.

const SPEED_LINE_THRESHOLD := 0.72
const BOOST_VIGNETTE := 0.22

var _vignette: ColorRect
var _lines: Array[ColorRect] = []
var _ratio: float = 0.0
var _boosting: bool = false
var _reduced: bool = false
var presenting: bool = false


func _ready() -> void:
	layer = 8
	_vignette = ColorRect.new()
	_vignette.name = "SpeedVignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0.02, 0.05, 0.1, 0.0)
	add_child(_vignette)
	for i in 6:
		var line := ColorRect.new()
		line.name = "SpeedLine_%d" % i
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.color = Color(1, 1, 1, 0)
		line.size = Vector2(4, 90 + i * 12)
		add_child(line)
		_lines.append(line)


func set_reduced_motion(active: bool) -> void:
	_reduced = active
	if active:
		presenting = false
		if _vignette:
			_vignette.color.a = 0.0
		for line in _lines:
			line.color.a = 0.0


func apply(speed_ratio: float, boosting: bool, profile: int) -> void:
	_ratio = clampf(speed_ratio, 0.0, 1.35)
	_boosting = boosting
	_reduced = profile == 2
	var show_lines := (not _reduced) and _ratio >= SPEED_LINE_THRESHOLD
	presenting = show_lines or (_boosting and not _reduced)
	if _vignette:
		var a := 0.0
		if not _reduced:
			a = maxf((_ratio - 0.55) * 0.18, 0.0)
			if _boosting:
				a += BOOST_VIGNETTE * 0.45
		_vignette.color.a = clampf(a, 0.0, 0.28)
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	for i in _lines.size():
		var line := _lines[i]
		if not show_lines:
			line.color.a = 0.0
			continue
		var edge := 0.08 + float(i % 2) * 0.84
		line.position = Vector2(vp.x * edge, 40.0 + float(i) * 70.0)
		line.color = Color(0.85, 0.95, 1.0, clampf((_ratio - SPEED_LINE_THRESHOLD) * 1.4, 0.0, 0.35))
