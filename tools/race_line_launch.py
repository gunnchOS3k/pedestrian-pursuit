"""Bounce aim and lap order shared by the course builder.

A misaligned hop keeps the speed already earned and aims it along the next
path segment. Crossing the pad does not count a lap. Checkpoint order still
matches LapManager: index 0 increments the lap only after every earlier gate,
including checkpoint 4 on the launch courses.
"""

from __future__ import annotations

import math
from typing import Iterable, Sequence

ALIGN_DOT = 0.9
MIN_CARRIED_SPEED = 1.0

# Headless runs finished none of these. Tideglass Harbor is not in this list.
FAILED_LAUNCH_COURSES: tuple[str, ...] = (
    "verdant_cascade_circuit",
    "cloverwind_ranch",
    "prism_apex",
    "emberkeep_gauntlet",
    "neon_switchyard",
    "cloudstep_ridge",
    "mirage_mesa",
)


def _xz(point: Sequence[float]) -> tuple[float, float]:
    return float(point[0]), float(point[2])


def segment_forward(points: Sequence[Sequence[float]], index: int) -> tuple[float, float]:
    """Unit XZ direction from this path point toward the next one."""
    count = len(points)
    current = _xz(points[index % count])
    nxt = _xz(points[(index + 1) % count])
    dx = nxt[0] - current[0]
    dz = nxt[1] - current[1]
    length = math.hypot(dx, dz)
    if length < 1e-6:
        raise ValueError("degenerate segment at %s" % index)
    return (dx / length, dz / length)


def incoming_forward(points: Sequence[Sequence[float]], index: int) -> tuple[float, float]:
    """Unit XZ direction of the segment that arrives at this path point."""
    count = len(points)
    return segment_forward(points, (index - 1) % count)


def redirect_horizontal(
    facing: tuple[float, float],
    velocity: tuple[float, float],
    line_forward: tuple[float, float],
    forward_kick: float,
    align_dot: float = ALIGN_DOT,
) -> tuple[tuple[float, float], bool]:
    """Return horizontal velocity and whether the hop was aimed down the line.

    Facing and line_forward are unit XZ vectors. The body is not moved.
    """
    carried = math.hypot(velocity[0], velocity[1])
    alignment = facing[0] * line_forward[0] + facing[1] * line_forward[1]
    if alignment < align_dot and carried > MIN_CARRIED_SPEED:
        speed = carried + forward_kick
        return (line_forward[0] * speed, line_forward[1] * speed), True
    return (
        velocity[0] + facing[0] * forward_kick,
        velocity[1] + facing[1] * forward_kick,
    ), False


class LapGate:
    """Same ordered checkpoint rule as scripts/race/LapManager.gd."""

    def __init__(self, checkpoint_count: int) -> None:
        self.checkpoint_count = checkpoint_count
        self.next_checkpoint = 1 if checkpoint_count > 1 else 0
        self.lap = 0

    def on_checkpoint(self, index: int) -> None:
        if index != self.next_checkpoint:
            return
        if index == 0:
            self.next_checkpoint = 1 if self.checkpoint_count > 1 else 0
            self.lap += 1
            return
        self.next_checkpoint = index + 1
        if self.next_checkpoint >= self.checkpoint_count:
            self.next_checkpoint = 0


def lap_without_checkpoint(checkpoint_count: int, skipped: int) -> LapGate:
    """Cross every gate except `skipped`, including a premature lap line."""
    gate = LapGate(checkpoint_count)
    for index in range(checkpoint_count):
        if index == skipped:
            continue
        gate.on_checkpoint(index)
    return gate


def ordered_lap(checkpoint_count: int) -> LapGate:
    gate = LapGate(checkpoint_count)
    indices: Iterable[int] = list(range(1, checkpoint_count)) + [0]
    for index in indices:
        gate.on_checkpoint(index)
    return gate
