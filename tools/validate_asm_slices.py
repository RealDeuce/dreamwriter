#!/usr/bin/env python3
"""Assemble NASM slices and compare bytes against the ROM image."""

from __future__ import annotations

import argparse
import glob as _glob
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from rom2 import parse_file_base, parse_addr_part, phys_to_file, read_rom, seg_off_to_phys


PATH_RE = re.compile(r"^(?P<prefix>.+)-(?P<seg>[0-9A-Fa-f]{4})-(?P<start>[0-9A-Fa-f]{4})-(?P<end>[0-9A-Fa-f]{4})\\.asm$", re.I)
PATH_NOSEG_RE = re.compile(r"^(?P<prefix>.+)-(?P<start>[0-9A-Fa-f]{4})-(?P<end>[0-9A-Fa-f]{4})\\.asm$", re.I)
META_RE = re.compile(
    r"^;\s*Generated from disasm:\s*(?P<start_seg>[0-9A-Fa-f]{3,4}):(?P<start_off>[0-9A-Fa-f]{4})-"
    r"(?:(?P<end_seg>[0-9A-Fa-f]{3,4}):)?(?P<end_off>[0-9A-Fa-f]{4})",
    re.I,
)
SEGMENT_LINE_RE = re.compile(r"^;\s*Segment:\s*(?P<seg>[0-9A-Fa-f]{3,4}):\s*$", re.I)
FILE_RANGE_RE = re.compile(r"^;\s*File range:\s*0x(?P<start>[0-9A-Fa-f]+)\.\.0x(?P<end>[0-9A-Fa-f]+)\s*(?:\([^)]+\))?\s*$", re.I)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate assembled NASM slices against ROM bytes.")
    parser.add_argument(
        "scope",
        nargs="*",
        default=["asm"],
        help="asm files, globs, or directories to validate.",
    )
    parser.add_argument("--rom", type=Path, default=Path("t4_ir_2.1.ic303"), help="ROM image to validate against")
    parser.add_argument(
        "--bank-base",
        action="append",
        default=["3000=file:0x30000"],
        metavar="SEG=file:OFFSET",
        help=(
            "map a segment to ROM file offset for validation; repeatable. "
            "Defaults to 3000=file:0x30000."
        ),
    )
    return parser.parse_args()


def parse_bank_bases(values: list[str]) -> dict[int, int]:
    bases: dict[int, int] = {}
    for value in values:
        if "=" not in value:
            raise ValueError(f"invalid --bank-base {value!r}; expected SEG=file:OFFSET")
        seg_text, base_text = value.split("=", 1)
        seg = parse_addr_part(seg_text)
        if not 0 <= seg <= 0xFFFF:
            raise ValueError(f"bank segment out of range: {seg_text}")
        bases[seg] = parse_file_base(base_text)
    return bases


def normalize_segment_text(seg_text: str) -> int:
    return int(seg_text, 16)


def expand_scope(values: list[str]) -> list[Path]:
    collected: list[Path] = []
    for value in values:
        expanded = _glob.glob(value) if any(ch in value for ch in "*?[") else [value]
        for item in expanded:
            path = Path(item)
            if path.is_dir():
                collected.extend(sorted(path.glob("*.asm")))
                continue
            if path.suffix.lower() == ".asm" and path.exists():
                collected.append(path)

    return sorted({p for p in collected}, key=lambda path: str(path))


def parse_slice_name(path: Path, content_meta: tuple[int, int, int] | None) -> tuple[int, int, int]:
    base = path.name
    if m := PATH_RE.match(base):
        seg = normalize_segment_text(m.group("seg"))
        start = int(m.group("start"), 16)
        end = int(m.group("end"), 16)
        return seg, start, end

    if m := PATH_NOSEG_RE.match(base):
        seg, start, end = content_meta if content_meta is not None else (None, None, None)
        if seg is None:
            raise ValueError(
                "segment could not be inferred from filename; expected "
                f"{path.name} to contain a segment prefix or Metadata line"
            )
        return seg, start, end

    if content_meta is None:
        raise ValueError(
            f"cannot parse slice range for {path}: expected one of "
            "<name>-SEG-START-END.asm or <name>-START-END.asm with metadata"
        )
    return content_meta


def parse_slice_metadata(path: Path) -> tuple[int, int, int] | None:
    segment: int | None = None
    file_start: int | None = None
    file_end: int | None = None

    for raw in path.read_text(encoding="utf-8").splitlines()[:40]:
        m = META_RE.match(raw.strip())
        if not m:
            seg_match = SEGMENT_LINE_RE.match(raw.strip())
            if seg_match:
                segment = int(seg_match.group("seg"), 16)
            range_match = FILE_RANGE_RE.match(raw.strip())
            if range_match:
                file_start = int(range_match.group("start"), 16)
                file_end = int(range_match.group("end"), 16)
            continue

        start_seg = normalize_segment_text(m.group("start_seg"))
        start_off = int(m.group("start_off"), 16)
        end_seg = int(m.group("end_seg"), 16) if m.group("end_seg") else start_seg
        end_off = int(m.group("end_off"), 16)
        if end_seg != start_seg:
            raise ValueError(
                f"{path}: unsupported range {start_seg:04X}:{start_off:04X}-{end_seg:04X}:{end_off:04X}; "
                "validate_asm_slices expects in-segment ranges."
            )
        return start_seg, start_off, end_off

    if segment is not None and file_start is not None and file_end is not None and segment == 0x3000:
        if file_end < file_start:
            raise ValueError(
                f"{path}: invalid file range in header: 0x{file_start:X}..0x{file_end:X}"
            )
        return segment, (file_start - 0x30000), (file_end - 0x30000)

    return None


