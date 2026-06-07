#!/usr/bin/env python3
"""Recursive disassembly tracer for DreamWriter ROM images.

Traces execution from seed entry points, following all near calls,
near branches, and far calls/jumps within known segments. Deduplicates
at the instruction level so no address is disassembled twice.

Usage:
    python3 tools/trace_boot.py [--rom PATH] [--seed SEG:OFF ...] [--irqs] [--thunks]

Default seeds: C000:0029 (boot entry).
--irqs adds hardware IRQ entry points (NMI, keyboard, warm/power).
--thunks reads the banked thunk dispatch table at C000:1B38 and adds
each slot as a seed.
"""

from __future__ import annotations

import argparse
import re
import struct
import subprocess
import sys
from collections import OrderedDict
from dataclasses import dataclass, field


@dataclass
class Segment:
    name: str
    seg_value: int      # e.g. 0xC000
    file_base: int      # file offset of seg:0000
    max_offset: int     # highest valid offset in this segment
    covered: set = field(default_factory=set)

    def file_offset(self, off: int) -> int:
        return self.file_base + off

    def contains_phys(self, phys: int) -> bool:
        return self.file_base <= phys < self.file_base + self.max_offset


# Window 6 segments for v3.1 (1 MiB ROM, bank 14 at file 0xC0000)
WINDOW6_START = 0xC0000
WINDOW6_END = 0xE0000

SEGMENTS: dict[str, Segment] = {}


def add_segment(name: str, seg_value: int, max_offset: int):
    file_base = (seg_value << 4)
    SEGMENTS[name] = Segment(name, seg_value, file_base, max_offset)


def find_segment_for_far(seg_value: int, offset: int) -> tuple[str, int] | None:
    """Resolve a far seg:off by matching the segment value first."""
    for seg in SEGMENTS.values():
        if seg.seg_value == seg_value:
            if 0 <= offset < seg.max_offset:
                return seg.name, offset
    phys = (seg_value << 4) + offset
    for seg in SEGMENTS.values():
        if seg.file_base <= phys < seg.file_base + seg.max_offset:
            return seg.name, phys - seg.file_base
    return None


@dataclass
class Block:
    segment: str
    start: int
    end: int
    insns: list
    calls: list         # [(seg, off)]
    branches: list      # [(seg, off)]
    end_type: str
    label: str = ""


ROM: bytes = b""
BLOCKS: OrderedDict[tuple[str, int], Block] = OrderedDict()

COND_OPS = frozenset({
    "jz", "jnz", "jc", "jnc", "jb", "jnb", "ja", "jna",
    "jbe", "jnbe", "jae", "jnae", "jl", "jnl", "jg", "jng",
    "jle", "jnle", "jge", "jnge", "je", "jne", "js", "jns",
    "jo", "jno", "jp", "jnp", "jcxz", "loop", "loopz", "loopnz",
})


def parse_far_target(mnemonic: str) -> tuple[int, int] | None:
    """Extract seg:off from a far call/jmp mnemonic."""
    m = re.search(r'0x([0-9a-f]+):0x([0-9a-f]+)', mnemonic, re.I)
    if m:
        return int(m.group(1), 16), int(m.group(2), 16)
    return None


