extends SceneTree

## PartyLink capacity 2–8: allocated seats vs connected humans vs CPU fill.
## Bots never count as humans. BeatLink sibling stays 2. Physical 8p / Metal false.

const OnlineArchitectureScript = preload("res://scripts/net/OnlineArchitecture.gd")
const TrackCatalogScript = preload("res://scripts/data/TrackCatalog.gd")
const CourseTrackScript = preload("res://scripts/tracks/CourseTrack.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	var desc: Dictionary = OnlineArchitectureScript.describe()
	var pl: Dictionary = desc.get("partylink", {})
	if int(pl.get("min_human_seats", 0)) != 2:
		failures.append("partylink min_human_seats != 2")
	if int(pl.get("max_human_seats", 0)) != 8:
		failures.append("partylink max_human_seats != 8")
	if int(pl.get("field_size", 0)) != 8:
		failures.append("partylink field_size != 8")
	if int(pl.get("beatlink_sibling_contract_humans", 0)) != 2:
		failures.append("BeatLink sibling contract humans must stay 2")
	if bool(pl.get("physical_eight_human_party", true)):
		failures.append("physical_eight_human_party must stay false")
	if not bool(pl.get("bots_never_count_as_humans", false)):
		failures.append("bots_never_count_as_humans required")

	## Allocated capacity map: never invents connected humans.
	for seats in range(2, 9):
		var seat_map: Dictionary = OnlineArchitectureScript.partylink_seat_map(seats)
		if int(seat_map.get("allocated_human_seats", 0)) != seats:
			failures.append("seat_map allocated %d != %d" % [int(seat_map.get("allocated_human_seats", 0)), seats])
		if int(seat_map.get("connected_humans", -1)) != 0:
			failures.append("capacity map must not invent connected humans")
		if int(seat_map.get("cpu_seats", -1)) != 8 - seats:
			failures.append("seat_map cpu_seats wrong for %d allocated" % seats)
		var claimed_humans := 0
		var allocated_flags := 0
		for entry in seat_map.get("seats", []):
			if typeof(entry) != TYPE_DICTIONARY:
				failures.append("bad seat entry")
				continue
			if bool(entry.get("counts_as_human_participant", false)):
				claimed_humans += 1
			if bool(entry.get("allocated_human_capacity", false)):
				allocated_flags += 1
		if claimed_humans != 0:
			failures.append("capacity map must not count allocated seats as connected humans")
		if allocated_flags != seats:
			failures.append("allocated_human_capacity flags %d != %d" % [allocated_flags, seats])

	## Runtime roster: connected ≤ allocated; CPU fills the rest; bots ≠ humans.
	for allocated in range(2, 9):
		for connected in range(0, allocated + 1):
			var roster: Dictionary = OnlineArchitectureScript.partylink_runtime_roster(allocated, connected)
			if int(roster.get("allocated_human_seats", -1)) != allocated:
				failures.append("roster allocated mismatch")
			if int(roster.get("connected_humans", -1)) != connected:
				failures.append("roster connected mismatch a=%d c=%d" % [allocated, connected])
			if int(roster.get("cpu_seats", -1)) != 8 - connected:
				failures.append("roster cpu_seats wrong a=%d c=%d" % [allocated, connected])
			if int(roster.get("human_participant_count", -1)) != connected:
				failures.append("human_participant_count mismatch a=%d c=%d" % [allocated, connected])
			if int(roster.get("bot_participant_count", -1)) != 8 - connected:
				failures.append("bot_participant_count mismatch a=%d c=%d" % [allocated, connected])
			if int(roster.get("field_sum_humans_plus_bots", -1)) != 8:
				failures.append("humans+bots must equal field 8")
			if bool(roster.get("bots_count_as_humans", true)):
				failures.append("bots_count_as_humans must stay false")
			if bool(roster.get("physical_eight_human_party", true)):
				failures.append("roster must keep physical_eight_human_party false")
			if bool(roster.get("COURSE_ACCEPTED", true)):
				failures.append("roster COURSE_ACCEPTED must stay false")
			var humans := 0
			var cpus := 0
			for entry in roster.get("seats", []):
				if bool(entry.get("counts_as_human_participant", false)):
					humans += 1
					if str(entry.get("owner", "")) != "human":
						failures.append("human participant owner mismatch")
					if str(entry.get("control", "")) != "human_input":
						failures.append("human control mismatch")
				else:
					cpus += 1
					if str(entry.get("owner", "")) != "cpu":
						failures.append("non-human seat must be cpu")
			if humans != connected:
				failures.append("counted humans %d != connected %d" % [humans, connected])
			if cpus != 8 - connected:
				failures.append("counted cpus wrong")
			## Explicit bots≠humans accounting helper.
			var acct: Dictionary = OnlineArchitectureScript.partylink_human_bot_accounting(allocated, connected)
			if int(acct.get("connected_humans", -1)) != connected:
				failures.append("accounting connected mismatch")
			if int(acct.get("bot_participant_count", -1)) != 8 - connected:
				failures.append("accounting bots mismatch")
			if int(acct.get("humans_plus_bots", -1)) != 8:
				failures.append("accounting humans+bots != 8")
			if bool(acct.get("bots_count_as_humans", true)) or not bool(acct.get("bots_never_count_as_humans", false)):
				failures.append("accounting must keep bots≠humans")
			## S7N: seat cosmetics bind trails without inventing humans.
			var fake_payloads: Array = []
			for hi in range(connected):
				fake_payloads.append({
					"fingerprint": "human_%d" % hi,
					"trail_expression_id": "metro_pulse_trail",
					"counts_as_human_participant": false,
				})
			var cos: Dictionary = OnlineArchitectureScript.partylink_seat_cosmetic_bindings(
				allocated, connected, fake_payloads
			)
			if int(cos.get("connected_humans", -1)) != connected:
				failures.append("cosmetic bindings must not change connected_humans")
			if int(cos.get("human_cosmetics_bound", -1)) != connected:
				failures.append("human_cosmetics_bound mismatch a=%d c=%d" % [allocated, connected])
			if not bool(cos.get("cosmetics_never_invent_humans", false)):
				failures.append("cosmetics_never_invent_humans required")
			for b in cos.get("cosmetic_bindings", []):
				if typeof(b) != TYPE_DICTIONARY:
					continue
				if bool(b.get("cosmetics_count_as_human", true)):
					failures.append("cosmetics_count_as_human must stay false")
			## S7O: sparse payloads never invent humans via cosmetics.
			var sparse: Array = []
			if connected > 0:
				sparse.append({
					"fingerprint": "only_one",
					"trail_expression_id": "metro_pulse_trail",
				})
			var gap: Dictionary = OnlineArchitectureScript.partylink_cosmetic_gap_integrity(
				allocated, connected, sparse
			)
			if int(gap.get("connected_humans", -1)) != connected:
				failures.append("gap integrity must not change connected_humans")
			if not bool(gap.get("cosmetics_never_invent_humans", false)):
				failures.append("gap integrity cosmetics_never_invent_humans required")
			if not bool(gap.get("gap_ok", false)):
				failures.append("gap_ok required for sparse payloads")
			if bool(gap.get("HUMAN", true)) or bool(gap.get("COURSE_ACCEPTED", true)):
				failures.append("gap integrity must keep HUMAN/COURSE false")
			## S7P: unique fingerprints across distinct human seats.
			var uniq_payloads: Array = []
			for ui in range(connected):
				uniq_payloads.append({
					"fingerprint": "human_fp_%d" % ui,
					"trail_expression_id": "metro_pulse_trail",
				})
			var uniq: Dictionary = OnlineArchitectureScript.partylink_seat_fingerprint_uniqueness(
				allocated, connected, uniq_payloads
			)
			if not bool(uniq.get("uniqueness_ok", false)):
				failures.append("seat fingerprint uniqueness_ok required")
			if int(uniq.get("duplicate_fingerprints", 1)) != 0:
				failures.append("duplicate_fingerprints must be 0")
			if bool(uniq.get("HUMAN", true)) or bool(uniq.get("RC2", true)) or bool(uniq.get("V1", true)):
				failures.append("fingerprint uniqueness must keep HUMAN/RC2/V1 false")
			## S7Q: empty payloads → bot cosmetics never count as humans.
			var bots: Dictionary = OnlineArchitectureScript.partylink_bot_cosmetics_never_humans(
				allocated, connected
			)
			if not bool(bots.get("bots_never_count_as_humans", false)):
				failures.append("bot cosmetics must never count as humans")
			if int(bots.get("bot_cosmetics_marked_human", 1)) != 0:
				failures.append("bot_cosmetics_marked_human must be 0")
			if bool(bots.get("HUMAN", true)) or bool(bots.get("RC2", true)) or bool(bots.get("V1", true)):
				failures.append("bot cosmetics helper must keep HUMAN/RC2/V1 false")
			## S7R: field sum humans+bots == 8; physical eight-human false.
			var field: Dictionary = OnlineArchitectureScript.partylink_field_sum_honesty(
				allocated, connected
			)
			if not bool(field.get("field_sum_ok", false)):
				failures.append("field_sum_ok required (humans+bots==8)")
			if bool(field.get("physical_eight_human_party", true)):
				failures.append("physical_eight_human_party must stay false")
			if bool(field.get("HUMAN", true)) or bool(field.get("RC2", true)) or bool(field.get("V1", true)):
				failures.append("field sum honesty must keep HUMAN/RC2/V1 false")

	## Clamp honesty: out-of-range requests still stay 2–8 allocated; connected clamps.
	## S7T allocated bounds honesty helper.
	var under: Dictionary = OnlineArchitectureScript.partylink_allocated_bounds_honesty(1)
	var over: Dictionary = OnlineArchitectureScript.partylink_allocated_bounds_honesty(99)
	if not bool(under.get("bounds_ok", false)) or int(under.get("allocated_human_seats", 0)) != 2:
		failures.append("allocated_bounds under-min must clamp to 2")
	if not bool(over.get("bounds_ok", false)) or int(over.get("allocated_human_seats", 0)) != 8:
		failures.append("allocated_bounds over-max must clamp to 8")
	if bool(under.get("physical_eight_human_party", true)) or bool(over.get("physical_eight_human_party", true)):
		failures.append("allocated_bounds must keep physical_eight_human_party false")
	if bool(under.get("HUMAN", true)) or bool(under.get("RC2", true)) or bool(under.get("V1", true)):
		failures.append("allocated_bounds must keep HUMAN/RC2/V1 false")
	if int(OnlineArchitectureScript.partylink_seat_map(1).get("allocated_human_seats", 0)) != 2:
		failures.append("under-min seats must clamp to 2")
	if int(OnlineArchitectureScript.partylink_seat_map(99).get("allocated_human_seats", 0)) != 8:
		failures.append("over-max seats must clamp to 8")
	if int(OnlineArchitectureScript.partylink_runtime_roster(8, 99).get("connected_humans", -1)) != 8:
		failures.append("connected must clamp to allocated max")
	if int(OnlineArchitectureScript.partylink_runtime_roster(4, 8).get("connected_humans", -1)) != 4:
		failures.append("connected must not exceed allocated")

	var gm = preload("res://scripts/core/GameManager.gd").new()
	root.add_child(gm)
	## Allocated 8, connected 1 local — honest single-device PartyLink field.
	gm.start_party_link("lantern_corridor", 8, 1)
	if not gm.is_party_link():
		failures.append("start_party_link did not activate")
	if int(gm.party_link_human_seats) != 8:
		failures.append("party_link_human_seats not 8")
	if int(gm.party_link_connected_humans) != 1:
		failures.append("party_link_connected_humans must stay 1 (do not invent humans)")
	if int(gm.ai_field_size) != 7:
		failures.append("party_link field should be player + 7 AI = 8")
	if not gm.has_meta("party_link_seat_map"):
		failures.append("missing party_link_seat_map meta")
	if not gm.has_meta("party_link_runtime_roster"):
		failures.append("missing party_link_runtime_roster meta")
	else:
		var live: Dictionary = gm.get_meta("party_link_runtime_roster")
		if int(live.get("connected_humans", -1)) != 1:
			failures.append("runtime roster connected_humans != 1")
		if int(live.get("cpu_seats", -1)) != 7:
			failures.append("runtime roster cpu_seats != 7")

	## BeatLink-sibling dual connected (2h+6cpu) — still bots≠humans, not physical 8p.
	gm.start_party_link("lantern_corridor", 8, 2)
	if int(gm.party_link_connected_humans) != 2:
		failures.append("dual connected_humans must be 2")
	if int(gm.ai_field_size) != 6:
		failures.append("dual field should be player + local P2 + 6 AI = 8")
	if int(gm.get_meta("party_link_local_extra_humans")) != 1:
		failures.append("party_link_local_extra_humans must be 1 for connected=2")
	var dual: Dictionary = gm.get_meta("party_link_runtime_roster")
	if int(dual.get("connected_humans", -1)) != 2:
		failures.append("dual roster connected_humans != 2")
	if int(dual.get("cpu_seats", -1)) != 6:
		failures.append("dual roster cpu_seats != 6")
	## Cap: requested 8 must NOT invent 8 wired humans — field stays sibling-2 (2h+6cpu).
	gm.start_party_link("lantern_corridor", 8, 8)
	if int(gm.get_meta("party_link_requested_connected_humans")) != 8:
		failures.append("requested_connected_humans must record lobby intent=8")
	if int(gm.party_link_connected_humans) != 2:
		failures.append("wired party_link_connected_humans must stay BeatLink-sibling 2 (do not invent humans)")
	if int(gm.get_meta("party_link_wired_connected_humans")) != 2:
		failures.append("wired_connected_humans meta must be 2")
	if int(gm.get_meta("party_link_local_extra_humans")) != 1:
		failures.append("local extra humans must stay BeatLink-sibling capped at 1")
	if int(gm.ai_field_size) != 6:
		failures.append("local field wiring stays sibling-2 even if allocated/connected ask for 8")
	var capped: Dictionary = gm.get_meta("party_link_runtime_roster")
	if int(capped.get("connected_humans", -1)) != 2:
		failures.append("runtime roster must stamp only wired humans (=2), not requested 8")
	if int(capped.get("cpu_seats", -1)) != 6:
		failures.append("capped roster cpu_seats != 6")
	if int(capped.get("unwired_requested_humans", -1)) != 6:
		failures.append("unwired_requested_humans should be 6 (8 requested − 2 wired)")

	## Course still builds under PartyLink track pick (Neon Night candidate).
	var data := TrackCatalogScript.load_track("lantern_corridor")
	var course: Node = CourseTrackScript.new()
	root.add_child(course)
	course.configure(data)
	if not course.build():
		failures.append("lantern_corridor failed to build under PartyLink probe")
	elif course.get_node_or_null("NeonFill") == null:
		failures.append("PartyLink probe missing NeonFill")
	course.queue_free()

	if failures.is_empty():
		print(
			"PartyLinkCapacityTest PASS — allocated 2..8 · connected honest · field 8 · BeatLink sibling 2 · bots≠humans · physical 8p false"
		)
		quit(0)
		return
	print("PartyLinkCapacityTest FAIL:")
	for f in failures:
		print(" - ", f)
	quit(1)
