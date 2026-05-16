import pytest

from integrity_service import compute_payload_hash, is_payload_unchanged
from interfaces.aws_clients import build_aws_client


@pytest.mark.unit
def test_hash_changes_on_modification():
    original = {"id": "RPT-001", "total": 1500.5}
    modified = {"id": "RPT-001", "total": 5000.0}
    assert compute_payload_hash(original) != compute_payload_hash(modified)


@pytest.mark.unit
def test_modified_payload_is_rejected():
    original = {"id": "RPT-001", "total": 1500.5}
    modified = {"id": "RPT-001", "total": 1500.51}
    assert is_payload_unchanged(original, modified) is False


@pytest.mark.integration
def test_dynamodb_list_tables_call():
    dynamodb = build_aws_client("dynamodb")
    payload = dynamodb.list_tables()
    assert "TableNames" in payload
