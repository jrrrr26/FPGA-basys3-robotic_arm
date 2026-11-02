#!/usr/bin/env python3
"""Validate and decode one 18-byte Basys 3 arm telemetry frame."""

from __future__ import annotations

import json
import re
import sys


HEADER = bytes((0xAA, 0x55))
FRAME_SIZE = 18


def signed16(value: int) -> int:
    return value - 0x10000 if value & 0x8000 else value


def decode(frame: bytes) -> dict[str, object]:
    checksum = 0
    for value in frame[:-1]:
        checksum ^= value

    status = frame[16]
    return {
        "frame_size": len(frame),
        "checksum_ok": checksum == frame[17],
        "seq": (frame[2] << 8) | frame[3],
        "raw": (frame[4] << 8) | frame[5],
        "mav": (frame[6] << 8) | frame[7],
        "baseline": (frame[8] << 8) | frame[9],
        "threshold": (frame[10] << 8) | frame[11],
        "flex": (frame[12] << 8) | frame[13],
        "gyro_axis": signed16((frame[14] << 8) | frame[15]),
        "status": status,
        "status_bits": {
            "emg_tense": bool(status & (1 << 0)),
            "emg_ready": bool(status & (1 << 1)),
            "emg_calibrating": bool(status & (1 << 2)),
            "grip_active": bool(status & (1 << 3)),
            "flex_ready": bool(status & (1 << 4)),
            "gyro_ready": bool(status & (1 << 5)),
            "i2c_error": bool(status & (1 << 6)),
            "base_active": bool(status & (1 << 7)),
        },
    }


def parse_frame(raw: str) -> bytes:
    text = raw.strip()
    if not text:
        raise ValueError("empty frame")
    if re.fullmatch(r"[0-9A-Fa-f]{36}", text):
        return bytes.fromhex(text)
    return bytes(int(item, 16) for item in re.split(r"[\s,;:-]+", text) if item)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: python check_frame.py \"AA 55 ...\"")
        return 2

    try:
        frame = parse_frame(" ".join(sys.argv[1:]))
    except ValueError as exc:
        print(f"INVALID: {exc}")
        return 1

    if len(frame) != FRAME_SIZE:
        print(f"FRAME_SIZE_ERROR: expected {FRAME_SIZE}, got {len(frame)}")
        return 1
    if frame[:2] != HEADER:
        print("HEADER_ERROR: expected AA 55")
        return 1

    result = decode(frame)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["checksum_ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
