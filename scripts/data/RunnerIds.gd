class_name RunnerIds
extends RefCounted

## Authoritative selectable-roster IDs.
## CORE remains the original eight. GUEST is additive. Do not weaken core validation.

const CORE_RUNNER_IDS: Array[String] = [
	"dash_reed",
	"nova_quill",
	"sierra_flux",
	"mira_lane",
	"bolt_harbor",
	"zig_riven",
	"solen_pike",
	"kai_volt",
]

const GUEST_RUNNER_IDS: Array[String] = [
	"ember_vale",
	"rook_ironside",
	"juno_spark",
	"kaia_windrow",
	"nix_calder",
	"orion_vell",
	"vesper_nyx",
]

const DEV_REVIEW_LABEL := "Guest Runner — AA CC0 Candidate Derivative"
const PROVENANCE_LABEL := "AA_CC0_CANDIDATE_DERIVATIVE"


static func all_selectable_ids() -> Array[String]:
	var out: Array[String] = []
	out.append_array(CORE_RUNNER_IDS)
	out.append_array(GUEST_RUNNER_IDS)
	return out


static func is_core(runner_id: String) -> bool:
	return runner_id in CORE_RUNNER_IDS


static func is_guest(runner_id: String) -> bool:
	return runner_id in GUEST_RUNNER_IDS


static func core_count() -> int:
	return CORE_RUNNER_IDS.size()


static func guest_count() -> int:
	return GUEST_RUNNER_IDS.size()


static func selectable_count() -> int:
	return CORE_RUNNER_IDS.size() + GUEST_RUNNER_IDS.size()


static func ids_are_unique() -> bool:
	var seen := {}
	for rid in all_selectable_ids():
		if seen.has(rid):
			return false
		seen[rid] = true
	return seen.size() == selectable_count()
