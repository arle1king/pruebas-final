import os
import sys
from pathlib import Path

import pytest


ROOT_DIR = Path(__file__).resolve().parent
SRC_DIRS = [
    ROOT_DIR / "manejadorDisponibilidad" / "src",
    ROOT_DIR / "manejadorConfidencialidad" / "src",
    ROOT_DIR / "manejadorIntegridad" / "src",
]

for src in SRC_DIRS:
    src_str = str(src)
    if src.exists() and src_str not in sys.path:
        sys.path.insert(0, src_str)


def pytest_addoption(parser):
    parser.addoption(
        "--run-aws",
        action="store_true",
        default=False,
        help="Ejecuta pruebas integration (AWS/HTTP real)",
    )


def pytest_collection_modifyitems(config, items):
    run_aws = config.getoption("--run-aws") or os.getenv("RUN_AWS_INTEGRATION") == "1"
    if run_aws:
        return

    skip_marker = pytest.mark.skip(
        reason="Pruebas integration deshabilitadas. Usa --run-aws o RUN_AWS_INTEGRATION=1"
    )
    for item in items:
        if "integration" in item.keywords:
            item.add_marker(skip_marker)
