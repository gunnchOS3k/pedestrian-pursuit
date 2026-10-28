extends SceneTree

## Headless: 50-vehicle registry, Street Legends playable, six items intact.

const VehicleCatalogScript = preload("res://scripts/data/VehicleCatalog.gd")
const ShoeDataScript = preload("res://scripts/data/ShoeData.gd")
const ItemDataScript = preload("res://scripts/data/ItemData.gd")


func _init() -> void:
	var failures: PackedStringArray = []
	VehicleCatalogScript.load_registry(true)
	var ids := VehicleCatalogScript.all_ids()
	if ids.size() != 50:
		failures.append("registry size %d != 50" % ids.size())
	var playable := VehicleCatalogScript.playable_ids()
	if playable.size() != 8:
		failures.append("playable size %d != 8" % playable.size())
	var stubs := VehicleCatalogScript.stub_ids()
	if stubs.size() != 42:
		failures.append("stub size %d != 42" % stubs.size())
	for vid in playable:
		var shoe := ShoeDataScript.load_by_id(str(vid))
		if shoe.is_empty():
			failures.append("playable shoe missing %s" % vid)
			continue
		if not bool(shoe.get("playable", false)):
			failures.append("playable flag false for %s" % vid)
		if str(shoe.get("art_status", "")) != "native_v1":
			failures.append("playable art_status not native_v1: %s" % vid)
		if float(shoe.get("handling_modifier", 0.0)) <= 0.0:
			failures.append("handling missing for %s" % vid)
	for vid in stubs:
		var entry := VehicleCatalogScript.by_id(str(vid))
		if str(entry.get("art_status", "")) != "stub_not_final":
			failures.append("stub art flag wrong: %s" % vid)
		if bool(entry.get("playable", true)):
			failures.append("stub marked playable: %s" % vid)
	var race_ids := ShoeDataScript.race_selectable_ids()
	if race_ids.size() != 8:
		failures.append("race_selectable_ids %d != 8" % race_ids.size())
	## Signature shoes for eight roster runners.
	var runners := [
		"dash_reed", "nova_quill", "sierra_flux", "mira_lane",
		"bolt_harbor", "zig_riven", "solen_pike", "kai_volt",
	]
	for rid in runners:
		var sig := VehicleCatalogScript.signature_vehicle_for_runner(rid)
		if sig.is_empty() or not ShoeDataScript.is_playable(sig):
			failures.append("missing signature vehicle for %s" % rid)
	## Six race items preserved.
	var items := ItemDataScript.all_mvp_ids()
	if items.size() < 6:
		failures.append("item pool < 6")
	for iid in items:
		var item := ItemDataScript.load_by_id(str(iid))
		if item.is_empty() or not item.has("counterplay"):
			failures.append("item broken: %s" % iid)
	## Legacy shoes still load for challenges.
	for lid in ShoeDataScript.legacy_ids():
		if ShoeDataScript.load_by_id(lid).is_empty():
			failures.append("legacy shoe missing %s" % lid)

	if failures.is_empty():
		print("VehicleGarageTest PASS — 50 IDs, 8 playable Street Legends, 42 stubs, 6 items.")
		quit(0)
	else:
		print("VehicleGarageTest FAIL:")
		for f in failures:
			print(" - ", f)
		quit(1)