def file_offset_from_slice(seg: int, start: int, end: int, bank_bases: dict[int, int]) -> tuple[int, int]:
    if seg in bank_bases:
        base = bank_bases[seg]
        return base + start, base + end
    phys_start = seg_off_to_phys(seg, start)
    file_start = phys_to_file(phys_start)
    file_end = file_start + (end - start)
    return file_start, file_end


def assemble_slice(path: Path, tmpdir: Path) -> tuple[int, bytes]:
    out_path = tmpdir / (path.name + ".bin")
    result = subprocess.run(
        ["nasm", "-f", "bin", "-o", str(out_path), str(path)],
        check=True,
        capture_output=True,
        text=False,
    )
    if result.stderr:
        # Keep noisy failure surfaces in caller context when assembly succeeds.
        pass
    return len(result.stdout or b""), out_path.read_bytes()


def preview_diff(expected: bytes, actual: bytes, max_bytes: int = 32) -> str:
    mismatch = []
    for i in range(min(len(expected), len(actual), max_bytes)):
        mismatch.append(f"{i:04x}:{expected[i]:02X}!={actual[i]:02X}")
    if not mismatch:
        mismatch.append("no byte overlap mismatch within preview window")
    return ", ".join(mismatch)


def validate_file(path: Path, rom: bytes, bank_bases: dict[int, int], tmpdir: Path) -> int:
    metadata = parse_slice_metadata(path)
    try:
        seg, start, end = parse_slice_name(path, (
            (metadata[0], metadata[1], metadata[2]) if metadata is not None else None
        ))
    except ValueError as exc:
        print(f"{path}: {exc}", file=sys.stderr)
        return 1

    if metadata:
        # Prefer metadata when segment inference fails from file name only.
        seg = metadata[0] if seg is None else seg
        start = metadata[1]
        end = metadata[2]

    if end < start:
        print(f"{path}: invalid range {seg:04X}:{start:04X}-{end:04X}", file=sys.stderr)
        return 1

    try:
        file_start, file_end = file_offset_from_slice(seg, start, end, bank_bases)
    except ValueError as exc:
        print(f"{path}: {exc}", file=sys.stderr)
        return 1

    expected_len = file_end - file_start + 1
    if file_start < 0 or file_end >= len(rom) or file_start > file_end:
        print(
            f"{path}: range {seg:04X}:{start:04X}-{end:04X} maps to invalid ROM bytes {file_start:05X}-{file_end:05X}",
            file=sys.stderr,
        )
        return 1

    try:
        _, actual = assemble_slice(path, tmpdir)
    except subprocess.CalledProcessError as exc:
        print(f"{path}: nasm failed", file=sys.stderr)
        stderr = exc.stderr.decode("utf-8", errors="replace").strip() if exc.stderr else ""
        if stderr:
            print(f"  nasm: {stderr}", file=sys.stderr)
        return 1
    except FileNotFoundError:
        print(f"{path}: nasm is not installed", file=sys.stderr)
        return 1

    expected = rom[file_start : file_end + 1]
    if len(actual) != expected_len:
        print(
            f"{path}: length mismatch (expected {expected_len} bytes from ROM, assembled {len(actual)} bytes)",
            file=sys.stderr,
        )
        return 1

    if actual != expected:
        print(
            f"{path}: bytes mismatch at ROM file 0x{file_start:05X}-0x{file_end:05X}",
            file=sys.stderr,
        )
        print(f"  first bytes: {preview_diff(expected, actual)}", file=sys.stderr)
        return 1

    return 0


def main() -> int:
    args = parse_args()
    try:
        bank_bases = parse_bank_bases(args.bank_base)
    except ValueError as exc:
        print(f"validate asm slices: {exc}", file=sys.stderr)
        return 1

    files = expand_scope(args.scope)
    if not files:
        print("no asm files matched", file=sys.stderr)
        return 1

    rom = read_rom(args.rom)
    failures = 0
    with tempfile.TemporaryDirectory(prefix="asm-validate-", suffix="-dreamwriter") as workdir:
        tmpdir = Path(workdir)
        for path in files:
            failures += validate_file(path, rom, bank_bases, tmpdir)

    print(f"asm validation: {'PASS' if failures == 0 else f'FAIL ({failures})'} ({len(files)} files)")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
