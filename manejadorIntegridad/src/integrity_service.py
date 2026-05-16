from __future__ import annotations

from interfaces.hashing import stable_sha256


def compute_payload_hash(payload: dict) -> str:
    return stable_sha256(payload)


def is_payload_unchanged(original_payload: dict, candidate_payload: dict) -> bool:
    return compute_payload_hash(original_payload) == compute_payload_hash(candidate_payload)
