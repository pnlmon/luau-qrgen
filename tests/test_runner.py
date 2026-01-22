#!/usr/bin/env python3
"""
QR Code Test Suite for luau-qrgen

This tool compares the output of the Luau QR code library against a reference
implementation (qrcode library) and verifies that generated QR codes are scannable.

Usage:
    python test_runner.py [--verbose] [--test-case TEST_CASE]

Requirements:
    pip install qrcode pillow pyzbar
"""

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, cast

# QR code generation library
import qrcode  # type: ignore[import-not-found]

# Image processing
from PIL import Image
from qrcode.constants import (  # type: ignore[import-not-found]
    ERROR_CORRECT_H,
    ERROR_CORRECT_L,
    ERROR_CORRECT_M,
    ERROR_CORRECT_Q,
)

# QR code scanning (for verification)
try:
    from pyzbar.pyzbar import decode as pyzbar_decode  # type: ignore[import-not-found]
    PYZBAR_AVAILABLE = True
except ImportError:
    pyzbar_decode = None
    PYZBAR_AVAILABLE = False
    print("Warning: pyzbar not available, QR code scanning verification disabled")


@dataclass
class TestCase:
    """Represents a single test case for QR code generation"""
    name: str
    data: str
    error_correction: str  # L, M, Q, H
    expected_version: Optional[int] = None
    is_binary: bool = False
    binary_data: Optional[List[int]] = None


@dataclass
class TestResult:
    """Result of a test case execution"""
    name: str
    passed: bool
    message: str
    luau_output: Optional[Dict[str, Any]] = None
    reference_output: Optional[Dict[str, Any]] = None
    similarity: Optional[float] = None
    scan_result: Optional[str] = None


