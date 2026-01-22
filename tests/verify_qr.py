#!/usr/bin/env python3
"""
Standalone QR Code Verification Tool

This tool can:
1. Generate QR codes from text and save as images
2. Verify QR codes by scanning them
3. Convert matrix data (from Luau output) to images

Usage:
    # Generate QR code
    python verify_qr.py generate "Hello World" --output hello.png
    
    # Verify an image
    python verify_qr.py scan image.png
    
    # Convert matrix JSON to image
    python verify_qr.py convert matrix.json --output qr.png
    
    # Compare Luau output with reference
    python verify_qr.py compare "Hello World" --matrix matrix.json
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any, List, Optional, cast

import qrcode  # type: ignore[import-not-found]
from PIL import Image
from qrcode.constants import (  # type: ignore[import-not-found]
    ERROR_CORRECT_H,
    ERROR_CORRECT_L,
    ERROR_CORRECT_M,
    ERROR_CORRECT_Q,
)

try:
    from pyzbar.pyzbar import decode as pyzbar_decode  # type: ignore[import-not-found]
    PYZBAR_AVAILABLE = True
except ImportError:
    pyzbar_decode = None
    PYZBAR_AVAILABLE = False


ECL_MAP = {
    'L': ERROR_CORRECT_L,
    'M': ERROR_CORRECT_M,
    'Q': ERROR_CORRECT_Q,
    'H': ERROR_CORRECT_H,
}


def matrix_to_image(matrix: List[List[int]], scale: int = 10, border: int = 4) -> Image.Image:
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


def flat_to_matrix(flat: List[int], size: int) -> List[List[int]]:
    """Convert a flat array to a 2D matrix"""
    matrix = []
    for y in range(size):
        row = []
        for x in range(size):
            row.append(flat[y * size + x])
        matrix.append(row)
    return matrix


def generate_qr(text: str, ecl: str = 'M', output: Optional[str] = None) -> Image.Image:
    """Generate a QR code image"""
    qr = qrcode.QRCode(
        version=None,
        error_correction=ECL_MAP.get(ecl.upper(), ERROR_CORRECT_M),
        box_size=10,
        border=4,
    )
    qr.add_data(text)
    qr.make(fit=True)
    
    img = cast(Image.Image, qr.make_image(fill_color="black", back_color="white"))
    
    if output:
        img.save(Path(output))
        print(f"Saved QR code to: {output}")
    
    return img


def scan_qr(image_path: str) -> Optional[str]:
    """Scan a QR code image and return the decoded text"""
    if not PYZBAR_AVAILABLE or pyzbar_decode is None:
        print("Error: pyzbar is not installed. Install with: pip install pyzbar")
        return None
    
    try:
        img = Image.open(image_path)
        decoded = pyzbar_decode(img)
        
        if decoded:
            result = decoded[0].data.decode('utf-8')
            print(f"Scanned content: {result}")
            return result
        else:
            print("No QR code found in image")
            return None
    except Exception as e:
        print(f"Error scanning: {e}")
        return None


def convert_matrix(input_file: str, output: str, scale: int = 10):
    """Convert a matrix JSON file to an image"""
    with open(input_file) as f:
        data = json.load(f)
    
    if isinstance(data, list):
        if isinstance(data[0], list):
            # 2D matrix
            matrix = data
        else:
            # Flat array
            size = int(len(data) ** 0.5)
            matrix = flat_to_matrix(data, size)
    elif isinstance(data, dict):
        if 'matrix' in data:
            matrix = data['matrix']
        elif 'flat' in data:
            size = data.get('size', int(len(data['flat']) ** 0.5))
            matrix = flat_to_matrix(data['flat'], size)
        else:
            print("Error: Unknown JSON format")
            return
    else:
        print("Error: Unknown data format")
        return
    
    img = matrix_to_image(matrix, scale=scale)
    img.save(output)
    print(f"Saved image to: {output}")


def compare_with_reference(text: str, matrix_file: str, ecl: str = 'M'):
    """Compare Luau output with reference implementation"""
    # Generate reference
    qr = qrcode.QRCode(
        version=None,
        error_correction=ECL_MAP.get(ecl.upper(), ERROR_CORRECT_M),
        box_size=1,
        border=0,
    )
    qr.add_data(text)
    qr.make(fit=True)
    
    ref_matrix = [[1 if cell else 0 for cell in row] for row in qr.modules]
    ref_size = len(ref_matrix)
    
    # Load Luau output
    with open(matrix_file) as f:
        data = json.load(f)
    
    if isinstance(data, dict):
        luau_matrix = data.get('matrix', [])
        luau_size = data.get('size', len(luau_matrix))
    elif isinstance(data, list):
        if isinstance(data[0], list):
            luau_matrix = data
            luau_size = len(data)
        else:
            luau_size = int(len(data) ** 0.5)
            luau_matrix = flat_to_matrix(data, luau_size)
    else:
        print("Error: Unknown format")
        return
    
    print(f"Reference: version={qr.version}, size={ref_size}")
    print(f"Luau: size={luau_size}")
    
    if luau_size != ref_size:
        print(f"❌ Size mismatch!")
        return
    
    # Compare
    matching = 0
    total = ref_size * ref_size
    
    for y in range(ref_size):
        for x in range(ref_size):
            if luau_matrix[y][x] == ref_matrix[y][x]:
                matching += 1
    
    similarity = matching / total
    print(f"Similarity: {similarity:.2%} ({matching}/{total} modules match)")
    
    if similarity > 0.99:
        print("✓ Matrices are essentially identical")
    elif similarity > 0.90:
        print("⚠ Matrices are similar (possibly different mask)")
    else:
        print("❌ Matrices differ significantly")
    
    # Try scanning both
    if PYZBAR_AVAILABLE and pyzbar_decode is not None:
        luau_img = matrix_to_image(luau_matrix)
        ref_img = matrix_to_image(ref_matrix)
        
        luau_scan = None
        ref_scan = None
        
        try:
            decoded = pyzbar_decode(luau_img)
            if decoded:
                luau_scan = decoded[0].data.decode('utf-8')
        except:
            pass
        
        try:
            decoded = pyzbar_decode(ref_img)
            if decoded:
                ref_scan = decoded[0].data.decode('utf-8')
        except:
            pass
        
        print(f"\nScan results:")
        print(f"  Reference: {ref_scan}")
        print(f"  Luau: {luau_scan}")
        
        if luau_scan == text:
            print("✓ Luau QR code scans correctly!")
        elif luau_scan:
            print(f"⚠ Luau QR code scans but content differs")
        else:
            print("❌ Luau QR code cannot be scanned")


def main():
    parser = argparse.ArgumentParser(description="QR Code Verification Tool")
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # Generate command
    gen_parser = subparsers.add_parser('generate', help='Generate a QR code')
    gen_parser.add_argument('text', help='Text to encode')
    gen_parser.add_argument('--output', '-o', default='qr.png', help='Output file')
    gen_parser.add_argument('--ecl', '-e', default='M', choices=['L', 'M', 'Q', 'H'],
                          help='Error correction level')
    
    # Scan command
    scan_parser = subparsers.add_parser('scan', help='Scan a QR code image')
    scan_parser.add_argument('image', help='Image file to scan')
    
    # Convert command
    conv_parser = subparsers.add_parser('convert', help='Convert matrix JSON to image')
    conv_parser.add_argument('input', help='Input JSON file')
    conv_parser.add_argument('--output', '-o', default='qr.png', help='Output file')
    conv_parser.add_argument('--scale', '-s', type=int, default=10, help='Scale factor')
    
    # Compare command
    cmp_parser = subparsers.add_parser('compare', help='Compare with reference')
    cmp_parser.add_argument('text', help='Original text')
    cmp_parser.add_argument('--matrix', '-m', required=True, help='Matrix JSON file')
    cmp_parser.add_argument('--ecl', '-e', default='M', choices=['L', 'M', 'Q', 'H'],
                          help='Error correction level')
    
    args = parser.parse_args()
    
    if args.command == 'generate':
        generate_qr(args.text, args.ecl, args.output)
    elif args.command == 'scan':
        scan_qr(args.image)
    elif args.command == 'convert':
        convert_matrix(args.input, args.output, args.scale)
    elif args.command == 'compare':
        compare_with_reference(args.text, args.matrix, args.ecl)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
