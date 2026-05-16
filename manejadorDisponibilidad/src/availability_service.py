from __future__ import annotations

import time
import requests


def is_recovery_time_valid(recovery_seconds: float, threshold_seconds: float = 5.0) -> bool:
    return recovery_seconds <= threshold_seconds


def measure_health_latency(url: str, timeout: float = 5.0) -> tuple[int, float]:
    start = time.perf_counter()
    response = requests.get(url, timeout=timeout)
    elapsed = time.perf_counter() - start
    return response.status_code, elapsed
