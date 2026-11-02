#!/usr/bin/env python3
"""Read and decode the Basys 3 final arm-controller UART telemetry."""

from __future__ import annotations

import argparse
import csv
import time
from pathlib import Path

import serial
from serial.tools import list_ports

HEADER = b"\xAA\x55"
FRAME_SIZE = 18


def available_ports() -> list[list_ports.ListPortInfo]:
    return sorted(list_ports.comports(), key=lambda item: item.device)


def print_ports() -> None:
    ports = available_ports()
    if not ports:
        print("没有找到串口。请检查 Basys 3 的 Micro-USB 数据线和 FTDI 驱动。")
        return
    for item in ports:
        print(f"{item.device:8s}  {item.description}  [{item.hwid}]")


def choose_port(requested: str | None) -> str:
    if requested:
        return requested

    ftdi_ports = [
        item for item in available_ports()
        if item.vid == 0x0403 and item.pid == 0x6010
    ]
    if len(ftdi_ports) == 1:
        return ftdi_ports[0].device
    if not ftdi_ports:
        raise RuntimeError(
            "没有自动找到 Basys 3 的 FTDI 串口，请用 --list 查看后指定 --port COMx。"
        )
    names = ", ".join(item.device for item in ftdi_ports)
    raise RuntimeError(f"检测到多个 FTDI 串口：{names}，请用 --port 明确选择。")


def decode_frame(frame: bytes) -> dict[str, object]:
    gyro_unsigned = (frame[14] << 8) | frame[15]
    gyro_signed = (
        gyro_unsigned - 65536 if gyro_unsigned & 0x8000 else gyro_unsigned
    )
    status = frame[16]

    return {
        "seq": (frame[2] << 8) | frame[3],
        "raw": (frame[4] << 8) | frame[5],
        "mav": (frame[6] << 8) | frame[7],
        "baseline": (frame[8] << 8) | frame[9],
        "threshold": (frame[10] << 8) | frame[11],
        "flex": (frame[12] << 8) | frame[13],
        "gyro_axis": gyro_signed,
        "status": status,
        "emg_tense": bool(status & (1 << 0)),
        "emg_ready": bool(status & (1 << 1)),
        "emg_calibrating": bool(status & (1 << 2)),
        "grip_active": bool(status & (1 << 3)),
        "flex_ready": bool(status & (1 << 4)),
        "gyro_ready": bool(status & (1 << 5)),
        "i2c_error": bool(status & (1 << 6)),
        "base_active": bool(status & (1 << 7)),
        "checksum": frame[17],
    }


def find_frame(buffer: bytearray, stats: dict[str, int]) -> dict[str, object] | None:
    while True:
        header_index = buffer.find(HEADER)
        if header_index < 0:
            if len(buffer) > 1:
                del buffer[:-1]
            return None

        if header_index > 0:
            del buffer[:header_index]
        if len(buffer) < FRAME_SIZE:
            return None

        frame = bytes(buffer[:FRAME_SIZE])
        checksum = 0
        for value in frame[:17]:
            checksum ^= value

        if checksum != frame[17]:
            stats["checksum_errors"] += 1
            del buffer[0]
            continue

        del buffer[:FRAME_SIZE]
        stats["valid_frames"] += 1
        return decode_frame(frame)


def state_text(sample: dict[str, object]) -> str:
    if sample["emg_calibrating"]:
        emg_state = "CALIBRATING"
    elif sample["emg_tense"]:
        emg_state = "TENSE"
    else:
        emg_state = "RELAX"

    active: list[str] = []
    if sample["grip_active"]:
        active.append("GRIP")
    if sample["base_active"]:
        active.append("BASE")
    if sample["i2c_error"]:
        active.append("I2C_ERROR")
    return "+".join([emg_state, *active]) if active else emg_state


def format_sample(sample: dict[str, object], show_hex: bool, frame: bytes = b"") -> str:
    text = (
        f"seq={sample['seq']:5d} "
        f"raw={sample['raw']:4d} "
        f"mav={sample['mav']:4d} "
        f"base={sample['baseline']:4d} "
        f"thr={sample['threshold']:4d} "
        f"flex={sample['flex']:4d} "
        f"gyro={sample['gyro_axis']:6d} "
        f"status=0x{sample['status']:02X} "
        f"{state_text(sample)}"
    )
    if show_hex:
        text += f"  hex={frame.hex(' ').upper()}"
    return text


