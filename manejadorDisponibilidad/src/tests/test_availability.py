import os
import pytest

from availability_service import is_recovery_time_valid, measure_health_latency
from interfaces.aws_clients import build_aws_client


@pytest.mark.unit
def test_recovery_time_rule():
    assert is_recovery_time_valid(4.9) is True
    assert is_recovery_time_valid(5.1) is False


@pytest.mark.integration
def test_health_endpoint_response_time():
    health_url = os.getenv("HEALTH_ENDPOINT_URL")
    if not health_url:
        pytest.skip("Define HEALTH_ENDPOINT_URL para ejecutar integration")

    status_code, elapsed = measure_health_latency(health_url)
    assert status_code == 200
    assert elapsed < 1.0


@pytest.mark.integration
def test_aws_target_groups_exist():
    elb = build_aws_client("elbv2")
    payload = elb.describe_target_groups()
    assert len(payload["TargetGroups"]) > 0
