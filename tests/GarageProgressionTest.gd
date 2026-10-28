extends SceneTree

const VehicleCatalogScript = preload("res://scripts/data/VehicleCatalog.gd")
const GarageProgressionScript = preload("res://scripts/data/GarageProgression.gd")
const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")


func _init() -> void:
	var failures: PackedStringArray = []
	GarageProgressionScript.set_test_unlock_all(false)
	VehicleCatalogScript.load_registry(true)
	var starters := GarageProgressionScript.starter_ids()
	if starters.size() < 8:
		failures.append("starter_ids too small: %d" % starters.size())
	var player_ids := GarageProgressionScript.player_selectable_ids()
	if player_ids.size() != starters.size():
		failures.append("player selectable without career unlocks should equal starters")
	## Modes must not all be starter.
	var modes: Dictionary = {}
	for vid in VehicleCatalogScript.playable_ids():
		var m := GarageProgressionScript.unlock_mode(vid)
		modes[m] = int(modes.get(m, 0)) + 1
	if int(modes.get("starter", 0)) == 50:
		failures.append("all vehicles still starter — progression not migrated")
	for need in ["cup", "challenge", "achievement", "crossover"]:
		if int(modes.get(need, 0)) < 1:
			failures.append("missing unlock mode %s" % need)
	## Test harness unlock-all restores CI race selectability without career claim.
	GarageProgressionScript.set_test_unlock_all(true)
	if ShoeDataScript.race_selectable_ids().size() != 50:
		failures.append("test unlock-all race_selectable_ids != 50")
	GarageProgressionScript.set_test_unlock_all(false)
	if ShoeDataScript.race_selectable_ids().size() == 50:
		failures.append("player race_selectable should not be all 50 without unlocks")

	if failures.is_empty():
		print(
			"GarageProgressionTest PASS — starters %d · modes %s"
			% [starters.size(), str(modes)]
		)
		quit(0)
	else:
		print("GarageProgressionTest FAIL:")
		for f in failures:
			print(" - ", f)
		quit(1)
