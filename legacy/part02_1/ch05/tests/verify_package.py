#!/usr/bin/env python3
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tests"))
from package_check import check_package

check_package(Path(__file__).resolve().parent.parent)
