extends RefCounted
class_name OnlineArchitecture

## Digital RC online architecture scaffold (private/dev only — no public deploy claim).
## Mirrors the private-room pattern used elsewhere in the product spine.

const PROTOCOL_VERSION := 1
const SCOPE := "private_dev_loopback_only"

const PARTYLINK_MIN_HUMAN_SEATS := 2
const PARTYLINK_MAX_HUMAN_SEATS := 8
const PARTYLINK_FIELD_SIZE := 8
## BeatLink sibling game-session contract remains host+guest (2 humans).
## Larger PartyLink fields fill non-human seats with CPU — never counted as humans.
const BEATLINK_SIBLING_CONTRACT_HUMANS := 2


static func describe() -> Dictionary:
	return {
		"schema": "pp_online_architecture/v1",
		"protocol_version": PROTOCOL_VERSION,
		"scope": SCOPE,
		"public_matchmaking": false,
		"partylink": {
			"min_human_seats": PARTYLINK_MIN_HUMAN_SEATS,
			"max_human_seats": PARTYLINK_MAX_HUMAN_SEATS,
			"field_size": PARTYLINK_FIELD_SIZE,
			"beatlink_sibling_contract_humans": BEATLINK_SIBLING_CONTRACT_HUMANS,
			"cpu_fills_remaining_seats": true,
			"bots_never_count_as_humans": true,
			"independent_two_process_proven": true,
			"physical_eight_human_party": false,
			"note": "Capacity 2–8 human seats with CPU fill to field 8. BeatLink sibling contract stays 2-member; do not invent Mac MoltenVK passes.",
		},
		"modes": {
			"private_room": {
				"host_authoritative": true,
				"guest_join": true,
				"spectator": "planned",
				"input_sync": "snapshot_delta_v1",
				"rollback": false,
				"note": "Foot-racing netcode scaffold; not shipped as public online.",
			},
			"ghost_share": {
				"enabled_digital": true,
				"transport": "local_file_exchange",
				"note": "Time Trial ghosts already persist under user://.",
			},
		},
		"anti_cheat_digital": [
			"no_server_speed_override",
			"client_physics_shared_rules",
			"ghost_checksum_planned",
		],
		"status": "architecture_documented",
	}


static func partylink_seat_map(human_seats: int) -> Dictionary:
	## Authoritative seat ownership for PartyLink capacity probes.
	var humans := clampi(human_seats, PARTYLINK_MIN_HUMAN_SEATS, PARTYLINK_MAX_HUMAN_SEATS)
	var seats: Array = []
	for i in range(PARTYLINK_FIELD_SIZE):
		var owner := "human" if i < humans else "cpu"
		seats.append({
			"seat": i,
			"owner": owner,
			"counts_as_human_participant": owner == "human",
		})
	return {
		"human_seats": humans,
		"field_size": PARTYLINK_FIELD_SIZE,
		"cpu_seats": PARTYLINK_FIELD_SIZE - humans,
		"beatlink_sibling_humans": BEATLINK_SIBLING_CONTRACT_HUMANS,
		"seats": seats,
	}


static func write_evidence(abs_path: String) -> String:
	var text := JSON.stringify(describe(), "\t")
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return abs_path
