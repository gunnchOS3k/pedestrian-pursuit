"""Cloudstep Ridge finish transition.

A fall returns the last accepted checkpoint, or the start line before the
first gate. It does not take a nearest-path point and it does not count a
lap. Results open only after every checkpoint has been crossed in order
enough times to finish the course's lap count.
"""

from __future__ import annotations

from race_line_launch import LapGate

CLOUDSTEP_TRACK_ID = "cloudstep_ridge"


def choose_respawn(has_accepted_checkpoint: bool, accepted: object, start: object) -> object:
    if has_accepted_checkpoint:
        return accepted
    return start


class CloudstepFinish:
    def __init__(self, checkpoint_count: int, total_laps: int) -> None:
        self.gate = LapGate(checkpoint_count)
        self.total_laps = total_laps
        self.results_visible = False
        self.state = "racing"
        self.accepted_checkpoint: int | None = None

    def cross(self, index: int) -> bool:
        if index != self.gate.next_checkpoint:
            return False
        self.accepted_checkpoint = index
        self.gate.on_checkpoint(index)
        if self.gate.lap >= self.total_laps:
            self.state = "finished"
            self.results_visible = True
        return True

    def fall(self) -> int | None:
        """Respawn index. None means the start line. Does not open results."""
        return self.accepted_checkpoint