def main() -> int:
    parser = argparse.ArgumentParser(
        description="读取 Basys 3 机械臂最终工程的 18 字节串口遥测帧"
    )
    parser.add_argument("--port", help="例如 COM9；省略时会自动寻找 FTDI")
    parser.add_argument("--baud", type=int, default=115200)
    parser.add_argument("--csv", type=Path, help="把所有有效帧同时保存为 CSV")
    parser.add_argument("--duration", type=float, default=None,
                        help="运行指定秒数后退出；省略则一直运行")
    parser.add_argument("--print-hz", type=float, default=5.0,
                        help="终端刷新频率，默认每秒 5 次")
    parser.add_argument("--show-hex", action="store_true",
                        help="在终端同时显示完整原始帧")
    parser.add_argument("--list", action="store_true", help="列出所有串口后退出")
    args = parser.parse_args()

    if args.list:
        print_ports()
        return 0
    if args.print_hz <= 0:
        parser.error("--print-hz 必须大于 0")
    if args.duration is not None and args.duration <= 0:
        parser.error("--duration 必须大于 0")

    try:
        port_name = choose_port(args.port)
    except RuntimeError as exc:
        print(exc)
        return 2

    csv_file = None
    writer = None
    if args.csv:
        args.csv.parent.mkdir(parents=True, exist_ok=True)
        csv_file = args.csv.open("w", newline="", encoding="utf-8")
        writer = csv.DictWriter(csv_file, fieldnames=[
            "time_s", "seq", "raw", "mav", "baseline", "threshold",
            "flex", "gyro_axis", "status", "emg_tense", "emg_ready",
            "emg_calibrating", "grip_active", "flex_ready", "gyro_ready",
            "i2c_error", "base_active", "checksum", "state",
        ])
        writer.writeheader()

    print(f"打开 {port_name}，协议 115200 8N1。按 Ctrl+C 停止。")
    buffer = bytearray()
    stats = {"valid_frames": 0, "checksum_errors": 0}
    last_seq: int | None = None
    sequence_errors = 0
    started = time.monotonic()
    deadline = started + args.duration if args.duration is not None else None
    last_print = 0.0

    try:
        with serial.Serial(
            port=port_name,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1,
        ) as port:
            while deadline is None or time.monotonic() < deadline:
                chunk = port.read(port.in_waiting or 1)
                if chunk:
                    buffer.extend(chunk)

                while True:
                    sample = find_frame(buffer, stats)
                    if sample is None:
                        break

                    seq = int(sample["seq"])
                    if last_seq is not None and seq != ((last_seq + 1) & 0xFFFF):
                        sequence_errors += 1
                    last_seq = seq

                    elapsed = time.monotonic() - started
                    if writer:
                        writer.writerow({
                            "time_s": f"{elapsed:.6f}",
                            **sample,
                            "state": state_text(sample),
                        })

                    now = time.monotonic()
                    if now - last_print >= 1.0 / args.print_hz:
                        frame_hex = b""
                        if args.show_hex:
                            frame_hex = bytes([
                                0xAA, 0x55,
                                (seq >> 8) & 0xFF, seq & 0xFF,
                                (int(sample["raw"]) >> 8) & 0xFF,
                                int(sample["raw"]) & 0xFF,
                                (int(sample["mav"]) >> 8) & 0xFF,
                                int(sample["mav"]) & 0xFF,
                                (int(sample["baseline"]) >> 8) & 0xFF,
                                int(sample["baseline"]) & 0xFF,
                                (int(sample["threshold"]) >> 8) & 0xFF,
                                int(sample["threshold"]) & 0xFF,
                                (int(sample["flex"]) >> 8) & 0xFF,
                                int(sample["flex"]) & 0xFF,
                                (int(sample["gyro_axis"]) >> 8) & 0xFF,
                                int(sample["gyro_axis"]) & 0xFF,
                                int(sample["status"]),
                                int(sample["checksum"]),
                            ])
                        print(format_sample(sample, args.show_hex, frame_hex))
                        last_print = now
    except KeyboardInterrupt:
        pass
    except serial.SerialException as exc:
        print(f"串口打开或读取失败：{exc}")
        print("请关闭串口助手、Vivado Hardware Manager 或其他占用该 COM 口的软件。")
        return 1
    finally:
        if csv_file:
            csv_file.close()

    elapsed = time.monotonic() - started
    print(
        f"结束：有效帧 {stats['valid_frames']}，"
        f"校验错误 {stats['checksum_errors']}，"
        f"序号跳变 {sequence_errors}，运行 {elapsed:.2f} s。"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
