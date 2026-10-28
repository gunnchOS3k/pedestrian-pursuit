extends SceneTree

## Headless: 50-vehicle registry, Street through Crossover playable, Anime stubs, six items intact.

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
	if playable.size() != 41:
		failures.append("playable size %d != 41" % playable.size())
	var stubs := VehicleCatalogScript.stub_ids()
	if stubs.size() != 9:
		failures.append("stub size %d != 9" % stubs.size())
	var family_expect := {
		"street_legends": 8,
		"roller_revolution": 7,
		"hover_couture": 7,
		"elemental_amphibious": 6,
		"beautifully_ridiculous": 6,
		"gunnchos_crossover": 7,
	}
	for family_id in family_expect.keys():
		var family := VehicleCatalogScript.vehicles_in_family(family_id)
		var expect: int = int(family_expect[family_id])
		if family.size() != expect:
			failures.append("%s size %d != %d" % [family_id, family.size(), expect])
		for entry in family:
			if not bool(entry.get("playable", false)):
				failures.append("%s not playable: %s" % [family_id, str(entry.get("id", ""))])
			if str(entry.get("art_status", "")) != "native_v1":
				failures.append("%s art not native_v1: %s" % [family_id, str(entry.get("id", ""))])
	## Anime Aggressors footwear must remain truthful stubs (no unlock this batch).
	var anime := VehicleCatalogScript.vehicles_in_family("anime_aggressors")
	if anime.size() != 9:
		failures.append("anime_aggressors size %d != 9" % anime.size())
	for entry in anime:
		if bool(entry.get("playable", false)):
			failures.append("anime must stay stubbed: %s" % str(entry.get("id", "")))
		if str(entry.get("art_status", "")) != "stub_not_final":
			failures.append("anime art flag wrong: %s" % str(entry.get("id", "")))
	## Themed soles must keep grounded collision contracts + distinct fingerprints.
	for family_id in ["hover_couture", "elemental_amphibious", "beautifully_ridiculous", "gunnchos_crossover"]:
		var themed := VehicleCatalogScript.vehicles_in_family(family_id)
		var fps: Dictionary = {}
		for hv in themed:
			var contract := str(hv.get("collision_contract", "")).to_lower()
			if "grounded" not in contract and "checkpoint" not in contract:
				failures.append("%s missing grounded collision contract: %s" % [family_id, str(hv.get("id"))])
			if "skip" in contract and "never" not in contract:
				failures.append("%s contract must forbid skipping: %s" % [family_id, str(hv.get("id"))])
			var fp := "%s|%s|%s|%s|%s|%s|%s|%s" % [
				str(hv.get("top_speed_modifier")),
				str(hv.get("acceleration_modifier")),
				str(hv.get("handling_modifier")),
				str(hv.get("drift_modifier")),
				str(hv.get("jump_modifier")),
				str(hv.get("boost_modifier")),
				str(hv.get("stomp_modifier")),
				str(hv.get("material_family")),
			]
			if fps.has(fp):
				failures.append("duplicate %s fingerprint %s vs %s" % [family_id, fps[fp], str(hv.get("id"))])
			else:
				fps[fp] = str(hv.get("id"))
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
	if race_ids.size() != 41:
		failures.append("race_selectable_ids %d != 41" % race_ids.size())
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
		print("VehicleGarageTest PASS — 50 IDs, 41 playable (Street through Crossover), 9 Anime stubs, 6 items.")
		quit(0)
	else:
		print("VehicleGarageTest FAIL:")
		for f in failures:
			print(" - ", f)
		quit(1)
