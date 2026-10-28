extends SceneTree

## Headless: 50-vehicle registry, Street+Roller playable, six items intact.

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
	if playable.size() != 15:
		failures.append("playable size %d != 15" % playable.size())
	var stubs := VehicleCatalogScript.stub_ids()
	if stubs.size() != 35:
		failures.append("stub size %d != 35" % stubs.size())
	var rollers := VehicleCatalogScript.vehicles_in_family("roller_revolution")
	if rollers.size() != 7:
		failures.append("roller family size %d != 7" % rollers.size())
	for rv in rollers:
		if not bool(rv.get("playable", false)):
			failures.append("roller not playable: %s" % str(rv.get("id", "")))
		if str(rv.get("art_status", "")) != "native_v1":
			failures.append("roller art not native_v1: %s" % str(rv.get("id", "")))
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
	if race_ids.size() != 15:
		failures.append("race_selectable_ids %d != 15" % race_ids.size())
	## Roller fingerprints must not be cosmetic-only duplicates.
	var roller_fps: Dictionary = {}
	for rv in rollers:
		var fp := "%s|%s|%s|%s|%s|%s|%s|%s" % [
			str(rv.get("top_speed_modifier")),
			str(rv.get("acceleration_modifier")),
			str(rv.get("handling_modifier")),
			str(rv.get("drift_modifier")),
			str(rv.get("jump_modifier")),
			str(rv.get("boost_modifier")),
			str(rv.get("stomp_modifier")),
			str(rv.get("material_family")),
		]
		if roller_fps.has(fp):
			failures.append("duplicate roller fingerprint %s vs %s" % [roller_fps[fp], str(rv.get("id"))])
		else:
			roller_fps[fp] = str(rv.get("id"))
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
		print("VehicleGarageTest PASS — 50 IDs, 15 playable (Street+Roller), 35 stubs, 6 items.")
		quit(0)
	else:
		print("VehicleGarageTest FAIL:")
		for f in failures:
			print(" - ", f)
		quit(1)
