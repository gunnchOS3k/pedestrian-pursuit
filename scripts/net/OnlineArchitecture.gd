extends RefCounted
class_name OnlineArchitecture

## Digital RC online architecture scaffold (private/dev only — no public deploy claim).
## Mirrors the private-room pattern used elsewhere in the product spine.

const PROTOCOL_VERSION := 1
const SCOPE := "same_room_lan_v1"

static func describe() -> Dictionary:
	return {
		"schema": "pp_online_architecture/v1",
		"protocol_version": PROTOCOL_VERSION,
		"scope": SCOPE,
		"public_matchmaking": false,
		"modes": {
			"partylink_8p": {
				"host_authoritative": true,
				"max_player_seats": 8,
				"min_player_seats": 2,
				"spectator_capacity_separate": true,
				"max_spectator_seats": 32,
				"authority": "HOST_AUTHORITATIVE_PARTY",
				"public_relay": false,
				"race_director_view": true,
				"lan_join_route": true,
				"browser_controller": true,
				"input_sync": "semantic_sequence_v1",
				"note": "Same-room/LAN PartyLink V2; spectators never consume player seats.",
			},
			"private_room": {
				"host_authoritative": true,
				"guest_join": true,
				"spectator": "supported_separate_capacity",
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
			"no_client_forged_lap_finish",
		],
		"status": "lan_party_mode_implemented",
	}


static func write_evidence(abs_path: String) -> String:
	var text := JSON.stringify(describe(), "\t")
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return abs_path
