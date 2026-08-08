extends RefCounted
class_name LaunchArtCatalog

## Resolves procedural launch presentation textures for menu/HUD/items/footwear.


static func racer_icon(runner_id: String) -> Texture2D:
	return _tex("res://assets/art/racers/%s.png" % runner_id)


static func shoe_icon(shoe_id: String) -> Texture2D:
	return _tex("res://assets/art/shoes/%s.png" % shoe_id)


static func item_icon(item_id: String) -> Texture2D:
	return _tex("res://assets/art/items/%s.png" % item_id)


static func track_icon(track_id: String) -> Texture2D:
	return _tex("res://assets/art/tracks/%s.png" % track_id)


static func ui_texture(name: String) -> Texture2D:
	return _tex("res://assets/art/ui/%s.png" % name)


static func vfx_texture(name: String) -> Texture2D:
	return _tex("res://assets/art/vfx/%s.png" % name)


static func art_status_is_launch_final(status: String) -> bool:
	return status in ["LAUNCH_PROCEDURAL_FINAL", "PROCEDURAL_FINAL", "FINAL"]


static func inventory_path() -> String:
	return "res://data/art/LAUNCH_ART_INVENTORY.json"


static func provenance_path() -> String:
	return "res://data/art/provenance.json"


static func _tex(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var res = load(path)
	return res as Texture2D