def disasm_block(seg_name: str, offset: int, max_bytes: int = 0x400) -> Block:
    seg = SEGMENTS[seg_name]
    file_off = seg.file_offset(offset)
    if file_off >= len(ROM) or offset >= seg.max_offset:
        return Block(seg_name, offset, offset, [], [], [], "eof")

    result = subprocess.run(
        ["ndisasm", "-b", "16", "-o", hex(offset),
         "-e", hex(file_off), "-"],
        input=ROM, capture_output=True, timeout=10,
    )

    insns = []
    calls = []
    branches = []
    end_type = "limit"

    for raw in result.stdout.decode().split("\n"):
        raw = raw.strip()
        if not raw:
            continue
        parts = raw.split(None, 2)
        if len(parts) < 2:
            continue
        try:
            addr = int(parts[0], 16)
        except ValueError:
            continue
        if addr < offset:
            continue
        if addr >= offset + max_bytes:
            break
        if addr in seg.covered:
            end_type = "already_covered"
            break

        bytehex = parts[1]
        mnemonic = parts[2] if len(parts) > 2 else ""
        insn_len = len(bytehex) // 2
        insns.append((addr, bytehex, mnemonic, insn_len))

        mn = mnemonic.lower().strip()
        words = mn.split()
        if not words:
            continue
        op = words[0]

        # --- unconditional jump ---
        if op == "jmp":
            far = parse_far_target(mn)
            if far:
                far_seg, far_off = far
                resolved = find_segment_for_far(far_seg, far_off)
                if resolved:
                    branches.append(resolved)
                end_type = "jmp_far"
                break
            target_str = words[-1]
            if target_str.startswith("0x") and ":" not in target_str:
                try:
                    target = int(target_str, 16)
                    branches.append((seg_name, target))
                except ValueError:
                    pass
                end_type = "jmp"
                break
            end_type = "jmp_indirect"
            break

        # --- returns ---
        if op in ("ret", "retf", "iret"):
            end_type = op
            break
        if bytehex.lower() == "cf":
            end_type = "iret"
            break

        # --- near call ---
        if op == "call" and len(words) == 2:
            w = words[1]
            if w.startswith("0x") and ":" not in w:
                try:
                    target = int(w, 16)
                    calls.append((seg_name, target))
                except ValueError:
                    pass
            elif ":" in mn:
                far = parse_far_target(mn)
                if far:
                    far_seg, far_off = far
                    phys = (far_seg << 4) + far_off
                    resolved = find_segment_for_far(far_seg, far_off)
                    if resolved:
                        calls.append(resolved)

        # --- conditional branch ---
        if op in COND_OPS:
            target_str = words[-1]
            if target_str.startswith("0x"):
                try:
                    target = int(target_str, 16)
                    branches.append((seg_name, target))
                except ValueError:
                    pass

    end = insns[-1][0] + insns[-1][3] if insns else offset
    return Block(seg_name, offset, end, insns, calls, branches, end_type)


def trace(seeds: list[tuple[str, int, str]], max_blocks: int = 5000):
    pending = list(seeds)
    count = 0

    while pending and count < max_blocks:
        seg_name, offset, label = pending.pop(0)
        seg = SEGMENTS.get(seg_name)
        if seg is None:
            continue
        if offset in seg.covered:
            continue
        if offset < 0 or offset >= seg.max_offset:
            continue

        block = disasm_block(seg_name, offset)
        if not block.insns:
            continue

        # Mark all instruction addresses as covered
        for addr, _, _, insn_len in block.insns:
            for a in range(addr, addr + insn_len):
                seg.covered.add(a)

        block.label = label
        BLOCKS[(seg_name, offset)] = block
        count += 1

        for target_seg, target_off in block.branches:
            tseg = SEGMENTS.get(target_seg)
            if tseg and target_off not in tseg.covered:
                pending.append((target_seg, target_off, f"from_{seg_name}:{offset:04X}"))

        for target_seg, target_off in block.calls:
            tseg = SEGMENTS.get(target_seg)
            if tseg and target_off not in tseg.covered:
                pending.append((target_seg, target_off, f"call_{seg_name}:{offset:04X}"))


def output():
    for (seg_name, start) in sorted(BLOCKS.keys(), key=lambda k: (k[0], k[1])):
        block = BLOCKS[(seg_name, start)]
        if not block.insns:
            continue

        parts = [f"--- {seg_name}:{start:04X}..{block.end:04X}"]
        if block.label:
            parts.append(f"  ; {block.label}")

        call_strs = []
        for cs, co in block.calls:
            call_strs.append(f"{cs}:{co:04X}")
        if call_strs:
            parts.append(f"  calls:{','.join(call_strs)}")

        branch_strs = []
        for bs, bo in block.branches:
            branch_strs.append(f"{bs}:{bo:04X}")
        if branch_strs:
            parts.append(f"  branches:{','.join(branch_strs)}")

        print("".join(parts))
        for addr, bytehex, mnemonic, _ in block.insns:
            print(f"  {seg_name}:{addr:04X}  {bytehex:<14s} {mnemonic}")
        print(f"  ; end: {block.end_type}")
        print()


