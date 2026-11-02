#!/usr/bin/env python3
"""Check a repository before a clean Vivado build."""

from __future__ import annotations

import re
import sys
from pathlib import Path


REQUIRED = [
    "src/rtl",
    "sim/tb",
    "board/constraints",
    "build/create_project.tcl",
    "sim/run_simulation.tcl",
    "build/build_bitstream.tcl",
]

BLOCKED_PATHS = {
    Path("build/vivado"),
    Path("build/xsim_project"),
    Path(".Xil"),
}
BLOCKED_PARTS = {"__pycache__", ".git"}
BLOCKED_SUFFIXES = {".pyc", ".jou", ".str"}
PRIVATE_PATTERNS = [
    re.compile(r"C:[\\/]Users[\\/]", re.IGNORECASE),
    re.compile(r"Desktop[\\/]FPGA", re.IGNORECASE),
]


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    errors: list[str] = []
    warnings: list[str] = []

    for rel in REQUIRED:
        if not (root / rel).exists():
            errors.append(f"missing required path: {rel}")

    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if any(relative == blocked or blocked in relative.parents for blocked in BLOCKED_PATHS):
            errors.append(f"generated path present: {relative}")
            continue
        if any(part in BLOCKED_PARTS for part in relative.parts):
            continue
        if path.is_file() and path.suffix.lower() in BLOCKED_SUFFIXES:
            errors.append(f"generated file present: {path.relative_to(root)}")

    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {
            ".md", ".txt", ".csv", ".tcl", ".v", ".sv", ".py", ".xdc"
        }:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if any(pattern.search(text) for pattern in PRIVATE_PATTERNS):
            warnings.append(f"possible local absolute path: {path.relative_to(root)}")

    print(f"root: {root}")
    print(f"errors: {len(errors)}")
    for item in errors:
        print(f"  ERROR {item}")
    print(f"warnings: {len(warnings)}")
    for item in warnings:
        print(f"  WARN  {item}")

    if errors:
        return 1
    print("repo structure check: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