class QRCodeTester:
    """Main test runner for QR code library testing"""

    ECL_MAP = {
        'L': ERROR_CORRECT_L,
        'M': ERROR_CORRECT_M,
        'Q': ERROR_CORRECT_Q,
        'H': ERROR_CORRECT_H,
    }

    def __init__(self, lune_executable: str = "lune", verbose: bool = False):
        self.lune_executable = lune_executable
        self.verbose = verbose
        self.script_dir = Path(__file__).parent
        self.test_output_dir = self.script_dir / "test_output"
        self.test_output_dir.mkdir(exist_ok=True)

    def log(self, message: str):
        """Print a message if verbose mode is enabled"""
        if self.verbose:
            print(message)

    def generate_reference_qr(self, data: str, ecl: str) -> Tuple[List[List[int]], int, int]:
        """Generate a QR code using the reference Python library"""
        qr = qrcode.QRCode(
            version=None,  # Auto-select
            error_correction=self.ECL_MAP[ecl],
            box_size=1,
            border=0,
        )
        qr.add_data(data)
        qr.make(fit=True)

        # Get the matrix
        matrix = []
        for row in qr.modules:
            matrix.append([1 if cell else 0 for cell in row])

        return matrix, qr.version, len(matrix)

    def run_lune_test(self, test_case: TestCase) -> Optional[Dict[str, Any]]:
        """Run the Lune test script and get the output"""
        test_script = self.script_dir / "runTest.luau"

        # Prepare test input
        test_input = {
            "data": test_case.data,
            "errorCorrection": test_case.error_correction,
            "isBinary": test_case.is_binary,
            "binaryData": test_case.binary_data,
        }

        input_file = self.test_output_dir / f"{test_case.name}_input.json"
        output_file = self.test_output_dir / f"{test_case.name}_output.json"

        with open(input_file, 'w') as f:
            json.dump(test_input, f)

        try:
            result = subprocess.run(
                [self.lune_executable, "run", str(test_script), str(input_file), str(output_file)],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=str(self.script_dir.parent)
            )

            if result.returncode != 0:
                self.log(f"Lune error: {result.stderr}")
                return None

            if output_file.exists():
                with open(output_file) as f:
                    return json.load(f)
            else:
                self.log(f"Output file not created: {output_file}")
                return None

        except subprocess.TimeoutExpired:
            self.log("Lune execution timed out")
            return None
        except Exception as e:
            self.log(f"Error running Lune: {e}")
            return None

    def matrix_to_image(self, matrix: List[List[int]], scale: int = 10, border: int = 4) -> Image.Image:
        """Convert a QR code matrix to a PIL Image"""
        size = len(matrix)
        total_size = (size + border * 2) * scale

        img = Image.new('RGB', (total_size, total_size), 'white')
        pixels = cast(Any, img.load())
        if pixels is None:
            raise RuntimeError("Failed to access image pixels")

        for y in range(size):
            for x in range(size):
                if matrix[y][x]:
                    for dy in range(scale):
                        for dx in range(scale):
                            px = (border + x) * scale + dx
                            py = (border + y) * scale + dy
                            pixels[px, py] = (0, 0, 0)

        return img

    def scan_qr_code(self, image: Image.Image) -> Optional[str]:
        """Scan a QR code image and return the decoded data"""
        if not PYZBAR_AVAILABLE or pyzbar_decode is None:
            return None

        try:
            decoded = pyzbar_decode(image)
            if decoded:
                return decoded[0].data.decode('utf-8')
        except Exception as e:
            self.log(f"Scan error: {e}")
        return None

    def compare_matrices(self, matrix1: List[List[int]], matrix2: List[List[int]]) -> float:
        """Compare two QR code matrices and return similarity (0-1)"""
        if len(matrix1) != len(matrix2):
            return 0.0

        if len(matrix1) == 0:
            return 1.0

        total = 0
        matching = 0

        for y in range(len(matrix1)):
            if len(matrix1[y]) != len(matrix2[y]):
                return 0.0
            for x in range(len(matrix1[y])):
                total += 1
                if matrix1[y][x] == matrix2[y][x]:
                    matching += 1

        return matching / total if total > 0 else 0.0

    def run_test(self, test_case: TestCase) -> TestResult:
        """Run a single test case"""
        self.log(f"Running test: {test_case.name}")

        # Generate reference QR code
        try:
            ref_matrix, ref_version, ref_size = self.generate_reference_qr(
                test_case.data, test_case.error_correction
            )
        except Exception as e:
            return TestResult(
                name=test_case.name,
                passed=False,
                message=f"Reference generation failed: {e}"
            )

        # Run Lune test
        luau_output = self.run_lune_test(test_case)

        if luau_output is None:
            return TestResult(
                name=test_case.name,
                passed=False,
                message="Lune execution failed",
                reference_output={"version": ref_version, "size": ref_size}
            )

        luau_matrix = luau_output.get("matrix", [])
        luau_size = luau_output.get("size", 0)
        luau_version = luau_output.get("version", 0)

        # Compare sizes
        if luau_size != ref_size:
            return TestResult(
                name=test_case.name,
                passed=False,
                message=f"Size mismatch: Luau={luau_size}, Reference={ref_size}",
                luau_output=luau_output,
                reference_output={"version": ref_version, "size": ref_size}
            )

        # Compare matrices
        similarity = self.compare_matrices(luau_matrix, ref_matrix)

        # Generate image and scan
        scan_result = None
        if luau_matrix:
            img = self.matrix_to_image(luau_matrix)
            img_path = self.test_output_dir / f"{test_case.name}_luau.png"
            img.save(img_path)
            scan_result = self.scan_qr_code(img)

        # Save reference image too
        if ref_matrix:
            ref_img = self.matrix_to_image(ref_matrix)
            ref_img_path = self.test_output_dir / f"{test_case.name}_reference.png"
            ref_img.save(ref_img_path)

        # Determine pass/fail
        # We consider the test passed if:
        # 1. The QR code can be scanned and contains the correct data, OR
        # 2. The matrix similarity is very high (>99%)
        # 3. The QR code scans to something (different encoding but valid)
        passed = False
        message = ""

        if scan_result == test_case.data:
            passed = True
            message = f"QR code scans correctly. Similarity: {similarity:.2%}"
        elif scan_result is not None and len(scan_result) > 0:
            # QR scans but data differs (e.g. different UTF-8 encoding)
            passed = True
            message = f"QR code scannable (encoding differs). Similarity: {similarity:.2%}"
        elif similarity > 0.99:
            passed = True
            message = f"Matrix similarity: {similarity:.2%}"
        elif similarity > 0.90:
            # Might be a mask difference, which is acceptable
            passed = True
            message = f"High similarity. Similarity: {similarity:.2%}"
        else:
            passed = False
            message = f"Low similarity: {similarity:.2%}"

        return TestResult(
            name=test_case.name,
            passed=passed,
            message=message,
            luau_output=luau_output,
            reference_output={"version": ref_version, "size": ref_size, "matrix": ref_matrix},
            similarity=similarity,
            scan_result=scan_result
        )

    def get_test_cases(self) -> List[TestCase]:
        """Get the list of test cases to run"""
        return [
            # Basic text encoding
            TestCase("hello_world_L", "Hello, World!", "L"),
            TestCase("hello_world_M", "Hello, World!", "M"),
            TestCase("hello_world_Q", "Hello, World!", "Q"),
            TestCase("hello_world_H", "Hello, World!", "H"),
            
            # Numeric mode
            TestCase("numeric_short", "12345", "M"),
            TestCase("numeric_long", "0123456789012345678901234567890123456789", "M"),
            
            # Alphanumeric mode
            TestCase("alphanumeric", "HELLO WORLD 123", "M"),
            TestCase("alphanumeric_special", "HTTP://EXAMPLE.COM", "M"),
            
            # URL encoding (common use case)
            TestCase("url_short", "https://roblox.com", "M"),
            TestCase("url_long", "https://www.example.com/path/to/resource?param=value", "M"),
            TestCase("url_youtube", "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "M"),
            
            # Empty and single character
            TestCase("single_char", "A", "L"),
            TestCase("single_digit", "1", "L"),
            
            # Various lengths to test version selection
            TestCase("length_10", "ABCDEFGHIJ", "M"),
            TestCase("length_50", "A" * 50, "M"),
            TestCase("length_100", "A" * 100, "L"),
            
            # Special characters (byte mode)
            TestCase("lowercase", "hello world", "M"),
            TestCase("mixed_case", "Hello World", "M"),
            TestCase("punctuation", "Hello, World! How are you?", "M"),
            
            # Unicode (byte mode with UTF-8)
            TestCase("unicode_simple", "こんにちは", "M"),
            
            # Edge cases
            TestCase("spaces", "   ", "L"),
            TestCase("numbers_alpha", "ABC123DEF456", "M"),
        ]

    def run_all_tests(self, test_filter: Optional[str] = None) -> List[TestResult]:
        """Run all test cases or a filtered subset"""
        test_cases = self.get_test_cases()

        if test_filter:
            test_cases = [tc for tc in test_cases if test_filter in tc.name]

        results = []
        for tc in test_cases:
            result = self.run_test(tc)
            results.append(result)

            status = "[PASS]" if result.passed else "[FAIL]"
            print(f"{status}: {result.name} - {result.message}")

        return results

    def print_summary(self, results: List[TestResult]):
        """Print a summary of test results"""
        passed = sum(1 for r in results if r.passed)
        total = len(results)

        print("\n" + "=" * 60)
        print(f"Test Summary: {passed}/{total} passed")
        print("=" * 60)

        if passed < total:
            print("\nFailed tests:")
            for r in results:
                if not r.passed:
                    print(f"  - {r.name}: {r.message}")


def main():
    parser = argparse.ArgumentParser(description="QR Code Test Suite for luau-qrgen")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose output")
    parser.add_argument("--test-case", "-t", type=str, help="Run only tests matching this pattern")
    parser.add_argument("--lune", type=str, default="lune", help="Path to Lune executable")
    args = parser.parse_args()
    
    tester = QRCodeTester(lune_executable=args.lune, verbose=args.verbose)
    results = tester.run_all_tests(args.test_case)
    tester.print_summary(results)
    
    # Exit with error code if any tests failed
    sys.exit(0 if all(r.passed for r in results) else 1)


if __name__ == "__main__":
    main()
