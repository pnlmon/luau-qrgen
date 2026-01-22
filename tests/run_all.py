#!/usr/bin/env python3
"""
Run the full test suite for luau-qrgen.

This runs:
1) Luau unit tests (tests/testQrgen.luau)
2) Python verification tests (tests/test_runner.py)

By default, it retries forever until all tests pass.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
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
    parser = argparse.ArgumentParser(description="Run all tests")
    parser.add_argument(
        "--max-attempts",
        type=int,
        default=0,
        help="Max attempts before failing (0 = retry forever)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=2.0,
        help="Seconds to wait between attempts",
    )
    args = parser.parse_args()

    attempt = 0
    while True:
        attempt += 1
        print(f"\nAttempt {attempt}")

        if run_all_once():
            print("\nAll tests passed.")
            return 0

        if args.max_attempts > 0 and attempt >= args.max_attempts:
            print("\nTests failed after max attempts.")
            return 1

        if args.delay > 0:
            time.sleep(args.delay)


if __name__ == "__main__":
    raise SystemExit(main())
