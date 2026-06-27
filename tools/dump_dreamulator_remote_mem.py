#!/usr/bin/env python3
"""Dump Dreamulator remote-debug memory to a binary file or hex text."""

from __future__ import annotations

import argparse
import re
import socket
import sys
from pathlib import Path


MAX_REMOTE_MEM = 256
MEM_LINE_RE = re.compile(r"^[0-9A-Fa-f]{5}\s+((?:[0-9A-Fa-f]{2}\s*)+)$")


def parse_int(text: str) -> int:
    text = text.strip()
    if text.startswith("$"):
        return int(text[1:], 16)
    return int(text, 0)


def parse_address_int(text: str) -> int:
    text = text.strip()
    if text.startswith("$"):
        return int(text[1:], 16)
    if text.lower().startswith("0x"):
        return int(text, 16)
    return int(text, 16)


def parse_address(text: str) -> int:
    text = text.strip()
    if ":" in text:
        seg_text, off_text = text.split(":", 1)
        return ((parse_address_int(seg_text) << 4) + parse_address_int(off_text)) & 0xFFFFF
    return parse_address_int(text) & 0xFFFFF


def read_line(sock_file) -> str:
    line = sock_file.readline()
    if not line:
        raise RuntimeError("remote socket closed")
    return line.decode("ascii", errors="replace").rstrip("\r\n")


def read_banner(sock_file) -> str:
    return read_line(sock_file)


def read_mem_chunk(sock: socket.socket, sock_file, phys: int, count: int) -> bytes:
    seg = (phys >> 4) & 0xFFFF
    off = phys & 0xF
    command = f"mem {seg:04X}:{off:04X} {count}\n"
    sock.sendall(command.encode("ascii"))

    data = bytearray()
    while len(data) < count:
        line = read_line(sock_file)
        match = MEM_LINE_RE.match(line)
        if not match:
            raise RuntimeError(f"unexpected remote response: {line!r}")
        data.extend(int(byte_text, 16) for byte_text in match.group(1).split())
    return bytes(data[:count])


def dump_memory(host: str, port: int, address: int, length: int, timeout: float) -> bytes:
    out = bytearray()
    with socket.create_connection((host, port), timeout=timeout) as sock:
        sock.settimeout(timeout)
        sock_file = sock.makefile("rb", buffering=0)
        read_banner(sock_file)
        while len(out) < length:
            count = min(MAX_REMOTE_MEM, length - len(out))
            phys = (address + len(out)) & 0xFFFFF
            out.extend(read_mem_chunk(sock, sock_file, phys, count))
        sock.sendall(b"quit\n")
    return bytes(out)


def print_hex(data: bytes, base: int) -> None:
    for offset in range(0, len(data), 16):
        chunk = data[offset : offset + 16]
        print(
            f"{(base + offset) & 0xFFFFF:05X}: "
            + " ".join(f"{byte:02X}" for byte in chunk)
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Dump memory through Dreamulator's --remote debug socket."
    )
    parser.add_argument("address", help="physical address or SEG:OFF, e.g. 0000:1000")
    parser.add_argument("length", help="byte count, e.g. 0x1000")
    parser.add_argument("-o", "--output", type=Path, help="write binary dump here")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=9999)
    parser.add_argument("--timeout", type=float, default=2.0)
    parser.add_argument("--hex", action="store_true", help="print hex dump to stdout")
    args = parser.parse_args(argv)

    address = parse_address(args.address)
    length = parse_int(args.length)
    if length < 0:
        parser.error("length must be non-negative")

    try:
        data = dump_memory(args.host, args.port, address, length, args.timeout)
    except OSError as exc:
        print(f"remote connection failed: {exc}", file=sys.stderr)
        return 1
    except RuntimeError as exc:
        print(f"remote dump failed: {exc}", file=sys.stderr)
        return 1

    if args.output:
        args.output.write_bytes(data)
    if args.hex or not args.output:
        print_hex(data, address)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
