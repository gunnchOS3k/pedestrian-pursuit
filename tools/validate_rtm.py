#!/usr/bin/env python3
"""Validate Pedestrian Pursuit RTM against vendored GUNNCHOS3K_PVS schema."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RTM_PATH = ROOT / "artifacts/quality_review/REQUIREMENTS_TO_EVIDENCE_MATRIX.json"
SCHEMA_PATH = ROOT / "contracts/quality/requirements_to_evidence_matrix.schema.json"
CONTRACT_PATH = ROOT / "contracts/quality/PRODUCT_VERIFICATION_STANDARD.v1.json"
PINNED_SOURCE_SHA = "45b456617002569c33a5a27fe30d5cf8be5a7032"


def main() -> int:
    if not RTM_PATH.is_file():
        print(f"RTM_MISSING {RTM_PATH}")
        return 1
    if not SCHEMA_PATH.is_file():
        print(f"SCHEMA_MISSING {SCHEMA_PATH}")
        return 1

    rtm = json.loads(RTM_PATH.read_text(encoding="utf-8"))
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))

    try:
        from jsonschema import Draft202012Validator
    except ImportError:
        print("JSONSCHEMA_MISSING: pip install 'jsonschema>=4.20'")
        return 1

    Draft202012Validator(schema).validate(rtm)

    if rtm.get("contract_id") != "GUNNCHOS3K_PVS":
        print("CONTRACT_ID_FAIL", rtm.get("contract_id"))
        return 1
    if rtm.get("contract_version") != "1.0.0":
        print("CONTRACT_VERSION_FAIL", rtm.get("contract_version"))
        return 1
    if rtm.get("contract_source_sha") != PINNED_SOURCE_SHA:
        print(
            "CONTRACT_SOURCE_SHA_FAIL expected",
            PINNED_SOURCE_SHA,
            "got",
            rtm.get("contract_source_sha"),
        )
        return 1
    if rtm.get("product_id") != "pedestrian-pursuit":
        print("PRODUCT_ID_FAIL", rtm.get("product_id"))
        return 1

    honesty = rtm.get("honesty_flags") or {}
    for key in ("HUMAN", "RC2", "V1"):
        if honesty.get(key) is not False:
            print(f"HONESTY_FLAG_FAIL {key} must be false, got {honesty.get(key)}")
            return 1

    for row in rtm.get("rows") or []:
        if row.get("independent_review_status") != "not_started":
            print(
                "INDEPENDENT_REVIEW_FAIL",
                row.get("req_id"),
                row.get("independent_review_status"),
            )
            return 1

    if CONTRACT_PATH.is_file():
        contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
        if contract.get("contract_id") != "GUNNCHOS3K_PVS" or contract.get("version") != "1.0.0":
            print("VENDORED_CONTRACT_MISMATCH", contract.get("contract_id"), contract.get("version"))
            return 1

    print(
        "RTM_PVS_OK",
        f"GUNNCHOS3K_PVS@{rtm['contract_version']}",
        f"source={rtm['contract_source_sha'][:12]}",
        f"rows={len(rtm.get('rows') or [])}",
        "independent_review=not_started",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
