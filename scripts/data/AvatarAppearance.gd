class_name AvatarAppearance
extends RefCounted

## Cosmetic-only modular avatar appearance. Never mutates hitboxes / handling stats.

const SCHEMA_VERSION := 1

var schema_version: int = SCHEMA_VERSION
var height_scale: float = 1.0
var width_scale: float = 1.0
var leg_scale: float = 1.0
var skin_tone: String = "warm_medium" ## catalog id
var undertone: String = "neutral"
var face_shape: String = "oval"
var hair_style: String = "short_fade" ## includes braids/locs/twists/protective
var hair_color: String = "#2A1A12"
var facial_hair: String = "none"
var makeup: String = "none"
var scar: String = "none"
var birthmark: String = "none"
var head_covering: String = "none"
var assistive: String = "none" ## prosthetic/assistive visual option id
var expression_idle: String = "neutral"
var expression_start: String = "focused"
var expression_victory: String = "bright"


static func default_appearance():
	return new()


static func from_dict(data: Dictionary):
	var a = new()
	a.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	a.height_scale = clampf(float(data.get("height_scale", 1.0)), 0.85, 1.2)
	a.width_scale = clampf(float(data.get("width_scale", 1.0)), 0.85, 1.2)
	a.leg_scale = clampf(float(data.get("leg_scale", 1.0)), 0.85, 1.2)
	a.skin_tone = str(data.get("skin_tone", a.skin_tone))
	a.undertone = str(data.get("undertone", a.undertone))
	a.face_shape = str(data.get("face_shape", a.face_shape))
	a.hair_style = str(data.get("hair_style", a.hair_style))
	a.hair_color = str(data.get("hair_color", a.hair_color))
	a.facial_hair = str(data.get("facial_hair", a.facial_hair))
	a.makeup = str(data.get("makeup", a.makeup))
	a.scar = str(data.get("scar", a.scar))
	a.birthmark = str(data.get("birthmark", a.birthmark))
	a.head_covering = str(data.get("head_covering", a.head_covering))
	a.assistive = str(data.get("assistive", a.assistive))
	a.expression_idle = str(data.get("expression_idle", a.expression_idle))
	a.expression_start = str(data.get("expression_start", a.expression_start))
	a.expression_victory = str(data.get("expression_victory", a.expression_victory))
	return a


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"height_scale": height_scale,
		"width_scale": width_scale,
		"leg_scale": leg_scale,
		"skin_tone": skin_tone,
		"undertone": undertone,
		"face_shape": face_shape,
		"hair_style": hair_style,
		"hair_color": hair_color,
		"facial_hair": facial_hair,
		"makeup": makeup,
		"scar": scar,
		"birthmark": birthmark,
		"head_covering": head_covering,
		"assistive": assistive,
		"expression_idle": expression_idle,
		"expression_start": expression_start,
		"expression_victory": expression_victory,
		"affects_collision": false,
		"affects_stats": false,
	}


static func skin_color(tone_id: String, undertone_id: String = "neutral") -> Color:
	var base := Color(0.78, 0.58, 0.45)
	match tone_id:
		"deep_cool":
			base = Color(0.28, 0.18, 0.14)
		"deep_warm":
			base = Color(0.36, 0.22, 0.14)
		"rich_brown":
			base = Color(0.45, 0.28, 0.18)
		"warm_medium":
			base = Color(0.72, 0.52, 0.38)
		"golden_medium":
			base = Color(0.82, 0.62, 0.42)
		"light_warm":
			base = Color(0.92, 0.74, 0.6)
		"light_cool":
			base = Color(0.9, 0.78, 0.72)
		"porcelain":
			base = Color(0.96, 0.88, 0.82)
		_:
			pass
	match undertone_id:
		"warm":
			base = base.lerp(Color(0.95, 0.7, 0.45), 0.12)
		"cool":
			base = base.lerp(Color(0.7, 0.65, 0.85), 0.1)
		"olive":
			base = base.lerp(Color(0.55, 0.65, 0.4), 0.08)
		_:
			pass
	return base
