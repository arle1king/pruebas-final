from __future__ import annotations

from dataclasses import dataclass


@dataclass
class AccessContext:
    requester_tenant: str
    resource_tenant: str


def is_cross_tenant_access_blocked(context: AccessContext) -> bool:
    return context.requester_tenant != context.resource_tenant


def is_suspicious_payload(payload: str) -> bool:
    lowered = payload.lower()
    signatures = [" or ", "union select", "drop table", "--"]
    return any(signature in lowered for signature in signatures)
