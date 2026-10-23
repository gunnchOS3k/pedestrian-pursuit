extends RefCounted

## Void respawn choice. Not a new checkpoint system: the racer already stores
## the last accepted gate via set_recovery_transform, and the start line via
## setup_for_race. Nearest-path snaps are not a respawn.


static func choose(
	has_accepted_checkpoint: bool,
	accepted_checkpoint: Transform3D,
	start_fallback: Transform3D
) -> Transform3D:
	if has_accepted_checkpoint:
		return accepted_checkpoint
	return start_fallback