def read_thunk_table(table_offset: int = 0x1B38, count: int = 12) -> list[tuple[str, int, str]]:
    """Read the banked thunk dispatch table and return seed entries."""
    seeds = []
    for i in range(count):
        file_off = WINDOW6_START + table_offset + i * 2
        if file_off + 2 > len(ROM):
            break
        target = struct.unpack_from("<H", ROM, file_off)[0]
        if 0 < target < 0x20000:
            seeds.append(("C000", target, f"thunk_slot_{i}"))
    return seeds


def main():
    global ROM

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rom", type=str, default="v3.1/t4_ir_3.1_e588.ic303")
    parser.add_argument("--seed", action="append", default=[], metavar="SEG:OFF",
                        help="Additional seed entry point (e.g. C000:0029)")
    parser.add_argument("--irqs", action="store_true",
                        help="Add hardware IRQ entry points as seeds")
    parser.add_argument("--thunks", action="store_true",
                        help="Add banked thunk dispatch table entries as seeds")
    parser.add_argument("--max-blocks", type=int, default=5000)
    args = parser.parse_args()

    ROM = open(args.rom, "rb").read()

    # Set up segments for window 6 (port 0x16=0x01, bank 14, file 0xC0000)
    add_segment("C000", 0xC000, 0x10000)     # C000:0000..FFFF
    add_segment("C772", 0xC772, 0x188E0)     # C772:0000 to end of window
    add_segment("DEF0", 0xDEF0, 0x10F00)     # DEF0:0000 to end of window

    # Window 5 (port 0x15=0x02 during banked call, bank 13, file 0xA0000)
    add_segment("AD00", 0xAD00, 0x13000)     # AD00:0000 to end of window

    # Window 7 (port 0x17=0x00, bank 15, file 0xE0000) — fixed, not banked
    add_segment("ED1B", 0xED1B, 0x12E50)     # ED1B:0000 to end of window
    add_segment("EE17", 0xEE17, 0x11E90)     # EE17:0000 to end of window

    # Default seeds
    seeds: list[tuple[str, int, str]] = [("C000", 0x0029, "boot_entry")]

    # Parse --seed arguments
    for s in args.seed:
        m = re.match(r"([0-9A-Fa-f]+):([0-9A-Fa-f]+)$", s)
        if m:
            seg_str = m.group(1).upper()
            off = int(m.group(2), 16)
            # Find or create segment
            seg_name = None
            for name, seg in SEGMENTS.items():
                if seg.seg_value == int(seg_str, 16):
                    seg_name = name
                    break
            if seg_name is None:
                seg_val = int(seg_str, 16)
                seg_name = seg_str
                add_segment(seg_name, seg_val, 0x10000)
            seeds.append((seg_name, off, f"seed_{s}"))
        else:
            print(f"warning: ignoring unparseable seed '{s}'", file=sys.stderr)

    if args.irqs:
        irq_seeds = [
            ("C000", 0x04D0, "irq_f8_nmi"),
            ("C000", 0x05C0, "irq_f9"),
            ("C000", 0x05D4, "irq_fa"),
            ("C000", 0x05F7, "irq_fb_keyboard"),
            ("C000", 0x0676, "irq_fc"),
            ("C000", 0x084A, "irq_fd"),
            ("C000", 0x085E, "irq_fe"),
            ("C000", 0x03FC, "irq_ff_warm"),
        ]
        seeds.extend(irq_seeds)

    if args.thunks:
        seeds.extend(read_thunk_table())

    trace(seeds, args.max_blocks)

    total_insns = sum(len(b.insns) for b in BLOCKS.values())
    seg_counts = {}
    for (sn, _), b in BLOCKS.items():
        seg_counts[sn] = seg_counts.get(sn, 0) + 1
    seg_summary = ", ".join(f"{n}:{c}" for n, c in sorted(seg_counts.items()))
    print(f"Traced {len(BLOCKS)} blocks, {total_insns} instructions ({seg_summary})",
          file=sys.stderr)

    output()


if __name__ == "__main__":
    main()
