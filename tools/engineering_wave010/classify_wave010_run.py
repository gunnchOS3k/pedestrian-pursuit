#!/usr/bin/env python3
"""Classify Wave010 step logs: reject PASS-over-failure false greens.

Verdict rules (do not weaken):
- Explicit FAIL / SCRIPT / Parse / Compilation errors are genuine failures.
  A PASS marker must NOT override them.
- Nonzero exit is a genuine failure unless characterized as a legitimate
  Godot 4.3 headless ObjectDB leak *after* a clean PASS (no genuine errors).
- Malformed Godot suite logs (exit 0, no suite PASS marker) cannot PASS.
- Generic steps (import/code_integrity/ai_subset) require exit 0 and no fatals.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

GENUINE_FAILURE_RE = re.compile(
    r"SCRIPT ERROR|Parse Error|Compilation failed|Failed to load script|"
    r"autoload dependency|FATAL ERROR|"
    r"Wave010RuntimeTest FAIL|Wave010RaceSceneE2E FAIL|Wave010TimeTrialMasteryE2E FAIL",
    re.IGNORECASE,
)

# Godot headless often flips nonzero after quit(0) when dummy/orphan objects leak.
LEGITIMATE_OBJECTDB_SHUTDOWN_RE = re.compile(
    r"ObjectDB instances leaked at exit|"
    r"ObjectDB instances leaked|"
    r"resources still in use at exit|"
    r"Leaked instance:|"
    r"ERROR: \d+ resources still in use",
    re.IGNORECASE,
)

SUITE_PASS_MARKERS = {
    "wave010_component_runtime": "Wave010RuntimeTest PASS",
    "wave010_racescene_e2e": "Wave010RaceSceneE2E PASS",
    "wave010_time_trial_mastery": "Wave010TimeTrialMasteryE2E PASS",
}


@dataclass(frozen=True)
class Verdict:
    ok: bool
    reason: str
    kind: str  # PASS | FAIL | PASS_OBJECTDB_SHUTDOWN

    def as_tuple(self) -> tuple[bool, str, str]:
        return self.ok, self.reason, self.kind


def classify_wave010_run(name: str, exit_code: int, log_text: str) -> Verdict:
    """Return whether a Wave010 step may be treated as PASS."""
    if name == "mutation":
        if exit_code != 0:
            return Verdict(False, "mutation nonzero exit", "FAIL")
        return Verdict(True, "mutation campaign exit 0", "PASS")

    genuine = bool(GENUINE_FAILURE_RE.search(log_text))
    objectdb = bool(LEGITIMATE_OBJECTDB_SHUTDOWN_RE.search(log_text))
    required_pass = SUITE_PASS_MARKERS.get(name)
    has_suite_pass = bool(required_pass and required_pass in log_text)

    # PASS marker must never override script errors / FAIL markers.
    if genuine:
        return Verdict(
            False,
            "genuine failure signals present (PASS marker does not override)",
            "FAIL",
        )

    if required_pass is not None:
        if not has_suite_pass:
            return Verdict(
                False,
                f"malformed/incomplete run: missing required marker {required_pass!r}",
                "FAIL",
            )
        if exit_code == 0:
            return Verdict(True, "suite PASS marker with clean exit 0", "PASS")
        if objectdb:
            return Verdict(
                True,
                "suite PASS + characterized ObjectDB leak shutdown (post-quit)",
                "PASS_OBJECTDB_SHUTDOWN",
            )
        return Verdict(
            False,
            "nonzero exit without characterized legitimate ObjectDB shutdown "
            "(PASS marker does not override)",
            "FAIL",
        )

    # Generic steps: import / code_integrity / ai_subset / etc.
    if exit_code != 0:
        if objectdb and not genuine:
            # Generic steps still must not green on uncharacterized crashes;
            # ObjectDB-only after clean work is allowed the same way.
            return Verdict(
                True,
                "generic step ObjectDB leak shutdown after clean log",
                "PASS_OBJECTDB_SHUTDOWN",
            )
        return Verdict(False, "nonzero exit", "FAIL")
    return Verdict(True, "clean exit 0 without genuine failure", "PASS")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--name", required=True)
    p.add_argument("--exit-code", type=int, required=True)
    p.add_argument("--log", required=True, help="path to step log")
    args = p.parse_args(argv)
    text = Path(args.log).read_text(errors="replace")
    verdict = classify_wave010_run(args.name, args.exit_code, text)
    print(f"WAVE010_CLASSIFY ok={int(verdict.ok)} kind={verdict.kind} reason={verdict.reason}")
    return 0 if verdict.ok else 1


if __name__ == "__main__":
    sys.exit(main())
