import pytest

from confidentiality_service import (
    AccessContext,
    is_cross_tenant_access_blocked,
    is_suspicious_payload,
)
from interfaces.aws_clients import build_aws_client


@pytest.mark.unit
def test_cross_tenant_is_blocked():
    context = AccessContext(requester_tenant="empresa_a", resource_tenant="empresa_b")
    assert is_cross_tenant_access_blocked(context) is True


@pytest.mark.unit
def test_same_tenant_not_blocked():
    context = AccessContext(requester_tenant="empresa_a", resource_tenant="empresa_a")
    assert is_cross_tenant_access_blocked(context) is False


@pytest.mark.unit
def test_sqli_detection():
    assert is_suspicious_payload("' OR '1'='1") is True
    assert is_suspicious_payload("consulta normal") is False


@pytest.mark.integration
def test_waf_acl_list_call():
    waf = build_aws_client("wafv2")
    payload = waf.list_web_acls(Scope="REGIONAL")
    assert "WebACLs" in payload
