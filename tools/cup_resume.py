"""Cup save/resume index. A recorded finish continues at the saved race."""


def plan_saved_cup(
    round_index: int,
    result_count: int,
    track_count: int,
    standings: dict,
    resume_index: int | None = None,
    completed: bool = False,
    cup_id: str = "",
) -> dict:
    next_index = round_index + 1 if result_count > round_index else round_index
    if resume_index is not None:
        next_index = int(resume_index)
    finished = bool(completed) or (track_count > 0 and next_index >= track_count)
    resumable = (
        not finished
        and bool(cup_id)
        and track_count > 0
        and 0 <= next_index < track_count
    )
    return {
        "resumable": resumable,
        "round_index": next_index,
        "course_number": next_index + 1,
        "standing": dict(standings),
        "finished": finished,
    }
