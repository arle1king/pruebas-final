from __future__ import annotations

import boto3


def build_aws_client(service_name: str, region: str = "us-east-1"):
    return boto3.client(service_name, region_name=region)
