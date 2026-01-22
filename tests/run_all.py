#!/usr/bin/env python3
"""
Run the full test suite for luau-qrgen.

This runs:
1) Luau unit tests (tests/testQrgen.luau)
2) Python verification tests (tests/test_runner.py)

Runs the test suite once and exits with the combined result.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent


def run_command(name: str, command: list[str]) -> bool:
    print(f"\n=== {name} ===")
    result = subprocess.run(command, cwd=str(ROOT_DIR))
    if result.returncode != 0:
        print(f"{name} failed with exit code {result.returncode}")
        return False
    return True


def run_all_once() -> bool:
    if not run_command("Luau tests", ["lune", "run", "tests/testQrgen.luau"]):
        return False
    if not run_command("Python tests", [sys.executable, "tests/test_runner.py"]):
        return False
    return True


def main() -> int:
    if run_all_once():
        print("\nAll tests passed.")
        return 0

    print("\nTests failed.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
